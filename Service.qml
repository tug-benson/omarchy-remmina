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
    // collection limits enforced in QML as well
    readonly property int maxServersQml: 2000
    readonly property int maxOutputBytes: 262144 // 256 KiB

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
        // tray fix no longer auto-run (requires explicit user action, see fixTray())
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
        onRunningChanged: if (running) { timedOut=false; listDeadline.restart() } else listDeadline.stop()
        Timer { id: listDeadline; interval: 8000; onTriggered: { listProc.timedOut=true; listProc.running=false } }
        onExited: function(code) {
            listDeadline.stop()
            if (timedOut) { root.lastError="list timeout (8s)"; return }
            if (listOut.text.length > root.maxOutputBytes || listErr.text.length > root.maxOutputBytes) { root.lastError="list output too large"; return }
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

    function applyFilter() {
        var q = (root.searchText || "").toLowerCase().trim()
        if (q.length > 256) q = q.slice(0,256)
        if (!q) {
            root.filteredServers = root.servers.slice(0, root.maxServersQml)
            return
        }
        var out=[]
        for (var i=0;i<root.servers.length;i++) {
            if (out.length >= root.maxServersQml) break
            var s=root.servers[i]
            var hay = ((s.name||"")+" "+(s.host||"")+" "+(s.protocol||"")+" "+(s.group||"")+" "+(s.username||"")+" "+(s.domain||"")+" "+(s.notes||"")).toLowerCase()
            if (hay.length > 2048) hay = hay.slice(0,2048)
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
        if (servers.length > root.maxServersQml) servers = servers.slice(0, root.maxServersQml)
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
            if (g.length > 64) g = g.slice(0,64)
            groups[g]=(groups[g]||0)+1
            if (Object.keys(groups).length > 500) break
        }
        root.totalCount=total
        root.windowsCount=win
        root.linuxCount=lin
        root.otherCount=Math.max(0,total-win-lin)
        var arr=[]
        if (fav > 0) arr.push({group: "Favorites", count: Math.min(fav, 500)})
        if (rec > 0) {
            var n = Math.min(rec, root.recentLimit)
            arr.push({group: "Recent", count: n})
        }
        var customKeys=[]
        var defaultKeys=[]
        var keys=Object.keys(groups).sort()
        if (keys.length > 500) keys = keys.slice(0,500)
        for (var j=0;j<keys.length;j++) {
            if (isDefaultGroup(keys[j])) defaultKeys.push(keys[j])
            else customKeys.push(keys[j])
        }
        for (var k=0;k<root.extraGroupNames.length;k++) {
            var eg=root.extraGroupNames[k]
            if (eg.length > 64) eg = eg.slice(0,64)
            if (groups[eg] === undefined && !isDefaultGroup(eg) && !isVirtualGroup(eg)) customKeys.push(eg)
            if (customKeys.length > 500) break
        }
        customKeys.sort()
        defaultKeys.sort()
        for (var a=0;a<customKeys.length;a++) { if (arr.length >= 500) break; arr.push({group: customKeys[a], count: groups[customKeys[a]] || 0}) }
        for (var b=0;b<defaultKeys.length;b++) { if (arr.length >= 500) break; arr.push({group: defaultKeys[b], count: groups[defaultKeys[b]]}) }
        root.groupCounts=arr
    }

    // ── Extra empty groups (custom) ──
    property var extraGroups: [] // list of {name, glyph}
    property var extraGroupNames: {
        var out=[]
        if (extraGroups.length > 500) return out
        for (var i=0;i<extraGroups.length;i++) {
            var g=extraGroups[i]
            if (typeof g === "string" && g.length <= 64) out.push(g)
            else if (g && g.name && g.name.length <= 64) out.push(g.name)
            if (out.length >= 500) break
        }
        return out
    }
    function groupGlyph(name) {
        if (name.length > 64) name = name.slice(0,64)
        for (var i=0;i<extraGroups.length;i++) {
            var g=extraGroups[i]
            if (g && g.name === name && g.glyph) return g.glyph
        }
        if (name === "Favorites") return "󰓎"
        if (name === "Recent") return "󰧓"
        if (name === "Windows") return ""
        if (name === "Linux") return ""
        return "󰉋"
    }
    Process {
        id: groupsProc
        command: ["python3", root.scriptPath("omarchy-remmina-servers"), "groups-json"]
        stdout: StdioCollector { id: groupsOut; waitForEnd: true }
        stderr: StdioCollector { id: groupsErr; waitForEnd: true }
        property bool timedOut: false
        onRunningChanged: if (running) { timedOut=false; groupsDeadline.restart() } else groupsDeadline.stop()
        Timer { id: groupsDeadline; interval: 8000; onTriggered: { groupsProc.timedOut=true; groupsProc.running=false } }
        onExited: function(code){
            groupsDeadline.stop()
            if (timedOut) { root.lastError="groups timeout"; return }
            if (groupsOut.text.length > root.maxOutputBytes) { root.lastError="groups output too large"; return }
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
    function refreshGroups(){ groupsProc.running=true }

    // ── CRUD ──
    Process { id: addProc; stdout: StdioCollector { id: addOut; waitForEnd:true }; stderr: StdioCollector { id: addErr; waitForEnd:true }
        property bool timedOut: false
        onRunningChanged: if (running) { timedOut=false; addDead.restart() } else addDead.stop()
        Timer { id: addDead; interval: 10000; onTriggered: { addProc.timedOut=true; addProc.running=false } }
        onExited: function(c){
            addDead.stop()
            root.busy=false
            if (timedOut) { root.lastError="add timeout"; return }
            if (addOut.text.length > root.maxOutputBytes || addErr.text.length > 8192) { root.lastError="add output too large"; return }
            if (c===0) { root.lastError=""; root.refresh(); root.showAddForm=false }
            else root.lastError=(addOut.text+addErr.text).trim().slice(0,512) || "Add failed"
        }
    }
    function addServer(obj) {
        // enforce collection limit before send
        if (root.servers.length >= root.maxServersQml) { root.lastError="too many servers (limit 2000)"; return }
        var jsonStr = JSON.stringify(obj)
        if (jsonStr.length > 64*1024) { root.lastError="payload too large"; return }
        if (jsonStr.length > 2048) { /* field limits already enforced in sanitize, but check */ }
        root.busy=true
        root.lastError=""
        addProc.environment = {"REM_JSON": jsonStr}
        addProc.command = ["bash","-lc","printf '%s' \"$REM_JSON\" | python3 \""+root.scriptPath("omarchy-remmina-servers")+"\" add"]
        addProc.running=true
    }

    Process { id: updateProc; stdout: StdioCollector { id: updOut; waitForEnd:true }; stderr: StdioCollector { id: updErr; waitForEnd:true }
        property bool timedOut: false
        onRunningChanged: if (running) { timedOut=false; updDead.restart() } else updDead.stop()
        Timer { id: updDead; interval: 10000; onTriggered: { updateProc.timedOut=true; updateProc.running=false } }
        onExited: function(c){
            updDead.stop()
            root.busy=false
            if (timedOut) { root.lastError="update timeout"; return }
            if (updOut.text.length > root.maxOutputBytes) { root.lastError="update output too large"; return }
            if (c===0) { root.lastError=""; root.refresh() }
            else root.lastError=(updOut.text+updErr.text).trim().slice(0,512) || "Update failed"
        }
    }
    function updateServer(id, obj) {
        if (String(id).length > 64) { root.lastError="invalid id"; return }
        var jsonStr = JSON.stringify(obj)
        if (jsonStr.length > 64*1024) { root.lastError="payload too large"; return }
        root.busy=true
        updateProc.environment = {"REM_JSON": jsonStr, "REM_ID": id}
        updateProc.command = ["bash","-lc","printf '%s' \"$REM_JSON\" | python3 \""+root.scriptPath("omarchy-remmina-servers")+"\" update \"$REM_ID\""]
        updateProc.running=true
    }

    Process { id: deleteProc; stdout: StdioCollector { id: delOut; waitForEnd:true }; stderr: StdioCollector { id: delErr; waitForEnd:true }
        property bool timedOut: false
        onRunningChanged: if (running) { timedOut=false; delDead.restart() } else delDead.stop()
        Timer { id: delDead; interval: 8000; onTriggered: { deleteProc.timedOut=true; deleteProc.running=false } }
        onExited: function(c){
            delDead.stop()
            root.busy=false
            if (timedOut) { root.lastError="delete timeout"; return }
            if (c===0) root.refresh()
            else root.lastError=(delOut.text+delErr.text).trim().slice(0,512) || "Delete failed"
        }
    }
    function deleteServer(id) {
        if (String(id).length > 64) { root.lastError="invalid id"; return }
        root.busy=true
        deleteProc.command = ["python3", root.scriptPath("omarchy-remmina-servers"), "delete", id]
        deleteProc.running=true
    }

    // ── Launch ──
    Process { id: launchProc; stdout: StdioCollector { id: launchOut; waitForEnd:true }; stderr: StdioCollector { id: launchErr; waitForEnd:true }
        property bool timedOut: false
        onRunningChanged: if (running) { timedOut=false; launchDead.restart() } else launchDead.stop()
        Timer { id: launchDead; interval: 10000; onTriggered: { launchProc.timedOut=true; launchProc.running=false } }
        onExited: function(c){
            launchDead.stop()
            if (timedOut) { root.lastError="launch timeout"; return }
            if (launchOut.text.length > 8192 || launchErr.text.length > 8192) { root.lastError="launch output too large"; return }
            if (c!==0) root.lastError=(launchOut.text+launchErr.text).trim().slice(0,512) || "Launch failed — check dependencies (freerdp/virt-viewer/openssh)"
            Qt.callLater(root.refresh)
        }
    }
    function launchServer(id) {
        if (String(id).length > 64) { root.lastError="invalid id"; return }
        root.lastError=""
        launchProc.command = ["python3", root.scriptPath("omarchy-remmina-launch"), id]
        launchProc.running=true
    }
    function launchDirect(protocol, host, port, username, domain) {
        if (String(host).length > 253 || String(username).length > 64) { root.lastError="invalid host/user"; return }
        launchProc.command = ["python3", root.scriptPath("omarchy-remmina-launch"), "--direct", protocol, host, port||"-", username||"-", domain||"-"]
        launchProc.running=true
    }

    // ── Favorite ──
    Process { id: favProc; stdout: StdioCollector { id: favOut; waitForEnd:true }; stderr: StdioCollector { id: favErr; waitForEnd:true }
        property bool timedOut: false
        onRunningChanged: if (running) { timedOut=false; favDead.restart() } else favDead.stop()
        Timer { id: favDead; interval: 8000; onTriggered: { favProc.timedOut=true; favProc.running=false } }
        onExited: function(c){
            favDead.stop()
            if (timedOut) { root.lastError="favorite timeout"; return }
            if (c===0) { root.refresh(); root.refreshGroups() }
            else root.lastError=(favOut.text+favErr.text).trim().slice(0,512) || "Favorite toggle failed"
        }
    }
    function toggleFavorite(id) {
        if (String(id).length > 64) return
        var cur=false
        for (var i=0;i<root.servers.length;i++) if (root.servers[i].id===id) { cur=root.servers[i].favorite===true; break }
        favProc.command=["python3", root.scriptPath("omarchy-remmina-servers"), "favorite", id, cur ? "0" : "1"]
        favProc.running=true
    }

    // ── Groups ──
    Process { id: groupProc; stdout: StdioCollector { id: grpOut; waitForEnd:true }; stderr: StdioCollector { id: grpErr; waitForEnd:true }
        property bool timedOut: false
        onRunningChanged: if (running) { timedOut=false; grpDead.restart() } else grpDead.stop()
        Timer { id: grpDead; interval: 8000; onTriggered: { groupProc.timedOut=true; groupProc.running=false } }
        onExited: function(c){
            grpDead.stop()
            if (timedOut) { root.lastError="group timeout"; return }
            if (c===0) { root.refresh(); root.refreshGroups() }
            else root.lastError=(grpOut.text+grpErr.text).trim().slice(0,512) || "Group operation failed"
        }
    }
    function createGroup(name) {
        if (!name || !name.trim() || name.trim().length > 64) { root.lastError="Group name required (max 64)"; return }
        if (root.groupCounts.length >= 500) { root.lastError="too many groups"; return }
        groupProc.command=["python3", root.scriptPath("omarchy-remmina-servers"), "group-add", name.trim()]
        groupProc.running=true
    }
    function renameGroup(oldName, newName) {
        if (!oldName || !newName || !newName.trim() || oldName.length>64 || newName.trim().length>64) { root.lastError="New name required"; return }
        groupProc.command=["python3", root.scriptPath("omarchy-remmina-servers"), "group-rename", oldName, newName.trim()]
        groupProc.running=true
    }
    function deleteGroup(name) {
        if (String(name).length>64) return
        groupProc.command=["python3", root.scriptPath("omarchy-remmina-servers"), "group-delete", name]
        groupProc.running=true
    }
    function moveServerToGroup(id, newGroup) {
        if (String(id).length>64 || String(newGroup).length>64) return
        groupProc.command=["python3", root.scriptPath("omarchy-remmina-servers"), "move", id, newGroup]
        groupProc.running=true
    }
    function setGroupGlyph(name, glyph) {
        if (String(name).length>64 || String(glyph).length>8) return
        groupProc.command=["python3", root.scriptPath("omarchy-remmina-servers"), "group-glyph", name, glyph]
        groupProc.running=true
    }

    // ── Import ──
    Process { id: importProc; stdout: StdioCollector { id: impOut; waitForEnd:true }; stderr: StdioCollector { id: impErr; waitForEnd:true }
        property bool timedOut: false
        onRunningChanged: if (running) { root.busy=running; if (running) { timedOut=false; impDead.restart() } else impDead.stop() }
        Timer { id: impDead; interval: 30000; onTriggered: { importProc.timedOut=true; importProc.running=false } }
        onExited: function(c){
            impDead.stop()
            root.busy=false
            if (timedOut) { root.lastError="import timeout (30s)"; return }
            var txt = impOut.text.trim().slice(0, 8192)
            if (txt.length > 8192) txt = txt.slice(0,8192)
            try {
                var o=JSON.parse(txt)
                if (o.imported!==undefined) {
                    root.lastImport = "Imported "+o.imported+" / skipped "+o.skipped
                    if (o.errors && o.errors.length) root.lastError=o.errors.join("; ").slice(0,1024)
                    else root.lastError=""
                    root.refresh()
                } else root.lastError=txt.slice(0,512)
            } catch(e){ root.lastError=txt.slice(0,512) }
        }
    }
    function importCsv(path) {
        if (String(path).length > 1024) { root.lastError="path too long"; return }
        root.busy=true
        importProc.command=["python3", root.scriptPath("omarchy-remmina-import"), "csv", path]
        importProc.running=true
    }
    function importTxt(path) {
        if (String(path).length > 1024) { root.lastError="path too long"; return }
        root.busy=true
        importProc.command=["python3", root.scriptPath("omarchy-remmina-import"), "txt", path]
        importProc.running=true
    }
    function importSsh() {
        root.busy=true
        importProc.command=["python3", root.scriptPath("omarchy-remmina-import"), "ssh"]
        importProc.running=true
    }
    function importRemmina() {
        root.busy=true
        importProc.command=["python3", root.scriptPath("omarchy-remmina-import"), "remmina"]
        importProc.running=true
    }

    // ── Tray fix (explicit user action only) ──
    Process {
        id: trayFixProc
        command: ["bash", root.scriptPath("omarchy-remmina-tray-fix"), "--check"]
        stdout: StdioCollector { id: trayOut; waitForEnd:true }
        stderr: StdioCollector { id: trayErr; waitForEnd:true }
        property bool timedOut: false
        onRunningChanged: if (running) { timedOut=false; trayDead.restart() } else trayDead.stop()
        Timer { id: trayDead; interval: 8000; onTriggered: { trayFixProc.timedOut=true; trayFixProc.running=false } }
        onExited: function(c){
            trayDead.stop()
            if (timedOut) return
            var out = (trayOut.text+trayErr.text).trim()
            if (out.indexOf("needs fix") !== -1) {
                root.lastError = "Remmina tray enabled (breaks on Hyprland) — click Fix in panel"
            }
        }
    }
    function fixTray() {
        // explicit user action with backup/rollback support
        trayFixProc.command = ["bash", root.scriptPath("omarchy-remmina-tray-fix"), "--fix"]
        trayFixProc.running=true
    }
    function checkTray() { trayFixProc.command = ["bash", root.scriptPath("omarchy-remmina-tray-fix"), "--check"]; trayFixProc.running=true }

    // ── File pickers (zenity) ──
    Process {
        id: csvPicker
        command: ["zenity","--file-selection","--title=Select CSV/TXT file","--file-filter=CSV | *.csv *.txt *.TXT","--file-filter=All | *"]
        stdout: StdioCollector { id: csvPickOut; waitForEnd:true }
        stderr: StdioCollector { id: csvPickErr; waitForEnd:true }
        property bool timedOut: false
        onRunningChanged: if (running) { timedOut=false; csvPickDead.restart() } else csvPickDead.stop()
        Timer { id: csvPickDead; interval: 60000; onTriggered: { csvPicker.timedOut=true; csvPicker.running=false } }
        onExited: function(code){
            csvPickDead.stop()
            if (timedOut) { root.lastError="file picker timeout"; return }
            if (code===0) {
                var p=csvPickOut.text.trim().slice(0,1024)
                if (p.length > 1024) { root.lastError="path too long"; return }
                if (p) {
                    if (p.toLowerCase().endsWith(".txt")) root.importTxt(p)
                    else root.importCsv(p)
                }
            }
        }
    }
    function pickImport() { csvPicker.running=true }
    Process {
        id: jsonPicker
        command: ["zenity","--file-selection","--title=Select JSON file","--file-filter=JSON | *.json *.JSON","--file-filter=All | *"]
        stdout: StdioCollector { id: jsonPickOut; waitForEnd:true }
        stderr: StdioCollector { id: jsonPickErr; waitForEnd:true }
        property bool timedOut: false
        onRunningChanged: if (running) { timedOut=false; jsonPickDead.restart() } else jsonPickDead.stop()
        Timer { id: jsonPickDead; interval: 60000; onTriggered: { jsonPicker.timedOut=true; jsonPicker.running=false } }
        onExited: function(code){
            jsonPickDead.stop()
            if (timedOut) { root.lastError="picker timeout"; return }
            if (code===0) {
                var p=jsonPickOut.text.trim().slice(0,1024)
                if (p) root.importJson(p)
            }
        }
    }
    function pickJsonImport() { jsonPicker.running=true }
    function importJson(path) {
        if (String(path).length > 1024) { root.lastError="path too long"; return }
        root.busy=true
        importProc.command=["python3", root.scriptPath("omarchy-remmina-import"), "json", path]
        importProc.running=true
    }

    // Helpers for UI: grouped model (handles virtual groups)
    function serversForGroup(g) {
        if (g.length > 64) g = g.slice(0,64)
        if (g === "Favorites") {
            var fav=[]
            for (var i=0;i<root.filteredServers.length;i++) {
                if (fav.length >= root.maxServersQml) break
                if (root.filteredServers[i].favorite===true) fav.push(root.filteredServers[i])
            }
            return fav
        }
        if (g === "Recent") {
            var rec=[]
            for (var i=0;i<root.filteredServers.length;i++) {
                if (rec.length >= root.recentLimit) break
                if (root.filteredServers[i].lastUsed && root.filteredServers[i].lastUsed > 0) rec.push(root.filteredServers[i])
            }
            rec.sort(function(a,b){ return (b.lastUsed||0) - (a.lastUsed||0) })
            if (rec.length > root.recentLimit) rec = rec.slice(0, root.recentLimit)
            return rec
        }
        var out=[]
        for (var i=0;i<root.filteredServers.length;i++) {
            if (out.length >= root.maxServersQml) break
            var s=root.filteredServers[i]
            if ((s.group||"General")===g) out.push(s)
        }
        return out
    }
}
