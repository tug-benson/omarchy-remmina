pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

BarWidget {
    id: root
    moduleName: "io.github.tug-benson.remmina"

    readonly property var service: bar && bar.shell && typeof bar.shell.serviceFor === "function"
        ? (bar.shell.serviceFor("io.github.tug-benson.remmina") || bar.shell.serviceFor("remmina")) : null
    readonly property int totalCount: service ? service.totalCount : 0
    readonly property bool hasService: service !== null

    function injectPanel() {
        var t = panelLoader.item
        if (!t) return
        if ("bar" in t) t.bar = root.bar
        if ("settings" in t) t.settings = root.settings
        if ("anchorItem" in t) t.anchorItem = button
        if ("hostWidget" in t) t.hostWidget = root
    }
    function togglePanel() { if (panelLoader.item && panelLoader.item.toggle) panelLoader.item.toggle() }
    readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
    function open() { if (panelLoader.item && panelLoader.item.open) panelLoader.item.open() }
    function close() { if (panelLoader.item && panelLoader.item.close) panelLoader.item.close() }
    readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false
    function closeForPopoutSwitch(){ if(panelLoader.item && panelLoader.item.closeForPopoutSwitch) panelLoader.item.closeForPopoutSwitch() }

    implicitWidth: button.implicitWidth
    implicitHeight: barSize
    onBarChanged: injectPanel()
    onSettingsChanged: injectPanel()

    // ── Bar button ──
    BarIconButton {
        id: button
        anchors.fill: parent
        bar: root.bar
        // Nerd Font: 󰢹 (monitor) / 󰒋 (remote) — using desktop glyph
        text: "󰢹"
        // show count badge via tooltip; optional indicator dot when servers exist
        tooltipText: root.hasService ? ("Remmina Hub — "+root.totalCount+" servers — Click to manage") : "Remmina Hub"
        active: root.opened
        onPressed: function(b){ root.togglePanel() }
        // small counter badge
        Rectangle {
            visible: root.totalCount > 0
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: 2
            anchors.rightMargin: 2
            width: Math.max(14, countText.implicitWidth + 6)
            height: 12
            radius: 6
            color: Color.accent
            Text {
                id: countText
                anchors.centerIn: parent
                text: root.totalCount > 99 ? "99+" : String(root.totalCount)
                font.family: Style.font.family
                font.pixelSize: 8
                font.bold: true
                color: Color.background
            }
        }
    }

    Loader {
        id: panelLoader
        active: true
        source: Qt.resolvedUrl("Panel.qml")
        visible: false
        onLoaded: { root.injectPanel(); Qt.callLater(root.injectPanel) }
    }
}
