pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property string omarchyPath: ""
    property var shell: null
    property var manifest: null
    property var pluginRegistry: null

    // ── Data ──
    property var servers: []
    property var filteredServers: []
    property string searchText: ""
    property var groupCounts: []
    property int totalCount: 0
    property int windowsCount: 0
    property int linuxCount: 0
    property int otherCount: 0
    property string lastError: ""
    property string lastImport: ""
    property bool busy: false
    readonly property int recentLimit: 5
    readonly property int maxServersQml: 2000
    readonly property int maxOutputBytes: 262144

    // collapsed groups: map groupName -> bool (true = collapsed)
    property var collapsedGroups: ({})

    function isCollapsed(g) {
        return collapsedGroups[g] !== false
    }
    function toggleGroup(g) {
        var cg = Object.assign({}, collapsedGroups)
        cg[g] = !isCollapsed(g)
        collapsedGroups = cg
    }
    function expandAll() {
        var cg = {}
        for (var i=0;i<groupCounts.length;i++) cg[groupCounts[i].group]=false
        collapsedGroups = cg
    }
    function collapseAll() {
        var cg = {}
        for (var i=0;i<groupCounts.length;i++) cg[groupCounts[i].group]=true
        collapsedGroups = cg
    }

    // UI expanded states
    property bool showAddForm: false
    property bool showImportHelp: false

    function scriptPath(name) {
        return Qt.resolvedUrl("bin/" + name).toString().replace(/^file:\/\//,"")
    }

    Component.onCompleted: {
        refresh()
    }

    function refresh() {
        listProc.running = true
    }

    // ── List ──
    Process {
        id: listProc
        command: ["python3", root.scriptPath("omarchy-remmina-servers"), "list"]
        stdout: StdioCollector { id: listOut; waitForEnd: true }
        stderr: StdioCollector { id: listErr; waitForEnd: true }
        property bool timedOut: false
        onRunningChanged: {
            if (running) {
                timedOut = false
                listDeadline.restart()
            } else {
                listDeadline.stop()
            }
        }
        onExited: function(code) {
            listDeadline.stop()
            if (timedOut) {
                root.lastError = "list timeout (8s)"
                return
            }
            if (listOut.text.length > root.maxOutputBytes || listErr.text.length > root.maxOutputBytes) {
                root.lastError = "list output too large"
                return
            }
            try {
                var txt = listOut.text.trim()
                if (txt.length > root.maxOutputBytes) throw new Error("too large")
                var arr = JSON.parse(txt)
                if (!Array.isArray(arr)) arr=[]
                if (arr.length > root.maxServersQml) arr = arr.slice(0, root.maxServersQml)
                root.servers = arr
                root.applyFilter()
                root.recalcStats()
            } catch(e) {
                root.servers = []
                root.lastError = "list parse failed: " + e
            }
        }
    }
    Timer {
        id: listDeadline
        interval: 8000
        onTriggered: {
            listProc.timedOut = true
            listProc.running = false
        }
    }

    function applyFilter() {
        var q = (root.searchText || "").toLowerCase().trim()
        if (!q) {
            root.filteredServers = root.servers.slice()
            return
        }
        var out=[]
        for (var i=0;i<root.servers.length;i++) {
            var s=root.servers[i]
            var hay = ((s.name||"")+" "+(s.host||"")+" "+(s.protocol||"")+" "+(s.group||"")+" "+(s.username||"")+" "+(s.domain||"")+" "+(s.notes||"")).toLowerCase()
            if (hay.indexOf(q) !== -1) out.push(s)
        }
        root.filteredServers = out
    }
    onSearchTextChanged: applyFilter()

    // ── Group helpers ──
    readonly property var defaultGroups: ["Windows", "Linux"]
    function isDefaultGroup(g) { return g === "Windows" || g === "Linux" }
    function isVirtualGroup(g) { return g === "Favorites" || g === "Recent" }

    function recalcStats() {
        var total = servers.length
        var win=0, lin=0
        var fav=0, rec=0
        var groups={}
        for (var i=0;i<servers.length;i++) {
            var s=servers[i]
            var p=(s.protocol||"").toUpperCase()
            if (p==="RDP") win++
            else if (p==="SSH" || p==="VNC" || p==="SPICE" || p==="SFTP") lin++
            if (s.favorite === true) fav++
            if (s.lastUsed && s.lastUsed > 0) rec++
            var g=s.group||"General"
            groups[g]=(groups[g]||0)+1
        }
        root.totalCount=total
        root.windowsCount=win
        root.linuxCount=lin
        root.otherCount=Math.max(0,total-win-lin)
        var arr=[]
        if (fav > 0) arr.push({group: "Favorites", count: fav})
        if (rec > 0) {
            var n = Math.min(rec, root.recentLimit)
            arr.push({group: "Recent", count: n})
        }
        var customKeys=[]
        var defaultKeys=[]
        var keys=Object.keys(groups).sort()
        for (var j=0;j<keys.length;j++) {
            if (isDefaultGroup(keys[j])) defaultKeys.push(keys[j])
            else customKeys.push(keys[j])
        }
        for (var k=0;k<root.extraGroupNames.length;k++) {
            var eg=root.extraGroupNames[k]
            if (groups[eg] === undefined && !isDefaultGroup(eg) && !isVirtualGroup(eg)) customKeys.push(eg)
        }
        customKeys.sort()
        defaultKeys.sort()
        for (var a=0;a<customKeys.length;a++) arr.push({group: customKeys[a], count: groups[customKeys[a]] || 0})
        for (var b=0;b<defaultKeys.length;b++) arr.push({group: defaultKeys[b], count: groups[defaultKeys[b]]})
        root.groupCounts=arr
    }

    // ── Extra empty groups (custom) ──
    property var extraGroups: [] // list of {name, glyph}
    property var extraGroupNames: {
        var out=[]
        for (var i=0;i<extraGroups.length;i++) {
            var g=extraGroups[i]
            if (typeof g === "string") out.push(g)
            else if (g && g.name) out.push(g.name)
        }
        return out
    }
    function groupGlyph(name) {
        // custom glyph overrides first (allows Windows/Linux customization)
        for (var i=0;i<extraGroups.length;i++) {
            var g=extraGroups[i]
            if (g && g.name === name && g.glyph) return g.glyph
        }
        if (name === "Favorites") return "󰓎"
        if (name === "Recent") return "󰧓"
        if (name === "Windows") return ""
        if (name === "Linux") return ""
        return "󰉋" // default folder
    }
    Process {
        id: groupsProc
        command: ["python3", root.scriptPath("omarchy-remmina-servers"), "groups-json"]
        stdout: StdioCollector { id: groupsOut; waitForEnd: true }
        stderr: StdioCollector { id: groupsErr; waitForEnd: true }
        property bool timedOut: false
        onRunningChanged: {
            if (running) {
                timedOut = false
                groupsDeadline.restart()
            } else {
                groupsDeadline.stop()
            }
        }
        onExited: function(code){
            groupsDeadline.stop()
            if (timedOut) {
                root.lastError = "groups timeout"
                return
            }
            if (groupsOut.text.length > root.maxOutputBytes) {
                root.lastError = "groups output too large"
                return
            }
            try {
                var arr=JSON.parse(groupsOut.text.trim())
                if (Array.isArray(arr)) {
                    if (arr.length > 500) arr = arr.slice(0,500)
                    root.extraGroups=arr
                } else root.extraGroups=[]
                root.recalcStats()
            } catch(e){ root.extraGroups=[] }
        }
    }
    Timer {
        id: groupsDeadline
        interval: 8000
        onTriggered: {
            groupsProc.timedOut = true
            groupsProc.running = false
        }
    }
    function refreshGroups(){ groupsProc.running=true }

    // ── CRUD ──
    Process {
        id: addProc
        stdout: StdioCollector { id: addOut; waitForEnd: true }
        stderr: StdioCollector { id: addErr; waitForEnd: true }
        property bool timedOut: false
        onRunningChanged: {
            if (running) {
                timedOut = false
                addDeadline.restart()
            } else {
                addDeadline.stop()
            }
        }
        onExited: function(c){
            addDeadline.stop()
            root.busy = false
            if (timedOut) {
                root.lastError = "Add timeout (10s)"
                return
            }
            if (c === 0) {
                root.lastError = ""
                root.refresh()
                root.showAddForm = false
            } else {
                root.lastError = addOut.text.trim() || addErr.text.trim() || "Add failed"
            }
        }
    }
    Timer {
        id: addDeadline
        interval: 10000
        onTriggered: {
            addProc.timedOut = true
            addProc.running = false
        }
    }
    function addServer(obj) {
        root.busy = true
        root.lastError = ""
        var jsonStr = JSON.stringify(obj)
        if (jsonStr.length > 65536) { root.lastError = "add: payload too large (64KiB)"; root.busy = false; return }
        if (jsonStr.length > root.maxOutputBytes) { root.lastError = "add: output limit"; root.busy = false; return }
        var sPath = root.scriptPath("omarchy-remmina-servers")
        addProc.environment = {"REM_JSON": jsonStr}
        addProc.command = ["bash", "-lc", "printf '%s' \"$REM_JSON\" | python3 \"" + sPath + "\" add"]
        addProc.running = true
    }

    Process {
        id: updateProc
        stdout: StdioCollector { id: updateOut; waitForEnd: true }
        stderr: StdioCollector { id: updateErr; waitForEnd: true }
        property bool timedOut: false
        onRunningChanged: {
            if (running) {
                timedOut = false
                updateDeadline.restart()
            } else {
                updateDeadline.stop()
            }
        }
        onExited: function(c){
            updateDeadline.stop()
            root.busy = false
            if (timedOut) {
                root.lastError = "Update timeout (10s)"
                return
            }
            if (c === 0) {
                root.lastError = ""
                root.refresh()
            } else {
                root.lastError = updateOut.text.trim() || updateErr.text.trim() || "Update failed"
            }
        }
    }
    Timer {
        id: updateDeadline
        interval: 10000
        onTriggered: {
            updateProc.timedOut = true
            updateProc.running = false
        }
    }
    function updateServer(id, obj) {
        root.busy = true
        if (id.length > 1024) { root.lastError = "update: id too long"; root.busy = false; return }
        var jsonStr = JSON.stringify(obj)
        if (jsonStr.length > 65536) { root.lastError = "update: payload too large (64KiB)"; root.busy = false; return }
        var sPath = root.scriptPath("omarchy-remmina-servers")
        updateProc.environment = {"REM_JSON": jsonStr, "REM_ID": id}
        updateProc.command = ["bash", "-lc", "printf '%s' \"$REM_JSON\" | python3 \"" + sPath + "\" update \"$REM_ID\""]
        updateProc.running = true
    }

    Process {
        id: deleteProc
        stdout: StdioCollector { id: deleteOut; waitForEnd: true }
        stderr: StdioCollector { id: deleteErr; waitForEnd: true }
        property bool timedOut: false
        onRunningChanged: {
            if (running) {
                timedOut = false
                deleteDeadline.restart()
            } else {
                deleteDeadline.stop()
            }
        }
        onExited: function(c){
            deleteDeadline.stop()
            root.busy = false
            if (timedOut) {
                root.lastError = "Delete timeout (10s)"
                return
            }
            if (c === 0) {
                root.refresh()
            } else {
                root.lastError = deleteOut.text.trim() || deleteErr.text.trim() || "Delete failed"
            }
        }
    }
    Timer {
        id: deleteDeadline
        interval: 10000
        onTriggered: {
            deleteProc.timedOut = true
            deleteProc.running = false
        }
    }
    function deleteServer(id) {
        if (id.length > 1024) { root.lastError = "delete: id too long"; return }
        root.busy = true
        var sPath = root.scriptPath("omarchy-remmina-servers")
        deleteProc.command = ["python3", sPath, "delete", id]
        deleteProc.running = true
    }

    // ── Launch ──
    Process {
        id: launchProc
        stdout: StdioCollector { id: launchOut; waitForEnd: true }
        stderr: StdioCollector { id: launchErr; waitForEnd: true }
        property bool timedOut: false
        onRunningChanged: {
            if (running) {
                timedOut = false
                launchDeadline.restart()
            } else {
                launchDeadline.stop()
            }
        }
        onExited: function(c){
            launchDeadline.stop()
            if (timedOut) {
                root.lastError = "Launch timeout (15s)"
                return
            }
            if (c !== 0) {
                root.lastError = launchOut.text.trim() || launchErr.text.trim() || "Launch failed — check dependencies (freerdp/virt-viewer/openssh)"
            }
            Qt.callLater(root.refresh)
        }
    }
    Timer {
        id: launchDeadline
        interval: 15000
        onTriggered: {
            launchProc.timedOut = true
            launchProc.running = false
        }
    }
    function launchServer(id) {
        if (id.length > 1024) { root.lastError = "launch: id too long"; return }
        root.lastError = ""
        var sPath = root.scriptPath("omarchy-remmina-launch")
        launchProc.command = ["python3", sPath, id]
        launchProc.running = true
    }
    function launchDirect(protocol, host, port, username, domain) {
        if (host.length > 253 || (port && port.length > 10) || (username && username.length > 64)) { root.lastError = "launch: field too long"; return }
        var sPath = root.scriptPath("omarchy-remmina-launch")
        launchProc.command = ["python3", sPath, "--direct", protocol, host, port || "-", username || "-", domain || "-"]
        launchProc.running = true
    }

    // ── Favorite ──
    Process {
        id: favProc
        stdout: StdioCollector { id: favOut; waitForEnd: true }
        stderr: StdioCollector { id: favErr; waitForEnd: true }
        property bool timedOut: false
        onRunningChanged: {
            if (running) {
                timedOut = false
                favDeadline.restart()
            } else {
                favDeadline.stop()
            }
        }
        onExited: function(c){
            favDeadline.stop()
            if (timedOut) {
                root.lastError = "Favorite toggle timeout"
                return
            }
            if (c === 0) {
                root.refresh()
                root.refreshGroups()
            } else {
                root.lastError = favOut.text.trim() || favErr.text.trim() || "Favorite toggle failed"
            }
        }
    }
    Timer {
        id: favDeadline
        interval: 8000
        onTriggered: {
            favProc.timedOut = true
            favProc.running = false
        }
    }
    function toggleFavorite(id) {
        var cur = false
        for (var i = 0; i < root.servers.length; i++) {
            if (root.servers[i].id === id) {
                cur = root.servers[i].favorite === true
                break
            }
        }
        var sPath = root.scriptPath("omarchy-remmina-servers")
        favProc.command = ["python3", sPath, "favorite", id, cur ? "0" : "1"]
        favProc.running = true
    }

    // ── Groups ──
    Process {
        id: groupProc
        stdout: StdioCollector { id: groupOut; waitForEnd: true }
        stderr: StdioCollector { id: groupErr; waitForEnd: true }
        property bool timedOut: false
        onRunningChanged: {
            if (running) {
                timedOut = false
                groupDeadline.restart()
            } else {
                groupDeadline.stop()
            }
        }
        onExited: function(c){
            groupDeadline.stop()
            if (timedOut) {
                root.lastError = "Group operation timeout"
                return
            }
            if (c === 0) {
                root.refresh()
                root.refreshGroups()
            } else {
                root.lastError = groupOut.text.trim() || groupErr.text.trim() || "Group operation failed"
            }
        }
    }
    Timer {
        id: groupDeadline
        interval: 10000
        onTriggered: {
            groupProc.timedOut = true
            groupProc.running = false
        }
    }
    function createGroup(name) {
        if (!name || !name.trim()) {
            root.lastError = "Group name required"
            return
        }
        if (name.trim().length > 64) { root.lastError = "Group name too long"; return }
        var sPath = root.scriptPath("omarchy-remmina-servers")
        groupProc.command = ["python3", sPath, "group-add", name.trim()]
        groupProc.running = true
    }
    function renameGroup(oldName, newName) {
        if (!oldName || !newName || !newName.trim()) {
            root.lastError = "New name required"
            return
        }
        if (oldName.length > 64 || newName.trim().length > 64) { root.lastError = "Group name too long"; return }
        var sPath = root.scriptPath("omarchy-remmina-servers")
        groupProc.command = ["python3", sPath, "group-rename", oldName, newName.trim()]
        groupProc.running = true
    }
    function deleteGroup(name) {
        if (name.length > 64) { root.lastError = "Group name too long"; return }
        var sPath = root.scriptPath("omarchy-remmina-servers")
        groupProc.command = ["python3", sPath, "group-delete", name]
        groupProc.running = true
    }
    function moveServerToGroup(id, newGroup) {
        if (id.length > 1024 || newGroup.length > 64) { root.lastError = "move: field too long"; return }
        var sPath = root.scriptPath("omarchy-remmina-servers")
        groupProc.command = ["python3", sPath, "move", id, newGroup]
        groupProc.running = true
    }
    function setGroupGlyph(name, glyph) {
        if (name.length > 64 || glyph.length > 8) { root.lastError = "glyph: field too long"; return }
        var sPath = root.scriptPath("omarchy-remmina-servers")
        groupProc.command = ["python3", sPath, "group-glyph", name, glyph]
        groupProc.running = true
    }

    // ── Import ──
    Process {
        id: importProc
        stdout: StdioCollector { id: importOut; waitForEnd: true }
        stderr: StdioCollector { id: importErr; waitForEnd: true }
        property bool timedOut: false
        onRunningChanged: {
            if (running) {
                timedOut = false
                importDeadline.restart()
            } else {
                importDeadline.stop()
            }
        }
        onExited: function(c){
            importDeadline.stop()
            root.busy = false
            if (timedOut) {
                root.lastError = "Import timeout (30s)"
                return
            }
            if (importOut.text.length > root.maxOutputBytes || importErr.text.length > 8192) { root.lastError = "import output too large"; return }
            try {
                var raw = importOut.text.trim()
                if (!raw) raw = importErr.text.trim()
                if (raw.length > root.maxOutputBytes) { root.lastError = "import output too large"; return }
                var o = JSON.parse(raw)
                if (o.imported !== undefined) {
                    root.lastImport = "Imported " + o.imported + " / skipped " + o.skipped
                    if (o.errors && o.errors.length) {
                        root.lastError = o.errors.join("; ")
                    } else {
                        root.lastError = ""
                    }
                    root.refresh()
                } else {
                    root.lastError = raw
                }
            } catch(e) {
                root.lastError = importOut.text.trim() || importErr.text.trim() || "Import failed"
            }
        }
    }
    Timer {
        id: importDeadline
        interval: 30000
        onTriggered: {
            importProc.timedOut = true
            importProc.running = false
        }
    }
    function importCsv(path) {
        if (path.length > 1024) { root.lastError = "import: path too long"; return }
        root.busy = true
        var sPath = root.scriptPath("omarchy-remmina-import")
        importProc.command = ["python3", sPath, "csv", path]
        importProc.running = true
    }
    function importTxt(path) {
        if (path.length > 1024) { root.lastError = "import: path too long"; return }
        root.busy = true
        var sPath = root.scriptPath("omarchy-remmina-import")
        importProc.command = ["python3", sPath, "txt", path]
        importProc.running = true
    }
    function importSsh() {
        root.busy = true
        var sPath = root.scriptPath("omarchy-remmina-import")
        importProc.command = ["python3", sPath, "ssh"]
        importProc.running = true
    }
    function importRemmina() {
        root.busy = true
        var sPath = root.scriptPath("omarchy-remmina-import")
        importProc.command = ["python3", sPath, "remmina"]
        importProc.running = true
    }

    // ── Tray fix ──
    Process {
        id: trayFixProc
        stdout: StdioCollector { id: trayFixOut; waitForEnd: true }
        stderr: StdioCollector { id: trayFixErr; waitForEnd: true }
        property bool timedOut: false
        onRunningChanged: {
            if (running) {
                timedOut = false
                trayFixDeadline.restart()
            } else {
                trayFixDeadline.stop()
            }
        }
        onExited: function(c){
            trayFixDeadline.stop()
            if (timedOut) {
                root.lastError = "Tray fix timeout (10s)"
                return
            }
            var out = trayFixOut.text.trim()
            var err = trayFixErr.text.trim()
            if (c === 0) {
                // --check prints "needs fix (...)" on stdout with exit 0; surface as error so banner appears
                if (out.indexOf("needs fix") !== -1 || out.indexOf("Remmina tray") !== -1 || err.indexOf("needs fix") !== -1) {
                    root.lastError = out || err || "Remmina tray icon needs fix"
                    root.lastImport = ""
                } else {
                    root.lastError = ""
                    root.lastImport = out || "Tray icon disabled"
                }
            } else {
                root.lastError = err || out || "Tray fix failed"
            }
        }
    }
    Timer {
        id: trayFixDeadline
        interval: 10000
        onTriggered: {
            trayFixProc.timedOut = true
            trayFixProc.running = false
        }
    }
    function fixTray() {
        var sPath = root.scriptPath("omarchy-remmina-tray-fix")
        trayFixProc.command = ["bash", sPath, "--fix"]
        trayFixProc.running = true
    }
    function checkTray() {
        var sPath = root.scriptPath("omarchy-remmina-tray-fix")
        trayFixProc.command = ["bash", sPath, "--check"]
        trayFixProc.running = true
    }

    // ── File pickers (zenity) ──
    Process {
        id: csvPicker
        command: ["zenity", "--file-selection", "--title=Select CSV/TXT file", "--file-filter=CSV | *.csv *.txt *.TXT", "--file-filter=All | *"]
        stdout: StdioCollector { id: csvPickerOut; waitForEnd: true }
        property bool timedOut: false
        onRunningChanged: {
            if (running) {
                timedOut = false
                csvPickerDeadline.restart()
            } else {
                csvPickerDeadline.stop()
            }
        }
        onExited: function(code){
            csvPickerDeadline.stop()
            if (timedOut) return
            if (csvPickerOut.text.length > 8192) { root.lastError = "picker output too large"; return }
            if (code === 0) {
                var p = csvPickerOut.text.trim()
                if (p.length > 1024) { root.lastError = "picker path too long"; return }
                if (p) {
                    if (p.toLowerCase().endsWith(".txt")) {
                        root.importTxt(p)
                    } else {
                        root.importCsv(p)
                    }
                }
            }
        }
    }
    Timer {
        id: csvPickerDeadline
        interval: 60000
        onTriggered: {
            csvPicker.timedOut = true
            csvPicker.running = false
        }
    }
    function pickImport() { csvPicker.running = true }

    Process {
        id: jsonPicker
        command: ["zenity", "--file-selection", "--title=Select JSON file", "--file-filter=JSON | *.json *.JSON", "--file-filter=All | *"]
        stdout: StdioCollector { id: jsonPickerOut; waitForEnd: true }
        property bool timedOut: false
        onRunningChanged: {
            if (running) {
                timedOut = false
                jsonPickerDeadline.restart()
            } else {
                jsonPickerDeadline.stop()
            }
        }
        onExited: function(code){
            jsonPickerDeadline.stop()
            if (timedOut) return
            if (jsonPickerOut.text.length > 8192) { root.lastError = "picker output too large"; return }
            if (code === 0) {
                var p = jsonPickerOut.text.trim()
                if (p.length > 1024) { root.lastError = "picker path too long"; return }
                if (p) root.importJson(p)
            }
        }
    }
    Timer {
        id: jsonPickerDeadline
        interval: 60000
        onTriggered: {
            jsonPicker.timedOut = true
            jsonPicker.running = false
        }
    }
    function pickJsonImport() { jsonPicker.running = true }
    function importJson(path) {
        if (path.length > 1024) { root.lastError = "import: path too long"; return }
        if (jsonPickerOut.text.length > root.maxOutputBytes || csvPickerOut.text.length > 8192) { root.lastError = "picker output too large"; return }
        root.busy = true
        var sPath = root.scriptPath("omarchy-remmina-import")
        importProc.command = ["python3", sPath, "json", path]
        importProc.running = true
    }

    // Helpers for UI: grouped model (handles virtual groups)
    function serversForGroup(g) {
        if (g === "Favorites") {
            var fav=[]
            for (var i=0;i<root.filteredServers.length;i++) if (root.filteredServers[i].favorite===true) fav.push(root.filteredServers[i])
            return fav
        }
        if (g === "Recent") {
            var rec=[]
            for (var i=0;i<root.filteredServers.length;i++) if (root.filteredServers[i].lastUsed && root.filteredServers[i].lastUsed > 0) rec.push(root.filteredServers[i])
            rec.sort(function(a,b){ return (b.lastUsed||0) - (a.lastUsed||0) })
            if (rec.length > root.recentLimit) rec = rec.slice(0, root.recentLimit)
            return rec
        }
        var out=[]
        for (var i=0;i<root.filteredServers.length;i++) {
            var s=root.filteredServers[i]
            if ((s.group||"General")===g) out.push(s)
        }
        return out
    }
}
