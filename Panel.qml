pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
    id: root
    moduleName: "Remmina Hub"
    manageIpc: false

    property var hostWidget: null
    property var anchorItem: null

    readonly property var service: hostWidget && hostWidget.service
        ? hostWidget.service
        : (bar && bar.shell && typeof bar.shell.serviceFor === "function"
            ? (bar.shell.serviceFor("io.github.tug-benson.remmina") || bar.shell.serviceFor("remmina")) : null)

    // theme
    readonly property color cAccent: Color.accent
    readonly property color cMuted: Color.muted
    readonly property color cFg: Color.foreground
    readonly property color cBg: Color.background
    readonly property color cUrgent: Color.urgent
    readonly property string fontFam: Style.font.family
    readonly property int titleSize: Style.font.title
    readonly property int bodySize: Style.font.body
    readonly property int capSize: Style.font.caption

    // confirm dialog state
    property string confirmTargetId: ""
    property string confirmTargetName: ""
    property bool confirmVisible: false
    // group edit state
    property string editingGroup: ""
    property string editingGroupText: ""
    property string newGroupName: ""
    property string newGroupGlyph: "󰉋"
    property bool glyphPickerVisible: false
    property string pickingGroup: ""
    property string glyphFilter: ""
    property string editId: ""
    property string formName: ""
    property string formHost: ""
    property string formProto: "RDP"
    property string formPort: ""
    property string formUser: ""
    property string formDomain: ""
    property string formGroup: ""
    property string formNotes: ""
    property string formError: ""

    function resetForm() {
        editId=""; formName=""; formHost=""; formProto="RDP"; formPort=""; formUser=""; formDomain=""; formGroup=""; formNotes=""; formError=""
    }
    function openAdd() {
        resetForm()
        if (service) service.showAddForm = true
    }
    function openEdit(srv) {
        editId=srv.id; formName=srv.name; formHost=srv.host; formProto=srv.protocol; formPort=srv.port||""; formUser=srv.username||""; formDomain=srv.domain||""; formGroup=srv.group||""; formNotes=srv.notes||""; formError=""
        if (service) service.showAddForm = true
    }
    function submitForm() {
        formError=""
        if (!formName.trim()) { formError="Name required"; return }
        if (!formHost.trim()) { formError="Host/IP required"; return }
        if (formPort && !/^\d+$/.test(formPort.trim())) { formError="Port must be numeric"; return }
        var obj = {
            name: formName.trim(),
            host: formHost.trim(),
            protocol: formProto,
            port: formPort.trim(),
            username: formUser.trim(),
            domain: formDomain.trim(),
            group: formGroup.trim() || "General",
            notes: formNotes.trim()
        }
        if (editId) service.updateServer(editId, obj)
        else service.addServer(obj)
        // close after small delay? service will clear busy, we close immediately optimistic
        // but keep form open until service refreshes; easier close now.
        if (service) service.showAddForm = false
        resetForm()
    }

    function protoGlyph(p) {
        if (p==="SSH") return ""   // terminal
        if (p==="RDP") return ""   // windows
        if (p==="VNC") return "󰢹"   // display
        if (p==="SPICE") return "󰹑" // virt
        if (p==="SFTP") return "󰉋"
        return "󰢹"
    }
    function protoColor(p) {
        if (p==="RDP") return cAccent
        if (p==="SSH") return cFg
        if (p==="VNC") return Util.alpha(cAccent,0.9)
        if (p==="SPICE") return cMuted
        return cMuted
    }

    KeyboardPanel {
        id: panel
        anchorItem: root.anchorItem
        owner: root.hostWidget || remminaRoot
        bar: root.bar
        open: root.opened
        focusTarget: keyCatcher
        contentWidth: Style.space(380)
        contentHeight: panel.fittedContentHeight(flick.contentHeight + Style.space(20))

        PanelKeyCatcher {
            id: keyCatcher
            anchors.fill: parent
            onCloseRequested: root.close()
            onTabRequested: function(dir){ root.switchPanel(dir) }

            Flickable {
                id: flick
                anchors.fill: parent
                contentWidth: width
                contentHeight: col.implicitHeight + Style.space(12)
                clip: true
                ColumnLayout {
                    id: col
                    width: flick.width - Style.space(16)
                    x: Style.space(8)
                    y: Style.space(8)
                    spacing: Style.space(8)

                    // ── Header ──
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Style.space(6)
                        Label {
                            textFormat: Text.PlainText
                            text: "󰢹"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: root.titleSize + 6
                            color: cAccent
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            Label {
                                textFormat: Text.PlainText
                                text: "Remmina Hub"
                                font.family: fontFam
                                font.pixelSize: titleSize + 1
                                font.bold: true
                                color: cFg
                            }
                            Label {
                                textFormat: Text.PlainText
                                text: service ? (service.totalCount + " servers") : "--"
                                font.family: fontFam
                                font.pixelSize: capSize
                                color: cMuted
                                opacity: 0.9
                            }
                        }
                        Button {
                            iconText: ""
                            fontFamily: "JetBrainsMono Nerd Font"
                            fontSize: capSize
                            tooltipText: "Refresh"
                            Layout.preferredWidth: Style.space(26)
                            onClicked: if (service) service.refresh()
                        }
                    }

                    // ── Counters (ring gauges quadrant-style, centred) ──
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignHCenter
                        spacing: Style.space(14)
                        Layout.topMargin: Style.space(4)
                        Layout.preferredHeight: Style.space(90)
                        Gauge {
                            Layout.alignment: Qt.AlignHCenter
                            size: Style.space(74)
                            thickness: Style.space(7)
                            glyph: ""
                            glyphSize: Style.font.title + 6
                            label: service ? String(service.windowsCount) : "0"
                            color: cAccent
                            trackColor: Util.alpha(cAccent, 0.12)
                            fraction: service && service.totalCount > 0 ? service.windowsCount / service.totalCount : 0
                        }
                        Gauge {
                            Layout.alignment: Qt.AlignHCenter
                            size: Style.space(74)
                            thickness: Style.space(7)
                            glyph: ""
                            glyphSize: Style.font.title + 6
                            label: service ? String(service.linuxCount) : "0"
                            color: cFg
                            trackColor: Util.alpha(cFg, 0.10)
                            fraction: service && service.totalCount > 0 ? service.linuxCount / service.totalCount : 0
                        }
                        Gauge {
                            Layout.alignment: Qt.AlignHCenter
                            size: Style.space(74)
                            thickness: Style.space(7)
                            glyph: "󰢹"
                            glyphSize: Style.font.title + 4
                            label: service ? String(service.totalCount) : "0"
                            color: cMuted
                            trackColor: Util.alpha(cMuted, 0.10)
                            fraction: service && service.totalCount > 0 ? 1 : 0
                        }
                    }

                    // ── Search ──
                    TextField {
                        id: searchField
                        Layout.fillWidth: true
                        placeholderText: "  Filter by name, host, group..."
                        font.family: fontFam
                        font.pixelSize: bodySize
                        text: service ? service.searchText : ""
                        onTextChanged: if (service) service.searchText = text
                    }

                    // ── Actions ──
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Style.space(6)
                        Button {
                            text: "＋ Add Server"
                            fontSize: bodySize
                            Layout.fillWidth: true
                            onClicked: root.openAdd()
                        }
                        Button {
                            iconText: ""
                            fontFamily: "JetBrainsMono Nerd Font"
                            fontSize: bodySize
                            tooltipText: "Import CSV/TXT"
                            Layout.preferredWidth: Style.space(28)
                            onClicked: if (service) service.pickImport()
                        }
                        Button {
                            iconText: ""
                            fontFamily: "JetBrainsMono Nerd Font"
                            fontSize: bodySize
                            tooltipText: "Import Remmina files"
                            Layout.preferredWidth: Style.space(28)
                            onClicked: if (service) service.importRemmina()
                        }
                        Button {
                            iconText: ""
                            fontFamily: "JetBrainsMono Nerd Font"
                            fontSize: bodySize
                            tooltipText: "Import ~/.ssh/config"
                            Layout.preferredWidth: Style.space(28)
                            onClicked: if (service) service.importSsh()
                        }
                        Button {
                            iconText: ""
                            fontFamily: "JetBrainsMono Nerd Font"
                            fontSize: bodySize
                            tooltipText: "Import JSON"
                            Layout.preferredWidth: Style.space(28)
                            onClicked: if (service) service.pickJsonImport()
                        }
                    }
                    // Collapse controls + Add Group
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Style.space(6)
                        Label { Layout.fillWidth: true; textFormat: Text.PlainText; text: "Groups"; font.family: fontFam; font.pixelSize: capSize; color: cMuted; opacity: 0.8 }
                        Label { textFormat: Text.PlainText; text: " Expand"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: capSize; color: cAccent
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if(service) service.expandAll() } }
                        Label { textFormat: Text.PlainText; text: " Collapse"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: capSize; color: cAccent
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if(service) service.collapseAll() } }
                    }
                    // Add Group
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Style.space(6)
                        TextField {
                            Layout.fillWidth: true
                            placeholderText: "New group (e.g. Hyperviseur)"
                            text: root.newGroupName
                            font.family: fontFam
                            font.pixelSize: capSize
                            onTextChanged: root.newGroupName = text
                            onAccepted: {
                                if (text.trim() && service) {
                                    service.createGroup(text.trim())
                                    root.newGroupName = ""
                                    text = ""
                                }
                            }
                        }
                        Button {
                            iconText: root.newGroupGlyph || "󰉋"
                            fontFamily: "JetBrainsMono Nerd Font"
                            fontSize: bodySize
                            tooltipText: "Choose glyph"
                            Layout.preferredWidth: Style.space(30)
                            onClicked: {
                                root.pickingGroup = "__new__"
                                root.glyphPickerVisible = true
                            }
                        }
                        Button {
                            text: "Add"
                            fontSize: capSize
                            Layout.preferredWidth: Style.space(50)
                            onClicked: {
                                if (root.newGroupName.trim() && service) {
                                    service.createGroup(root.newGroupName.trim())
                                    // If glyph chosen, set it
                                    if (root.newGroupGlyph) {
                                        // Use group-glyph command via Service (we'll add)
                                        service.setGroupGlyph(root.newGroupName.trim(), root.newGroupGlyph)
                                    }
                                    root.newGroupName = ""
                                    root.newGroupGlyph = "󰉋"
                                }
                            }
                        }
                    }

                    // errors
                    Label {
                        Layout.fillWidth: true
                        visible: (service && service.lastError) ? true : false
                        textFormat: Text.PlainText
                        text: service ? service.lastError : ""
                        font.family: fontFam; font.pixelSize: capSize; color: cUrgent; wrapMode: Text.Wrap
                    }
                    Label {
                        Layout.fillWidth: true
                        visible: (service && service.lastImport) ? true : false
                        textFormat: Text.PlainText
                        text: service ? service.lastImport : ""
                        font.family: fontFam; font.pixelSize: capSize; color: cAccent; opacity: 0.9; wrapMode: Text.Wrap
                    }

                    // separator
                    Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Qt.rgba(1,1,1,0.08) }

                    // ── Help: CSV format ──
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Style.space(2)
                        visible: service ? service.showImportHelp : false
                        Label { textFormat: Text.PlainText; text: "CSV format expected:"; font.family: fontFam; font.pixelSize: capSize; font.bold: true; color: cFg }
                        Label { Layout.fillWidth: true; textFormat: Text.PlainText; text: "name,host,protocol,port,username,group,notes"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: capSize-1; color: cMuted; wrapMode: Text.Wrap }
                        Label { Layout.fillWidth: true; textFormat: Text.PlainText; text: "Example: srv01,host.example.com,RDP,3389,admin,Windows,prod"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: capSize-1; color: cMuted; wrapMode: Text.Wrap }
                        Label { Layout.fillWidth: true; textFormat: Text.PlainText; text: "TXT fallback: name;host;protocol;port;username;group"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: capSize-1; color: cMuted; wrapMode: Text.Wrap }
                        Button { text: "Hide"; fontSize: capSize; Layout.preferredWidth: Style.space(60); onClicked: if(service) service.showImportHelp=false }
                    }
                    RowLayout {
                        Layout.fillWidth: false
                        Label { textFormat: Text.PlainText; text: "ℹ CSV/TXT help"; font.family: fontFam; font.pixelSize: capSize; color: cAccent; opacity: 0.9
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if(service) service.showImportHelp = !service.showImportHelp } }
                    }

                    // ── Add / Edit form ──
                    Rectangle {
                        Layout.fillWidth: true
                        visible: service ? service.showAddForm : false
                        radius: Style.space(6)
                        color: Util.alpha(cBg, 0.6)
                        border.color: Util.alpha(cAccent, 0.35)
                        border.width: 1
                        implicitHeight: formCol.implicitHeight + Style.space(16)
                        ColumnLayout {
                            id: formCol
                            anchors.fill: parent
                            anchors.margins: Style.space(8)
                            spacing: Style.space(6)
                            Label { textFormat: Text.PlainText; text: root.editId ? "Edit Server" : "Add Server"; font.family: fontFam; font.pixelSize: bodySize; font.bold: true; color: cFg }
                            GridLayout {
                                columns: 2
                                columnSpacing: Style.space(6)
                                rowSpacing: Style.space(4)
                                Layout.fillWidth: true
                                Label { textFormat: Text.PlainText; text: "Name *"; font.family: fontFam; font.pixelSize: capSize; color: cMuted }
                                TextField { Layout.fillWidth: true; text: root.formName; placeholderText: "srv-win-01"; font.pixelSize: capSize; onTextChanged: root.formName=text }
                                Label { textFormat: Text.PlainText; text: "Host *"; font.family: fontFam; font.pixelSize: capSize; color: cMuted }
                                TextField { Layout.fillWidth: true; text: root.formHost; placeholderText: "host.example.com"; font.pixelSize: capSize; onTextChanged: root.formHost=text }
                                Label { textFormat: Text.PlainText; text: "Protocol"; font.family: fontFam; font.pixelSize: capSize; color: cMuted }
                                Dropdown {
                                    Layout.fillWidth: true
                                    label: ""
                                    showLabel: false
                                    value: root.formProto
                                    options: ["RDP","SSH","VNC","SPICE"]
                                    onChanged: function(v){ root.formProto=v }
                                }
                                Label { textFormat: Text.PlainText; text: "Port"; font.family: fontFam; font.pixelSize: capSize; color: cMuted }
                                TextField { Layout.fillWidth: true; text: root.formPort; placeholderText: "3389 / 22 / 5900"; font.pixelSize: capSize; inputMethodHints: Qt.ImhDigitsOnly; onTextChanged: root.formPort=text }
                                Label { textFormat: Text.PlainText; text: "Username"; font.family: fontFam; font.pixelSize: capSize; color: cMuted }
                                TextField { Layout.fillWidth: true; text: root.formUser; placeholderText: "admin"; font.pixelSize: capSize; onTextChanged: root.formUser=text }
                                Label { textFormat: Text.PlainText; text: "Domain"; font.family: fontFam; font.pixelSize: capSize; color: cMuted }
                                TextField { Layout.fillWidth: true; text: root.formDomain; placeholderText: "EXAMPLE (for RDP)"; font.pixelSize: capSize; onTextChanged: root.formDomain=text }
                                Label { textFormat: Text.PlainText; text: "Group"; font.family: fontFam; font.pixelSize: capSize; color: cMuted }
                                TextField { Layout.fillWidth: true; text: root.formGroup; placeholderText: "Windows / Linux / Infra"; font.pixelSize: capSize; onTextChanged: root.formGroup=text }
                            }
                            TextField { Layout.fillWidth: true; text: root.formNotes; placeholderText: "Notes (optional)"; font.pixelSize: capSize; onTextChanged: root.formNotes=text }
                            Label { visible: root.formError!==""; textFormat: Text.PlainText; text: root.formError; font.family: fontFam; font.pixelSize: capSize; color: cUrgent }
                            RowLayout {
                                Layout.fillWidth: true; spacing: Style.space(6)
                                Button { text: "Cancel"; fontSize: capSize; Layout.fillWidth: true; onClicked: { if(service) service.showAddForm=false; root.resetForm() } }
                                Button { text: root.editId ? "Update" : "Add"; fontSize: capSize; Layout.fillWidth: true; onClicked: root.submitForm() }
                            }
                        }
                    }

                    // ── Server list grouped & collapsible (sections) ──
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Style.space(8)
                        visible: service ? service.groupCounts.length>0 : false

                        // Virtual groups at top: Favorites (󰓎) Recent (󰧓)
                        Repeater {
                            model: service ? service.groupCounts.filter(function(g){ return g.group==="Favorites" || g.group==="Recent" }) : []
                            delegate: ColumnLayout {
                                id: grpDel
                                required property var modelData
                                required property int index
                                readonly property string grpName: modelData.group
                                readonly property int grpCount: modelData.count
                                readonly property bool collapsed: service ? service.isCollapsed(grpName) : false
                                Layout.fillWidth: true
                                spacing: Style.space(4)
                                Rectangle {
                                    id: headerRect
                                    Layout.fillWidth: true
                                    implicitHeight: Style.space(28)
                                    radius: Style.space(4)
                                    color: collapsed ? Util.alpha(cAccent,0.06) : Util.alpha(cAccent,0.10)
                                    border.color: Util.alpha(cAccent,0.25)
                                    border.width: 1
                                    DropArea {
                                        anchors.fill: parent
                                        onDropped: function(drop) {
                                            var sid = drop.text
                                            if (sid && service) service.moveServerToGroup(sid, grpDel.grpName)
                                        }
                                    }
                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: Style.space(8)
                                        anchors.rightMargin: Style.space(8)
                                        spacing: Style.space(6)
                                        Label {
                                            textFormat: Text.PlainText
                                            text: grpDel.collapsed ? "" : ""
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: capSize
                                            color: cAccent
                                        }
                                        Label {
                                            textFormat: Text.PlainText
                                            text: service ? service.groupGlyph(grpDel.grpName) : "󰉋"
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: bodySize
                                            color: cAccent
                                        }
                                        // Editable group name
                                        TextField {
                                            visible: root.editingGroup === grpDel.grpName
                                            Layout.fillWidth: true
                                            text: root.editingGroupText
                                            font.family: fontFam
                                            font.pixelSize: bodySize
                                            onTextChanged: root.editingGroupText = text
                                            onAccepted: {
                                                var t = text.trim()
                                                if (t && t !== grpDel.grpName && service) service.renameGroup(grpDel.grpName, t)
                                                root.editingGroup = ""
                                            }
                                            Component.onCompleted: if (visible) forceActiveFocus()
                                        }
                                        Label {
                                            visible: root.editingGroup !== grpDel.grpName
                                            Layout.fillWidth: true
                                            textFormat: Text.PlainText
                                            text: grpDel.grpName + "  (" + grpDel.grpCount + ")"
                                            font.family: fontFam
                                            font.pixelSize: bodySize
                                            font.bold: true
                                            color: cFg
                                            elide: Text.ElideRight
                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: if(service && !service.isVirtualGroup(grpDel.grpName)) {
                                                    root.editingGroup = grpDel.grpName
                                                    root.editingGroupText = grpDel.grpName
                                                } else if(service) service.toggleGroup(grpDel.grpName)
                                                onDoubleClicked: if(service && !service.isVirtualGroup(grpDel.grpName)) {
                                                    root.editingGroup = grpDel.grpName
                                                    root.editingGroupText = grpDel.grpName
                                                }
                                            }
                                        }
                                        // Glyph picker for custom groups
                                        Button {
                                            visible: !service.isVirtualGroup(grpDel.grpName) && !service.isDefaultGroup(grpDel.grpName)
                                            iconText: ""
                                            fontFamily: "JetBrainsMono Nerd Font"
                                            fontSize: capSize
                                            tooltipText: "Choose glyph"
                                            Layout.preferredWidth: Style.space(22)
                                            Layout.preferredHeight: Style.space(22)
                                            onClicked: {
                                                root.pickingGroup = grpDel.grpName
                                                root.glyphPickerVisible = true
                                            }
                                        }
                                        Button {
                                            visible: !service.isVirtualGroup(grpDel.grpName) && !service.isDefaultGroup(grpDel.grpName)
                                            iconText: ""
                                            fontFamily: "JetBrainsMono Nerd Font"
                                            fontSize: capSize
                                            tooltipText: "Delete group"
                                            Layout.preferredWidth: Style.space(22)
                                            Layout.preferredHeight: Style.space(22)
                                            onClicked: if(service) service.deleteGroup(grpDel.grpName)
                                        }
                                        Rectangle {
                                            width: Style.space(22); height: Style.space(16); radius: 8
                                            color: Util.alpha(cAccent,0.18)
                                            Label { anchors.centerIn: parent; textFormat: Text.PlainText; text: String(grpDel.grpCount); font.family: fontFam; font.pixelSize: capSize-1; color: cAccent }
                                        }
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        propagateComposedEvents: true
                                        onClicked: function(mouse) {
                                            // Let child MouseAreas handle edit, otherwise toggle
                                            if (mouse.button === Qt.LeftButton && root.editingGroup !== grpDel.grpName) {
                                                if(service) service.toggleGroup(grpDel.grpName)
                                            }
                                        }
                                    }
                                }

                                // filtered empty hint
                                Label {
                                    Layout.fillWidth: true
                                    visible: !grpDel.collapsed && service && service.serversForGroup(grpDel.grpName).length===0
                                    textFormat: Text.PlainText
                                    text: "No match for current filter"
                                    font.family: fontFam; font.pixelSize: capSize; color: cMuted; opacity: 0.6
                                    leftPadding: Style.space(8)
                                }

                                // server rows
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: Style.space(4)
                                    visible: !grpDel.collapsed
                                    Repeater {
                                        model: service ? service.serversForGroup(grpDel.grpName) : []
                                        delegate: Rectangle {
                                            id: rowDel
                                            required property var modelData
                                            required property int index
                                            Layout.fillWidth: true
                                            implicitHeight: Style.space(38)
                                            radius: Style.space(6)
                                            color: dragArea.containsMouse ? Util.alpha(cAccent,0.12) : Util.alpha(cFg, 0.04)
                                            border.color: dragArea.containsMouse ? Util.alpha(cAccent,0.30) : Util.alpha(cFg, 0.08)
                                            border.width: 1
                                            // Drag support
                                            Drag.active: dragArea.drag.active
                                            Drag.hotSpot.x: width/2
                                            Drag.hotSpot.y: height/2
                                            Drag.mimeData: { "text/plain": modelData.id }
                                            Drag.dragType: Drag.Automatic
                                            opacity: Drag.active ? 0.6 : 1.0

                                            // Drag area (whole row, behind buttons but with higher z for drag handle)
                                            MouseArea {
                                                id: dragArea
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                drag.target: rowDel
                                                drag.axis: Drag.XAndYAxis
                                                onPressed: dragArea.drag.active = true
                                                onReleased: dragArea.drag.active = false
                                                propagateComposedEvents: true
                                                onClicked: function(mouse) { mouse.accepted = false }
                                            }
                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.leftMargin: Style.space(8)
                                                anchors.rightMargin: Style.space(4)
                                                spacing: Style.space(6)

                                                // Drag handle
                                                Label {
                                                    textFormat: Text.PlainText
                                                    text: "󰍝"
                                                    font.family: "JetBrainsMono Nerd Font"
                                                    font.pixelSize: capSize
                                                    color: cMuted
                                                    opacity: 0.5
                                                    MouseArea {
                                                        anchors.fill: parent
                                                        cursorShape: Qt.ClosedHandCursor
                                                        drag.target: rowDel
                                                        onPressed: dragArea.drag.active = true
                                                        onReleased: dragArea.drag.active = false
                                                    }
                                                }
                                                // protocol glyph box
                                                Rectangle {
                                                    width: Style.space(28); height: Style.space(28); radius: Style.space(4)
                                                    color: Util.alpha(root.protoColor(modelData.protocol), 0.14)
                                                    border.color: Util.alpha(root.protoColor(modelData.protocol), 0.35)
                                                    border.width: 1
                                                    Label {
                                                        anchors.centerIn: parent
                                                        textFormat: Text.PlainText
                                                        text: root.protoGlyph(modelData.protocol)
                                                        font.family: "JetBrainsMono Nerd Font"
                                                        font.pixelSize: bodySize
                                                        color: root.protoColor(modelData.protocol)
                                                    }
                                                }

                                                ColumnLayout {
                                                    Layout.fillWidth: true
                                                    spacing: 0
                                                    Label {
                                                        Layout.fillWidth: true
                                                        textFormat: Text.PlainText
                                                        text: modelData.name
                                                        font.family: fontFam
                                                        font.pixelSize: bodySize
                                                        font.bold: false
                                                        color: cFg
                                                        elide: Text.ElideRight
                                                    }
                                                    Label {
                                                        Layout.fillWidth: true
                                                        textFormat: Text.PlainText
                                                        text: (modelData.domain && modelData.username ? modelData.domain + "\\" + modelData.username + "@" : modelData.username ? modelData.username+"@" : "") + modelData.host + (modelData.port ? ":"+modelData.port : "") + " · " + modelData.protocol
                                                        font.family: fontFam
                                                        font.pixelSize: capSize
                                                        color: cMuted
                                                        elide: Text.ElideRight
                                                    }
                                                }

                                                // actions stacked right
                                                RowLayout {
                                                    spacing: Style.space(2)
                                                    // Favorite star
                                                    Button {
                                                        iconText: modelData.favorite === true ? "" : ""
                                                        fontFamily: "JetBrainsMono Nerd Font"
                                                        fontSize: capSize
                                                        tooltipText: modelData.favorite === true ? "Remove from favorites" : "Add to favorites"
                                                        Layout.preferredWidth: Style.space(26)
                                                        Layout.preferredHeight: Style.space(26)
                                                        onClicked: if(service) service.toggleFavorite(modelData.id)
                                                    }
                                                    // Launch
                                                    Button {
                                                        iconText: modelData.protocol==="SSH" ? "" : modelData.protocol==="RDP" ? "" : modelData.protocol==="VNC" ? "󰢹" : "󰹑"
                                                        fontFamily: "JetBrainsMono Nerd Font"
                                                        fontSize: bodySize
                                                        tooltipText: "Connect ("+modelData.protocol+")"
                                                        Layout.preferredWidth: Style.space(30)
                                                        Layout.preferredHeight: Style.space(26)
                                                        onClicked: if(service) service.launchServer(modelData.id)
                                                    }
                                                    // Edit
                                                    Button {
                                                        iconText: ""
                                                        fontFamily: "JetBrainsMono Nerd Font"
                                                        fontSize: capSize
                                                        tooltipText: "Edit"
                                                        Layout.preferredWidth: Style.space(26)
                                                        Layout.preferredHeight: Style.space(26)
                                                        onClicked: root.openEdit(modelData)
                                                    }
                                                    // Delete
                                                    Button {
                                                        iconText: ""
                                                        fontFamily: "JetBrainsMono Nerd Font"
                                                        fontSize: capSize
                                                        tooltipText: "Delete"
                                                        Layout.preferredWidth: Style.space(26)
                                                        Layout.preferredHeight: Style.space(26)
                                                        onClicked: {
                                                            root.confirmTargetId = modelData.id
                                                            root.confirmTargetName = modelData.name
                                                            root.confirmVisible = true
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Separator below virtual groups
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 1
                        visible: service ? service.groupCounts.filter(function(g){ return g.group==="Favorites" || g.group==="Recent" }).length>0 : false
                        color: Qt.rgba(1,1,1,0.08)
                    }
                    // Custom groups (INFRA, Hyperviseur, etc.) — editable, glyph picker, drag&drop
                    Repeater {
                        model: service ? service.groupCounts.filter(function(g){ return g.group!=="Favorites" && g.group!=="Recent" && g.group!=="Windows" && g.group!=="Linux" }) : []
                        delegate: ColumnLayout {
                            id: grpDelCustom
                            required property var modelData
                            required property int index
                            readonly property string grpName: modelData.group
                            readonly property int grpCount: modelData.count
                            readonly property bool collapsed: service ? service.isCollapsed(grpName) : false
                            Layout.fillWidth: true
                            spacing: Style.space(4)
                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: Style.space(28)
                                radius: Style.space(4)
                                color: collapsed ? Util.alpha(cAccent,0.06) : Util.alpha(cAccent,0.10)
                                border.color: Util.alpha(cAccent,0.25)
                                border.width: 1
                                DropArea {
                                    anchors.fill: parent
                                    onDropped: function(drop) {
                                        var sid = drop.text
                                        if (sid && service) service.moveServerToGroup(sid, grpDelCustom.grpName)
                                    }
                                }
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: Style.space(8)
                                    anchors.rightMargin: Style.space(8)
                                    spacing: Style.space(6)
                                    Label { textFormat: Text.PlainText; text: grpDelCustom.collapsed ? "" : ""; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: capSize; color: cAccent }
                                    Label { textFormat: Text.PlainText; text: service ? service.groupGlyph(grpDelCustom.grpName) : "󰉋"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: bodySize; color: cAccent }
                                    TextField {
                                        visible: root.editingGroup === grpDelCustom.grpName
                                        Layout.fillWidth: true
                                        text: root.editingGroupText
                                        font.family: fontFam; font.pixelSize: bodySize
                                        onTextChanged: root.editingGroupText = text
                                        onAccepted: {
                                            var t = text.trim()
                                            if (t && t !== grpDelCustom.grpName && service) service.renameGroup(grpDelCustom.grpName, t)
                                            root.editingGroup = ""
                                        }
                                        Component.onCompleted: if (visible) forceActiveFocus()
                                    }
                                    Label {
                                        visible: root.editingGroup !== grpDelCustom.grpName
                                        Layout.fillWidth: true
                                        textFormat: Text.PlainText
                                        text: grpDelCustom.grpName + "  (" + grpDelCustom.grpCount + ")"
                                        font.family: fontFam; font.pixelSize: bodySize; font.bold: true; color: cFg; elide: Text.ElideRight
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: { root.editingGroup = grpDelCustom.grpName; root.editingGroupText = grpDelCustom.grpName }
                                            onDoubleClicked: { root.editingGroup = grpDelCustom.grpName; root.editingGroupText = grpDelCustom.grpName }
                                        }
                                    }
                                    Button {
                                        iconText: ""
                                        fontFamily: "JetBrainsMono Nerd Font"
                                        fontSize: capSize
                                        tooltipText: "Choose glyph"
                                        Layout.preferredWidth: Style.space(22)
                                        Layout.preferredHeight: Style.space(22)
                                        onClicked: { root.pickingGroup = grpDelCustom.grpName; root.glyphPickerVisible = true }
                                    }
                                    Button {
                                        iconText: ""
                                        fontFamily: "JetBrainsMono Nerd Font"
                                        fontSize: capSize
                                        tooltipText: "Delete group"
                                        Layout.preferredWidth: Style.space(22)
                                        Layout.preferredHeight: Style.space(22)
                                        onClicked: if(service) service.deleteGroup(grpDelCustom.grpName)
                                    }
                                    Rectangle { width: Style.space(22); height: Style.space(16); radius: 8; color: Util.alpha(cAccent,0.18); Label { anchors.centerIn: parent; textFormat: Text.PlainText; text: String(grpDelCustom.grpCount); font.family: fontFam; font.pixelSize: capSize-1; color: cAccent } }
                                }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; propagateComposedEvents: true; onClicked: function(mouse){ if (mouse.button===Qt.LeftButton && root.editingGroup!==grpDelCustom.grpName) if(service) service.toggleGroup(grpDelCustom.grpName) } }
                            }
                            Label {
                                Layout.fillWidth: true
                                visible: !grpDelCustom.collapsed && service && service.serversForGroup(grpDelCustom.grpName).length===0
                                textFormat: Text.PlainText; text: "No match for current filter"
                                font.family: fontFam; font.pixelSize: capSize; color: cMuted; opacity: 0.6; leftPadding: Style.space(8)
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: Style.space(4)
                                visible: !grpDelCustom.collapsed
                                Repeater {
                                    model: service ? service.serversForGroup(grpDelCustom.grpName) : []
                                    delegate: Rectangle {
                                        id: rowDelCustom
                                        required property var modelData
                                        required property int index
                                        Layout.fillWidth: true
                                        implicitHeight: Style.space(38)
                                        radius: Style.space(6)
                                        color: dragAreaCustom.containsMouse ? Util.alpha(cAccent,0.12) : Util.alpha(cFg, 0.04)
                                        border.color: dragAreaCustom.containsMouse ? Util.alpha(cAccent,0.30) : Util.alpha(cFg, 0.08)
                                        border.width: 1
                                        Drag.active: dragAreaCustom.drag.active
                                        Drag.hotSpot.x: width/2
                                        Drag.hotSpot.y: height/2
                                        Drag.mimeData: { "text/plain": modelData.id }
                                        Drag.dragType: Drag.Automatic
                                        opacity: Drag.active ? 0.6 : 1.0
                                        MouseArea {
                                            id: dragAreaCustom
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            drag.target: rowDelCustom
                                            onPressed: dragAreaCustom.drag.active = true
                                            onReleased: dragAreaCustom.drag.active = false
                                            propagateComposedEvents: true
                                            onClicked: function(mouse){ mouse.accepted=false }
                                        }
                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: Style.space(8)
                                            anchors.rightMargin: Style.space(4)
                                            spacing: Style.space(6)
                                            Label { textFormat: Text.PlainText; text: "󰍝"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: capSize; color: cMuted; opacity: 0.5; MouseArea { anchors.fill: parent; cursorShape: Qt.ClosedHandCursor; drag.target: rowDelCustom; onPressed: dragAreaCustom.drag.active=true; onReleased: dragAreaCustom.drag.active=false } }
                                            Rectangle { width: Style.space(28); height: Style.space(28); radius: Style.space(4); color: Util.alpha(root.protoColor(modelData.protocol),0.14); border.color: Util.alpha(root.protoColor(modelData.protocol),0.35); border.width: 1; Label { anchors.centerIn: parent; textFormat: Text.PlainText; text: root.protoGlyph(modelData.protocol); font.family: "JetBrainsMono Nerd Font"; font.pixelSize: bodySize; color: root.protoColor(modelData.protocol) } }
                                            ColumnLayout { Layout.fillWidth: true; spacing: 0; Label { Layout.fillWidth: true; textFormat: Text.PlainText; text: modelData.name; font.family: fontFam; font.pixelSize: bodySize; color: cFg; elide: Text.ElideRight } Label { Layout.fillWidth: true; textFormat: Text.PlainText; text: (modelData.domain && modelData.username ? modelData.domain+"\\"+modelData.username+"@" : modelData.username ? modelData.username+"@" : "")+modelData.host+(modelData.port ? ":"+modelData.port:"")+" · "+modelData.protocol; font.family: fontFam; font.pixelSize: capSize; color: cMuted; elide: Text.ElideRight } }
                                            RowLayout { spacing: Style.space(2); Button { iconText: modelData.favorite===true ? "" : ""; fontFamily: "JetBrainsMono Nerd Font"; fontSize: capSize; tooltipText: modelData.favorite===true ? "Remove from favorites" : "Add to favorites"; Layout.preferredWidth: Style.space(26); Layout.preferredHeight: Style.space(26); onClicked: if(service) service.toggleFavorite(modelData.id) } Button { iconText: modelData.protocol==="SSH" ? "" : modelData.protocol==="RDP" ? "" : modelData.protocol==="VNC" ? "󰢹" : "󰹑"; fontFamily: "JetBrainsMono Nerd Font"; fontSize: bodySize; tooltipText: "Connect ("+modelData.protocol+")"; Layout.preferredWidth: Style.space(30); Layout.preferredHeight: Style.space(26); onClicked: if(service) service.launchServer(modelData.id) } Button { iconText: ""; fontFamily: "JetBrainsMono Nerd Font"; fontSize: capSize; tooltipText: "Edit"; Layout.preferredWidth: Style.space(26); Layout.preferredHeight: Style.space(26); onClicked: root.openEdit(modelData) } Button { iconText: ""; fontFamily: "JetBrainsMono Nerd Font"; fontSize: capSize; tooltipText: "Delete"; Layout.preferredWidth: Style.space(26); Layout.preferredHeight: Style.space(26); onClicked: { root.confirmTargetId=modelData.id; root.confirmTargetName=modelData.name; root.confirmVisible=true } } }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 1
                        visible: service ? service.groupCounts.filter(function(g){ return g.group!=="Favorites" && g.group!=="Recent" && g.group!=="Windows" && g.group!=="Linux" }).length>0 : false
                        color: Qt.rgba(1,1,1,0.08)
                    }
                    // Default groups at bottom (Windows, Linux)
                    Repeater {
                        model: service ? service.groupCounts.filter(function(g){ return g.group==="Windows" || g.group==="Linux" }) : []
                        delegate: ColumnLayout {
                            id: grpDelDefault
                            required property var modelData
                            required property int index
                            readonly property string grpName: modelData.group
                            readonly property int grpCount: modelData.count
                            readonly property bool collapsed: service ? service.isCollapsed(grpName) : false
                            Layout.fillWidth: true
                            spacing: Style.space(4)
                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: Style.space(28)
                                radius: Style.space(4)
                                color: collapsed ? Util.alpha(cAccent,0.06) : Util.alpha(cAccent,0.10)
                                border.color: Util.alpha(cAccent,0.25)
                                border.width: 1
                                DropArea {
                                    anchors.fill: parent
                                    onDropped: function(drop) {
                                        var sid = drop.text
                                        if (sid && service) service.moveServerToGroup(sid, grpDelDefault.grpName)
                                    }
                                }
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: Style.space(8)
                                    anchors.rightMargin: Style.space(8)
                                    spacing: Style.space(6)
                                    Label { textFormat: Text.PlainText; text: grpDelDefault.collapsed ? "" : ""; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: capSize; color: cAccent }
                                    Label { textFormat: Text.PlainText; text: service ? service.groupGlyph(grpDelDefault.grpName) : "󰉋"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: bodySize; color: cAccent }
                                    Label { Layout.fillWidth: true; textFormat: Text.PlainText; text: grpDelDefault.grpName + "  (" + grpDelDefault.grpCount + ")"; font.family: fontFam; font.pixelSize: bodySize; font.bold: true; color: cFg; elide: Text.ElideRight }
                                    Rectangle { width: Style.space(22); height: Style.space(16); radius: 8; color: Util.alpha(cAccent,0.18); Label { anchors.centerIn: parent; textFormat: Text.PlainText; text: String(grpDelDefault.grpCount); font.family: fontFam; font.pixelSize: capSize-1; color: cAccent } }
                                }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if(service) service.toggleGroup(grpDelDefault.grpName) }
                            }
                            Label {
                                Layout.fillWidth: true
                                visible: !grpDelDefault.collapsed && service && service.serversForGroup(grpDelDefault.grpName).length===0
                                textFormat: Text.PlainText; text: "No match for current filter"
                                font.family: fontFam; font.pixelSize: capSize; color: cMuted; opacity: 0.6; leftPadding: Style.space(8)
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: Style.space(4)
                                visible: !grpDelDefault.collapsed
                                Repeater {
                                    model: service ? service.serversForGroup(grpDelDefault.grpName) : []
                                    delegate: Rectangle {
                                        id: rowDelDefault
                                        required property var modelData
                                        required property int index
                                        Layout.fillWidth: true
                                        implicitHeight: Style.space(38)
                                        radius: Style.space(6)
                                        color: dragAreaDefault.containsMouse ? Util.alpha(cAccent,0.12) : Util.alpha(cFg, 0.04)
                                        border.color: dragAreaDefault.containsMouse ? Util.alpha(cAccent,0.30) : Util.alpha(cFg, 0.08)
                                        border.width: 1
                                        Drag.active: dragAreaDefault.drag.active
                                        Drag.hotSpot.x: width/2
                                        Drag.hotSpot.y: height/2
                                        Drag.mimeData: { "text/plain": modelData.id }
                                        Drag.dragType: Drag.Automatic
                                        opacity: Drag.active ? 0.6 : 1.0
                                        MouseArea {
                                            id: dragAreaDefault
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            drag.target: rowDelDefault
                                            onPressed: dragAreaDefault.drag.active = true
                                            onReleased: dragAreaDefault.drag.active = false
                                            propagateComposedEvents: true
                                            onClicked: function(mouse){ mouse.accepted=false }
                                        }
                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: Style.space(8)
                                            anchors.rightMargin: Style.space(4)
                                            spacing: Style.space(6)
                                            Label { textFormat: Text.PlainText; text: "󰍝"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: capSize; color: cMuted; opacity: 0.5; MouseArea { anchors.fill: parent; cursorShape: Qt.ClosedHandCursor; drag.target: rowDelDefault; onPressed: dragAreaDefault.drag.active=true; onReleased: dragAreaDefault.drag.active=false } }
                                            Rectangle { width: Style.space(28); height: Style.space(28); radius: Style.space(4); color: Util.alpha(root.protoColor(modelData.protocol),0.14); border.color: Util.alpha(root.protoColor(modelData.protocol),0.35); border.width: 1; Label { anchors.centerIn: parent; textFormat: Text.PlainText; text: root.protoGlyph(modelData.protocol); font.family: "JetBrainsMono Nerd Font"; font.pixelSize: bodySize; color: root.protoColor(modelData.protocol) } }
                                            ColumnLayout { Layout.fillWidth: true; spacing: 0; Label { Layout.fillWidth: true; textFormat: Text.PlainText; text: modelData.name; font.family: fontFam; font.pixelSize: bodySize; color: cFg; elide: Text.ElideRight } Label { Layout.fillWidth: true; textFormat: Text.PlainText; text: (modelData.domain && modelData.username ? modelData.domain+"\\"+modelData.username+"@" : modelData.username ? modelData.username+"@" : "")+modelData.host+(modelData.port ? ":"+modelData.port:"")+" · "+modelData.protocol; font.family: fontFam; font.pixelSize: capSize; color: cMuted; elide: Text.ElideRight } }
                                            RowLayout { spacing: Style.space(2); Button { iconText: modelData.favorite===true ? "" : ""; fontFamily: "JetBrainsMono Nerd Font"; fontSize: capSize; tooltipText: modelData.favorite===true ? "Remove from favorites" : "Add to favorites"; Layout.preferredWidth: Style.space(26); Layout.preferredHeight: Style.space(26); onClicked: if(service) service.toggleFavorite(modelData.id) } Button { iconText: modelData.protocol==="SSH" ? "" : modelData.protocol==="RDP" ? "" : modelData.protocol==="VNC" ? "󰢹" : "󰹑"; fontFamily: "JetBrainsMono Nerd Font"; fontSize: bodySize; tooltipText: "Connect ("+modelData.protocol+")"; Layout.preferredWidth: Style.space(30); Layout.preferredHeight: Style.space(26); onClicked: if(service) service.launchServer(modelData.id) } Button { iconText: ""; fontFamily: "JetBrainsMono Nerd Font"; fontSize: capSize; tooltipText: "Edit"; Layout.preferredWidth: Style.space(26); Layout.preferredHeight: Style.space(26); onClicked: root.openEdit(modelData) } Button { iconText: ""; fontFamily: "JetBrainsMono Nerd Font"; fontSize: capSize; tooltipText: "Delete"; Layout.preferredWidth: Style.space(26); Layout.preferredHeight: Style.space(26); onClicked: { root.confirmTargetId=modelData.id; root.confirmTargetName=modelData.name; root.confirmVisible=true } } }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // empty state
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Style.space(6)
                        visible: service ? service.totalCount===0 : true
                        Label {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            textFormat: Text.PlainText
                            text: "No servers yet"
                            font.family: fontFam; font.pixelSize: bodySize; color: cMuted; opacity: 0.7
                        }
                        Label {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.Wrap
                            textFormat: Text.PlainText
                            text: "Add a server or import from CSV/TXT, ~/.ssh/config, or Remmina files. For CSV use header: name,host,protocol,port,username,group,notes"
                            font.family: fontFam; font.pixelSize: capSize; color: cMuted; opacity: 0.5
                        }
                        Button { Layout.alignment: Qt.AlignHCenter; text: "Import ~/.ssh/config"; fontSize: capSize; onClicked: if(service) service.importSsh() }
                    }

                    // footer hint
                    Label {
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                        textFormat: Text.PlainText
                        text: "SSH launches in your default Omarchy terminal (xdg-terminal-exec). RDP via freerdp/remmina, VNC/SPICE via remmina/virt-viewer. Remmina tray icon is auto-disabled."
                        font.family: fontFam; font.pixelSize: capSize-1; color: cMuted; opacity: 0.45
                    }
                }
            }

            // ── Confirm delete overlay ──
            Rectangle {
                anchors.fill: keyCatcher
                visible: confirmVisible
                color: Util.alpha(root.cBg, 0.75)
                MouseArea { anchors.fill: parent; onClicked: root.confirmVisible=false }
                Rectangle {
                    anchors.centerIn: parent
                    width: Math.min(parent.width - Style.space(24), Style.space(300))
                    implicitHeight: confirmCol.implicitHeight + Style.space(24)
                    radius: Style.space(8)
                    color: cBg
                    border.color: cUrgent
                    border.width: 1
                    ColumnLayout {
                        id: confirmCol
                        anchors.fill: parent
                        anchors.margins: Style.space(12)
                        spacing: Style.space(8)
                        Label { Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; textFormat: Text.PlainText; text: "Delete server?"; font.family: fontFam; font.pixelSize: bodySize; font.bold: true; color: cFg }
                        Label { Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap; textFormat: Text.PlainText; text: root.confirmTargetName; font.family: fontFam; font.pixelSize: capSize; color: cMuted }
                        RowLayout {
                            spacing: Style.space(8)
                            Button { text: "Cancel"; fontSize: capSize; Layout.fillWidth: true; onClicked: root.confirmVisible=false }
                            Button { text: "Delete"; fontSize: capSize; Layout.fillWidth: true; onClicked: { var id=root.confirmTargetId; root.confirmVisible=false; if(service) service.deleteServer(id) } }
                        }
                    }
                }
            }
            // ── Glyph picker overlay ──
            Rectangle {
                anchors.fill: keyCatcher
                visible: root.glyphPickerVisible
                color: Util.alpha(root.cBg, 0.85)
                MouseArea { anchors.fill: parent; onClicked: root.glyphPickerVisible=false }
                Rectangle {
                    anchors.centerIn: parent
                    width: Math.min(parent.width - Style.space(16), Style.space(360))
                    height: Math.min(parent.height - Style.space(20), Style.space(400))
                    radius: Style.space(8)
                    color: cBg
                    border.color: cAccent
                    border.width: 1
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Style.space(8)
                        spacing: Style.space(6)
                        Label {
                            Layout.fillWidth: true
                            textFormat: Text.PlainText
                            text: root.pickingGroup === "__new__" ? "Choose glyph for new group" : "Choose glyph for " + root.pickingGroup
                            font.family: fontFam
                            font.pixelSize: bodySize
                            font.bold: true
                            color: cFg
                            horizontalAlignment: Text.AlignHCenter
                        }
                        GlyphPicker {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            onPicked: function(glyph) {
                                if (root.pickingGroup === "__new__") {
                                    root.newGroupGlyph = glyph
                                } else if (service) {
                                    service.setGroupGlyph(root.pickingGroup, glyph)
                                }
                                root.glyphPickerVisible = false
                            }
                            onClosed: root.glyphPickerVisible = false
                        }
                    }
                }
            }
        }
    }
}
