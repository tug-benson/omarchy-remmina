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

    // collapsed groups: map groupName -> bool (true = collapsed)
    property var collapsedGroups: ({})

    function isCollapsed(g) {
        return collapsedGroups[g] === true
    }
    function toggleGroup(g) {
        var cg = Object.assign({}, collapsedGroups)
        cg[g] = !isCollapsed(g)
        collapsedGroups = cg
    }
    function expandAll() { collapsedGroups = {} }
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
        trayFixProc.running = true
    }

    function refresh() {
        listProc.running = true
    }

    // ── List ──
    Process {
        id: listProc
        command: ["python3", root.scriptPath("omarchy-remmina-servers"), "list"]
        stdout: StdioCollector { waitForEnd: true }
        onExited: function(code) {
            try {
                var arr = JSON.parse(stdout.text.trim())
                if (!Array.isArray(arr)) arr=[]
                root.servers = arr
                root.applyFilter()
                root.recalcStats()
            } catch(e) {
                root.servers = []
            }
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
        if (name === "Favorites") return "󰓎"
        if (name === "Recent") return "󰧓"
        if (name === "Windows") return ""
        if (name === "Linux") return ""
        for (var i=0;i<extraGroups.length;i++) {
            var g=extraGroups[i]
            if (g && g.name === name && g.glyph) return g.glyph
        }
        return "󰉋" // default folder
    }
    Process {
        id: groupsProc
        command: ["python3", root.scriptPath("omarchy-remmina-servers"), "groups-json"]
        stdout: StdioCollector { waitForEnd: true }
        onExited: function(code){
            try {
                var arr=JSON.parse(stdout.text.trim())
                if (Array.isArray(arr)) root.extraGroups=arr
                else root.extraGroups=[]
                root.recalcStats()
            } catch(e){ root.extraGroups=[] }
        }
    }
    function refreshGroups(){ groupsProc.running=true }
    Component.onCompleted: { refresh(); trayFixProc.running=true; Qt.callLater(refreshGroups) }
    onServersChanged: Qt.callLater(recalcStats)

    // ── CRUD ──
    Process { id: addProc; stdout: StdioCollector {waitForEnd:true}
        onExited: function(c){
            root.busy=false
            if (c===0) { root.lastError=""; root.refresh(); root.showAddForm=false }
            else root.lastError=stdout.text.trim() || "Add failed"
        }
    }
    function addServer(obj) {
        root.busy=true
        root.lastError=""
        // Use python directly to avoid shell injection; pass JSON via stdin via bash heredoc is unsafe, so use python -c
        var jsonStr = JSON.stringify(obj)
        // Escape for bash single quote: we use Process with bash -lc and printf
        // Safer: write via python invocation with env var
        addProc.environment = {"REM_JSON": jsonStr}
        addProc.command = ["bash","-lc","printf '%s' \"$REM_JSON\" | python3 \""+root.scriptPath("omarchy-remmina-servers")+"\" add"]
        addProc.running=true
    }

    Process { id: updateProc; stdout: StdioCollector {waitForEnd:true}
        onExited: function(c){
            root.busy=false
            if (c===0) { root.lastError=""; root.refresh() }
            else root.lastError=stdout.text.trim() || "Update failed"
        }
    }
    function updateServer(id, obj) {
        root.busy=true
        var jsonStr = JSON.stringify(obj)
        updateProc.environment = {"REM_JSON": jsonStr, "REM_ID": id}
        updateProc.command = ["bash","-lc","printf '%s' \"$REM_JSON\" | python3 \""+root.scriptPath("omarchy-remmina-servers")+"\" update \"$REM_ID\""]
        updateProc.running=true
    }

    Process { id: deleteProc; stdout: StdioCollector {waitForEnd:true}
        onExited: function(c){
            root.busy=false
            if (c===0) root.refresh()
            else root.lastError=stdout.text.trim() || "Delete failed"
        }
    }
    function deleteServer(id) {
        root.busy=true
        deleteProc.command = ["python3", root.scriptPath("omarchy-remmina-servers"), "delete", id]
        deleteProc.running=true
    }

    // ── Launch ──
    Process { id: launchProc; stdout: StdioCollector {waitForEnd:true}
        onExited: function(c){
            if (c!==0) root.lastError=stdout.text.trim() || "Launch failed — check dependencies (freerdp/virt-viewer/openssh)"
            // Recent updated via launch script's lastUsed touch — refresh to show
            Qt.callLater(root.refresh)
        }
    }
    function launchServer(id) {
        root.lastError=""
        launchProc.command = ["python3", root.scriptPath("omarchy-remmina-launch"), id]
        launchProc.running=true
    }
    function launchDirect(protocol, host, port, username, domain) {
        launchProc.command = ["python3", root.scriptPath("omarchy-remmina-launch"), "--direct", protocol, host, port||"-", username||"-", domain||"-"]
        launchProc.running=true
    }

    // ── Favorite ──
    Process { id: favProc; stdout: StdioCollector {waitForEnd:true}
        onExited: function(c){
            if (c===0) { root.refresh(); root.refreshGroups() }
            else root.lastError=stdout.text.trim() || "Favorite toggle failed"
        }
    }
    function toggleFavorite(id) {
        var cur=false
        for (var i=0;i<root.servers.length;i++) if (root.servers[i].id===id) { cur=root.servers[i].favorite===true; break }
        favProc.command=["python3", root.scriptPath("omarchy-remmina-servers"), "favorite", id, cur ? "0" : "1"]
        favProc.running=true
    }

    // ── Groups ──
    Process { id: groupProc; stdout: StdioCollector {waitForEnd:true}
        onExited: function(c){
            if (c===0) { root.refresh(); root.refreshGroups() }
            else root.lastError=stdout.text.trim() || "Group operation failed"
        }
    }
    function createGroup(name) {
        if (!name || !name.trim()) { root.lastError="Group name required"; return }
        groupProc.command=["python3", root.scriptPath("omarchy-remmina-servers"), "group-add", name.trim()]
        groupProc.running=true
    }
    function renameGroup(oldName, newName) {
        if (!oldName || !newName || !newName.trim()) { root.lastError="New name required"; return }
        groupProc.command=["python3", root.scriptPath("omarchy-remmina-servers"), "group-rename", oldName, newName.trim()]
        groupProc.running=true
    }
    function deleteGroup(name) {
        groupProc.command=["python3", root.scriptPath("omarchy-remmina-servers"), "group-delete", name]
        groupProc.running=true
    }
    function moveServerToGroup(id, newGroup) {
        groupProc.command=["python3", root.scriptPath("omarchy-remmina-servers"), "move", id, newGroup]
        groupProc.running=true
    }
    function setGroupGlyph(name, glyph) {
        groupProc.command=["python3", root.scriptPath("omarchy-remmina-servers"), "group-glyph", name, glyph]
        groupProc.running=true
    }

    // ── Import ──
    Process { id: importProc; stdout: StdioCollector {waitForEnd:true}
        onExited: function(c){
            root.busy=false
            try {
                var o=JSON.parse(stdout.text.trim())
                if (o.imported!==undefined) {
                    root.lastImport = "Imported "+o.imported+" / skipped "+o.skipped
                    if (o.errors && o.errors.length) root.lastError=o.errors.join("; ")
                    else root.lastError=""
                    root.refresh()
                } else root.lastError=stdout.text.trim()
            } catch(e){ root.lastError=stdout.text.trim() }
        }
    }
    function importCsv(path) {
        root.busy=true
        importProc.command=["python3", root.scriptPath("omarchy-remmina-import"), "csv", path]
        importProc.running=true
    }
    function importTxt(path) {
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

    // ── Tray fix ──
    Process {
        id: trayFixProc
        command: ["bash", root.scriptPath("omarchy-remmina-tray-fix")]
        stdout: StdioCollector {waitForEnd:true}
        onExited: function(c){}
    }
    function fixTray() { trayFixProc.running=true }

    // ── File pickers (zenity) ──
    Process {
        id: csvPicker
        command: ["zenity","--file-selection","--title=Select CSV/TXT file","--file-filter=CSV | *.csv *.txt *.TXT","--file-filter=All | *"]
        stdout: StdioCollector {waitForEnd:true}
        onExited: function(code){
            if (code===0) {
                var p=stdout.text.trim()
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
        stdout: StdioCollector {waitForEnd:true}
        onExited: function(code){
            if (code===0) {
                var p=stdout.text.trim()
                if (p) root.importJson(p)
            }
        }
    }
    function pickJsonImport() { jsonPicker.running=true }
    function importJson(path) {
        root.busy=true
        importProc.command=["python3", root.scriptPath("omarchy-remmina-import"), "json", path]
        importProc.running=true
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
