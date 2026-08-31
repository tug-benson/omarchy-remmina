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

    function recalcStats() {
        var total = servers.length
        var win=0, lin=0
        var groups={}
        for (var i=0;i<servers.length;i++) {
            var s=servers[i]
            var p=(s.protocol||"").toUpperCase()
            if (p==="RDP") win++
            else if (p==="SSH" || p==="VNC" || p==="SPICE" || p==="SFTP") lin++
            var g=s.group||"General"
            groups[g]=(groups[g]||0)+1
        }
        root.totalCount=total
        root.windowsCount=win
        root.linuxCount=lin
        root.otherCount=Math.max(0,total-win-lin)
        var arr=[]
        var keys=Object.keys(groups).sort()
        for (var j=0;j<keys.length;j++) arr.push({group: keys[j], count: groups[keys[j]]})
        root.groupCounts=arr
    }

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
        }
    }
    function launchServer(id) {
        root.lastError=""
        launchProc.command = ["python3", root.scriptPath("omarchy-remmina-launch"), id]
        launchProc.running=true
    }
    function launchDirect(protocol, host, port, username) {
        launchProc.command = ["python3", root.scriptPath("omarchy-remmina-launch"), "--direct", protocol, host, port||"-", username||"-"]
        launchProc.running=true
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

    // Helpers for UI: grouped model
    function serversForGroup(g) {
        var q=(root.searchText||"").toLowerCase().trim()
        var out=[]
        for (var i=0;i<root.filteredServers.length;i++) {
            var s=root.filteredServers[i]
            if ((s.group||"General")===g) out.push(s)
        }
        return out
    }
}
