import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Ui

// Mini glyph picker — searchable grid of Nerd Font glyphs
// Shows glyphs with names, filters via textField, emits picked(glyph)
Item {
    id: root
    property string filter: ""
    signal picked(string glyph)
    signal closed()

    // Curated glyphs — common servers/groups + full nerd set via https://www.nerdfonts.com/cheat-sheet
    // Format: { glyph, name, keywords }
    property var glyphs: [
        // Generic
        { glyph: "󰉋", name: "folder", keywords: "folder directory" },
        { glyph: "󰉖", name: "folder-open", keywords: "folder open" },
        { glyph: "󰢹", name: "monitor", keywords: "monitor display" },
        { glyph: "󰒋", name: "server", keywords: "server" },
        { glyph: "󰈈", name: "database", keywords: "database db" },
        { glyph: "", name: "linux", keywords: "linux tux" },
        { glyph: "", name: "windows", keywords: "windows" },
        { glyph: "󰀄", name: "apple", keywords: "apple mac" },
        { glyph: "󰓎", name: "star", keywords: "star favorite" },
        { glyph: "󰧓", name: "history", keywords: "history recent clock" },
        { glyph: "󰜘", name: "chip", keywords: "chip cpu" },
        { glyph: "󰤉", name: "memory", keywords: "memory ram" },
        { glyph: "󰋊", name: "harddisk", keywords: "harddisk drive" },
        { glyph: "󰌗", name: "network", keywords: "network lan" },
        { glyph: "󰒍", name: "cloud", keywords: "cloud" },
        { glyph: "󰖟", name: "shield", keywords: "shield security" },
        { glyph: "󰕥", name: "key", keywords: "key" },
        { glyph: "󰒃", name: "lock", keywords: "lock" },
        { glyph: "󰌋", name: "vpn", keywords: "vpn" },
        { glyph: "󰦉", name: "docker", keywords: "docker" },
        { glyph: "󰡨", name: "kubernetes", keywords: "k8s kubernetes" },
        { glyph: "", name: "terminal", keywords: "terminal" },
        { glyph: "", name: "terminal2", keywords: "terminal" },
        { glyph: "󰹑", name: "vm", keywords: "vm virtual" },
        { glyph: "󰢮", name: "gpu", keywords: "gpu" },
        { glyph: "󰻠", name: "cpu", keywords: "cpu" },
        { glyph: "󰟐", name: "hypervisor", keywords: "hypervisor vm" },
        { glyph: "󰒋", name: "infra", keywords: "infra server" },
        { glyph: "󰖔", name: "web", keywords: "web http" },
        { glyph: "󰖟", name: "proxy", keywords: "proxy" },
        { glyph: "󰓅", name: "mail", keywords: "mail" },
        { glyph: "󰆧", name: "git", keywords: "git" },
        { glyph: "", name: "github", keywords: "github" },
        { glyph: "󰭹", name: "gitlab", keywords: "gitlab" },
        { glyph: "󰀲", name: "jenkins", keywords: "jenkins" },
        { glyph: "󰒋", name: "proxmox", keywords: "proxmox" },
        { glyph: "󰧓", name: "recent2", keywords: "recent" },
        { glyph: "󰥔", name: "clock", keywords: "clock" },
        { glyph: "󰃭", name: "calendar", keywords: "calendar" },
        { glyph: "󰷈", name: "alert", keywords: "alert" },
        { glyph: "󰋊", name: "disk2", keywords: "disk" },
        { glyph: "󰋙", name: "nas", keywords: "nas" },
        { glyph: "󰒋", name: "nas2", keywords: "nas" },
        // Nerd Fonts extended
        { glyph: "", name: "csv", keywords: "csv file" },
        { glyph: "", name: "remmina", keywords: "remmina rdp" },
        { glyph: "", name: "ssh", keywords: "ssh" },
        { glyph: "", name: "json", keywords: "json" },
        { glyph: "󰈙", name: "code", keywords: "code" },
        { glyph: "󰌠", name: "file", keywords: "file" },
        { glyph: "󰈔", name: "config", keywords: "config" },
        { glyph: "󰒓", name: "settings", keywords: "settings" },
        { glyph: "󰢩", name: "cube", keywords: "cube" },
        { glyph: "󰒋", name: "box", keywords: "box" },
        { glyph: "󰣖", name: "ansible", keywords: "ansible" },
        { glyph: "󰙨", name: "terraform", keywords: "terraform" },
        { glyph: "󰅨", name: "plus", keywords: "plus add" },
        { glyph: "󰅖", name: "minus", keywords: "minus" },
        { glyph: "󰇚", name: "check", keywords: "check" },
        { glyph: "󰅚", name: "close", keywords: "close" },
        { glyph: "󰍴", name: "arrow", keywords: "arrow" },
        { glyph: "󰞇", name: "wrench", keywords: "wrench" },
        { glyph: "󰦝", name: "tool", keywords: "tool" },
        { glyph: "󰒋", name: "lab", keywords: "lab test" },
        { glyph: "󰖪", name: "lab2", keywords: "lab" },
        { glyph: "󰢬", name: "flask", keywords: "flask" },
        { glyph: "󰉋", name: "folder2", keywords: "folder" },
        { glyph: "󰅴", name: "star2", keywords: "star" },
        { glyph: "󰄛", name: "heart", keywords: "heart" },
        { glyph: "󰲶", name: "fire", keywords: "fire" },
        { glyph: "󰚩", name: "bug", keywords: "bug" },
        { glyph: "󰬁", name: "light", keywords: "light" },
        { glyph: "󰛨", name: "vpn2", keywords: "vpn" },
        { glyph: "󰖂", name: "wifi", keywords: "wifi" },
        { glyph: "󰒋", name: "ethernet", keywords: "ethernet" },
        { glyph: "󰢹", name: "display2", keywords: "display" },
        { glyph: "󰹑", name: "spice", keywords: "spice" },
        // Add searchable via https://www.nerdfonts.com/cheat-sheet
        { glyph: "󰀵", name: "nf-fa-star", keywords: "star" },
        { glyph: "", name: "fa-star", keywords: "star" },
        { glyph: "", name: "fa-star-o", keywords: "star outline" },
        { glyph: "󰪥", name: "nf-md-star", keywords: "star" },
        { glyph: "󰓎", name: "nf-md-star-outline", keywords: "star" }
    ]

    property var filtered: {
        var f = (root.filter || "").toLowerCase().trim()
        if (!f) return glyphs
        var out=[]
        for (var i=0;i<glyphs.length;i++) {
            var g=glyphs[i]
            var hay=(g.glyph+" "+g.name+" "+g.keywords).toLowerCase()
            if (hay.indexOf(f) !== -1) out.push(g)
        }
        return out
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Style.space(6)

        TextField {
            id: filterField
            Layout.fillWidth: true
            placeholderText: "  Search glyph (e.g. linux, windows, star, folder) — nerd.lu/cheat-sheet"
            text: root.filter
            font.family: Style.font.family
            font.pixelSize: Style.font.body
            onTextChanged: root.filter = text
            Component.onCompleted: forceActiveFocus()
        }

        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredHeight: Style.space(200)
            clip: true
            contentHeight: flow.implicitHeight
            contentWidth: width
            Flow {
                id: flow
                width: parent.width
                spacing: Style.space(4)
                Repeater {
                    model: root.filtered
                    delegate: Rectangle {
                        id: del
                        required property var modelData
                        property int index
                        width: Style.space(48)
                        height: Style.space(48)
                        radius: Style.space(4)
                        color: "transparent"
                        border.color: "transparent"
                        border.width: 0

                        Column {
                            anchors.centerIn: parent
                            width: parent.width - Style.space(4)
                            spacing: 2
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                textFormat: Text.PlainText
                                text: del.modelData.glyph
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: Style.font.title
                                color: Color.foreground
                                horizontalAlignment: Text.AlignHCenter
                                width: parent.width
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                textFormat: Text.PlainText
                                text: del.modelData.name
                                font.family: Style.font.family
                                font.pixelSize: Style.font.caption - 2
                                color: Color.muted
                                horizontalAlignment: Text.AlignHCenter
                                width: parent.width
                                elide: Text.ElideRight
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.picked(del.modelData.glyph)
                            onDoubleClicked: root.picked(del.modelData.glyph)
                        }
                    }
                }
            }
            // Keyboard navigation
            Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Escape) root.closed()
            }
            focus: true
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(6)
            Text {
                Layout.fillWidth: true
                textFormat: Text.PlainText
                text: root.filtered.length + " glyphs"
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                color: Color.muted
            }
            Button {
                text: "Close"
                fontSize: Style.font.caption
                onClicked: root.closed()
            }
        }
    }
}
