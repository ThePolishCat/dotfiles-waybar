//@ pragma UseQApplication

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray
import Quickshell.Wayland
import Quickshell.Widgets

ShellRoot {
    id: root

    // Theme colors
    property color colBg: Theme.colBg
    property color colFg: Theme.colFg
    property color col0: Theme.col0
    property color col1: Theme.col1
    property color col2: Theme.col2
    property color col3: Theme.col3
    property color col4: Theme.col4
    property color col5: Theme.col5
    property color col6: Theme.col6
    property color col7: Theme.col7
    property color col8: Theme.col8
    property color col9: Theme.col9
    property color col10: Theme.col10
    property color col11: Theme.col11
    property color col12: Theme.col12
    property color col13: Theme.col13
    property color col14: Theme.col14
    property color col15: Theme.col15
    property color col16: Theme.col16
    property string fontFamily: "JetBrainsMono Nerd Font"
    property int fontSize: 12
    property int cpuUsage: 0
    property int memUsage: 0
    property var lastCpuIdle: 0
    property var lastCpuTotal: 0
    property int batteryPerc: 0
    property bool hasBattery: false
    property bool hasBatteryChecked: false
    property string audioTitle
    property string audioAuthor
    property real cpuTemp: 0

    FileView {
        id: cpuLoader

        path: "/proc/stat"
    }

    FileView {
        id: memLoader

        path: "/proc/meminfo"
    }

    Process {
        id: tempProc

        // Try thermal_zone files first, fall back to hwmon temp*_input
        command: ["sh", "-c", "cat /sys/class/thermal/thermal_zone*/temp 2>/dev/null | head -n1 || cat /sys/class/hwmon/hwmon*/temp*_input 2>/dev/null | head -n1 || echo 0"]
        running: false

        stdout: SplitParser {
            onRead: (data) => {
                var raw = parseInt(data.trim()) || 0;
                if (raw > 1000)
                    root.cpuTemp = raw / 1000;
                else
                    root.cpuTemp = raw;
            }
        }
    }

    FileView {
        id: batteryLoader

        path: "/sys/class/power_supply/BAT1/capacity"
    }

    Process {
        id: songProcTitle

        command: ["sh", "-c", "playerctl metadata title || echo ''"]
        Component.onCompleted: running = true

        stdout: SplitParser {
            onRead: (data) => {
                audioTitle = data.trim();
            }
        }

    }

    Process {
        id: songProcAuthor

        command: ["sh", "-c", "playerctl metadata artist || echo ''"]
        Component.onCompleted: running = true

        stdout: SplitParser {
            onRead: (data) => {
                audioAuthor = data.trim();
            }
        }

    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            cpuLoader.reload();
            var parts = cpuLoader.text().trim().split(/\s+/);
            var user = parseInt(parts[1]) || 0;
            var nice = parseInt(parts[2]) || 0;
            var system = parseInt(parts[3]) || 0;
            var idle = parseInt(parts[4]) || 0;
            var iowait = parseInt(parts[5]) || 0;
            var irq = parseInt(parts[6]) || 0;
            var softirq = parseInt(parts[7]) || 0;
            var total = user + nice + system + idle + iowait + irq + softirq;
            var idleTime = idle + iowait;
            if (root.lastCpuTotal > 0) {
                var totalDiff = total - root.lastCpuTotal;
                var idleDiff = idleTime - root.lastCpuIdle;
                if (totalDiff > 0)
                    root.cpuUsage = Math.round(100 * (totalDiff - idleDiff) / totalDiff);

            }
            root.lastCpuTotal = total;
            root.lastCpuIdle = idleTime;
            memLoader.reload();
            var memTotal = 0, memAvailable = 0;
            var lines = memLoader.text().split('\n');
            for (var i = 0; i < lines.length; i++) {
                var line = lines[i].trim();
                if (line.startsWith("MemTotal:"))
                    memTotal = parseInt(line.split(/\s+/)[1]) || 0;
                else if (line.startsWith("MemAvailable:"))
                    memAvailable = parseInt(line.split(/\s+/)[1]) || 0;
            }
            if (memTotal > 0 && memAvailable > 0)
                root.memUsage = Math.round(100 * (memTotal - memAvailable) / memTotal);

            // Trigger temperature read (Process will pick an appropriate sysfs file)
            tempProc.running = true;
            if (hasBattery || !hasBatteryChecked) {
                batteryLoader.reload();
                var batteryText = batteryLoader.text().trim();
            }
            if (!hasBatteryChecked) {
                root.hasBatteryChecked = true;
                var perc = parseInt(batteryText);
                if (!isNaN(perc)) {
                    root.batteryPerc = perc;
                    root.hasBattery = true;
                } else {
                    root.hasBattery = false;
                }
            } else {
                root.hasBattery = false;
            }
            songProcTitle.running = true;
            songProcAuthor.running = true;
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            property var modelData
            property var monitor: Hyprland.monitors.values.find((m) => {
                return m.name === modelData.name;
            }) || null
            property string focusedTitle: (monitor && Hyprland.activeToplevel && Hyprland.activeToplevel.workspace.id === monitor.activeWorkspace.id) ? (Hyprland.activeToplevel.title ?? "") : ""

            screen: modelData
            implicitHeight: 23
            color: "transparent"

            anchors {
                top: true
                left: true
                right: true
            }

            margins {
                top: 0
                bottom: 0
                left: 0
                right: 0
            }

            Rectangle {
                anchors.fill: parent
                radius: 5
                color: root.colBg

                RowLayout {
                    anchors.fill: parent
                    spacing: 0

                    //left elements
                    Item {
                        width: 8
                    }

                    Item {
                        id: workspaceContainer

                        Layout.fillHeight: true
                        Layout.preferredWidth: workspaceRow.implicitWidth
                        Layout.alignment: Qt.AlignVCenter

                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.NoButton
                            onWheel: (wheel) => {
                                if (wheel.angleDelta.y > 0)
                                    Hyprland.dispatch("workspace -1");
                                else if (wheel.angleDelta.y < 0)
                                    Hyprland.dispatch("workspace +1");
                                wheel.accepted = true;
                            }
                        }

                        RowLayout {
                            id: workspaceRow

                            height: parent.height

                            Repeater {
                                model: 9

                                Rectangle {
                                    property int wsId: index + 1
                                    property var workspace: Hyprland.workspaces.values.find((w) => {
                                        return w.id === wsId;
                                    })
                                    property bool hasWindows: workspace ? workspace.toplevels.values.length > 0 : false
                                    property bool isActive: Hyprland.focusedWorkspace.id === wsId

                                    Layout.fillHeight: true
                                    radius: 5
                                    color: isActive ? (Qt.rgba(1, 1, 1, 0.15)) : "transparent"
                                    Layout.preferredWidth: 16
                                    Layout.leftMargin: 4
                                    Layout.rightMargin: 4

                                    Text {
                                        text: wsId
                                        color: parent.hasWindows ? root.col15 : root.col3
                                        font.pixelSize: parent.isActive ? root.fontSize + 3 : root.fontSize + 1
                                        font.family: root.fontFamily
                                        font.bold: parent.isActive
                                        anchors.centerIn: parent

                                        Behavior on color {
                                            ColorAnimation {
                                                duration: 150
                                            }

                                        }

                                        Behavior on font.pixelSize {
                                            NumberAnimation {
                                                duration: 150
                                                easing.type: Easing.OutQuad
                                            }

                                        }

                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: Hyprland.dispatch("workspace " + wsId)
                                        onWheel: (wheel) => {
                                            return wheel.accepted = false;
                                        }
                                        cursorShape: Qt.PointingHandCursor
                                    }

                                }

                            }

                        }

                    }

                    Rectangle {
                        Layout.preferredWidth: 1
                        Layout.preferredHeight: 16
                        Layout.alignment: Qt.AlignVCenter
                        Layout.leftMargin: 8
                        Layout.rightMargin: 8
                        color: root.col1
                        visible: focusedTitle !== ""
                    }
                    // Window Title

                    Text {
                        text: focusedTitle
                        color: root.col7
                        font.pixelSize: root.fontSize
                        font.family: root.fontFamily
                        font.bold: true
                        Layout.alignment: Qt.AlignVCenter
                        Layout.leftMargin: 8
                        Layout.rightMargin: 8
                        Layout.maximumWidth: 400
                        elide: Text.ElideRight
                        visible: focusedTitle !== ""
                    }

                    Item {
                        Layout.fillWidth: true
                    }
                    //right elements

                    Text {
                        text: "▶ " + audioAuthor + " - " + audioTitle
                        color: root.col7
                        font.pixelSize: root.fontSize
                        font.family: root.fontFamily
                        font.bold: true
                        Layout.rightMargin: 8
                        Layout.alignment: Qt.AlignVCenter
                        Layout.maximumWidth: 300
                        elide: Text.ElideRight
                        visible: audioTitle !== ""
                    }

                    Rectangle {
                        Layout.preferredWidth: 1
                        Layout.preferredHeight: 16
                        Layout.alignment: Qt.AlignVCenter
                        Layout.leftMargin: 0
                        Layout.rightMargin: 8
                        color: root.col1
                        visible: audioTitle !== ""
                    }

                    Item {
                        // // Update when the default sink changes (e.g., new headphones)
                        // Connections {
                        //     target: Pipewire
                        //     function onSinksChanged() {
                        //         volumeRoot.defaultSink = Pipewire.sinks.values.find(sink => sink.name === "@DEFAULT_SINK@") || null
                        //     }
                        // }

                        id: volumeRoot

                        readonly property PwNode defaultSink: Pipewire.defaultAudioSink
                        readonly property PwNode source: Pipewire.defaultAudioSource

                        Layout.preferredWidth: volumeRow.implicitWidth
                        Layout.preferredHeight: parent.height
                        Layout.alignment: Qt.AlignVCenter
                        Layout.rightMargin: 8

                        PwObjectTracker {
                            objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource]
                        }

                        Row {
                            id: volumeRow

                            anchors.centerIn: parent

                            Text {
                                text: (volumeRoot.defaultSink.audio.muted ? "   " : "   ") + Math.floor((volumeRoot.defaultSink.audio.volume || 0) * 100) + "%"
                                color: root.col14
                                font.pixelSize: root.fontSize
                                font.family: root.fontFamily
                                font.bold: true
                            }

                        }

                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton
                            onClicked: {
                                volumeRoot.defaultSink.audio.muted = !volumeRoot.defaultSink.audio.muted;
                            }
                            onWheel: (wheel) => {
                                if (!volumeRoot.defaultSink)
                                    return ;
 // 1%
                                let step = 0.01;
                                let vol = volumeRoot.defaultSink.audio.volume;
                                let newVol;
                                if (wheel.angleDelta.y > 0)
                                    newVol = Math.min(1, vol + step);
                                else
                                    newVol = Math.max(0, vol - step);
                                volumeRoot.defaultSink.audio.volume = newVol;
                                wheel.accepted = true;
                            }
                        }

                    }

                    Rectangle {
                        Layout.preferredWidth: 1
                        Layout.preferredHeight: 16
                        Layout.alignment: Qt.AlignVCenter
                        Layout.leftMargin: 0
                        Layout.rightMargin: 8
                        color: root.col1
                    }
                    // Battery

                    Text {
                        text: "󰂎 " + root.batteryPerc + "%"
                        color: root.col14
                        font.pixelSize: root.fontSize
                        font.family: root.fontFamily
                        font.bold: true
                        Layout.alignment: Qt.AlignVCenter
                        visible: root.hasBattery
                    }

                    Rectangle {
                        Layout.preferredWidth: 1
                        Layout.preferredHeight: 10
                        Layout.alignment: Qt.AlignVCenter
                        Layout.leftMargin: 8
                        Layout.rightMargin: 8
                        color: root.col1
                        visible: root.hasBattery
                    }

                    Item {
                        id: resourcesContainer

                        Layout.fillHeight: true
                        Layout.preferredWidth: resourcesRow.implicitWidth
                        Layout.alignment: Qt.AlignVCenter

                        MouseArea {
                            anchors.fill: parent
                            onClicked: btop.running = true
                        }

                        Process {
                            id: btop

                            command: ["kitty", "-e", "btop"]
                            running: false
                        }

                        RowLayout {
                            id: resourcesRow

                            height: parent.height

                            // CPU usage
                            Text {
                                text: "  " + cpuUsage + "%"
                                color: root.col14
                                font.pixelSize: root.fontSize
                                font.family: root.fontFamily
                                font.bold: true
                            }

                            Rectangle {
                                Layout.preferredWidth: 1
                                Layout.preferredHeight: 10
                                Layout.leftMargin: 8
                                Layout.rightMargin: 8
                                color: root.col1
                            }
                            // Memory usage

                            Text {
                                text: "   " + memUsage + "%"
                                color: root.col14
                                font.pixelSize: root.fontSize
                                font.family: root.fontFamily
                                font.bold: true
                            }

                            Rectangle {
                                Layout.preferredWidth: 1
                                Layout.preferredHeight: 10
                                Layout.leftMargin: 8
                                Layout.rightMargin: 8
                                color: root.col1
                            }
                            // CPU temperature

                            Text {
                                text: " " + cpuTemp.toFixed(1) + "°C"
                                color: root.col14
                                font.pixelSize: root.fontSize
                                font.family: root.fontFamily
                                font.bold: true
                            }

                        }

                    }

                    Rectangle {
                        Layout.preferredWidth: 1
                        Layout.preferredHeight: 16
                        Layout.alignment: Qt.AlignVCenter
                        Layout.leftMargin: 8
                        Layout.rightMargin: 8
                        color: root.col1
                    }
                    // Tray

                    Row {
                        spacing: 6
                        visible: SystemTray.items.list.lenght > 0

                        Repeater {
                            id: sysTray

                            model: SystemTray.items

                            WrapperMouseArea {
                                id: mouseArea

                                required property SystemTrayItem modelData

                                acceptedButtons: Qt.AllButtons
                                onClicked: (event) => {
                                    switch (event.button) {
                                    case Qt.LeftButton:
                                        modelData.activate();
                                        break;
                                    case Qt.RightButton:
                                        if (modelData.hasMenu)
                                            menu.open();

                                        break;
                                    }
                                    event.accepted = true;
                                }

                                IconImage {
                                    implicitHeight: 14
                                    implicitWidth: 14
                                    anchors.fill: parent
                                    source: modelData.icon
                                }

                                QsMenuAnchor {
                                    id: menu

                                    menu: mouseArea.modelData.menu

                                    anchor {
                                        item: mouseArea
                                        edges: Edges.Top
                                        gravity: Edges.Top
                                        adjustment: PopupAdjustment.All
                                    }

                                }

                            }

                        }

                    }

                    Rectangle {
                        Layout.preferredWidth: 1
                        Layout.preferredHeight: 16
                        Layout.alignment: Qt.AlignVCenter
                        Layout.leftMargin: 8
                        Layout.rightMargin: 8
                        color: root.col1
                        visible: SystemTray.items.list.lenght > 0
                    }
                    // Clock

                    Text {
                        id: clockText

                        text: Qt.formatDateTime(clock.date, "dddd - dd/MM/yyyy - hh:mm")
                        color: root.col16
                        font.pixelSize: root.fontSize
                        font.family: root.fontFamily
                        font.bold: true
                        Layout.rightMargin: 8
                        Layout.alignment: Qt.AlignVCenter

                        SystemClock {
                            id: clock

                            precision: SystemClock.Seconds
                        }

                    }

                }
                // center

            }

        }

    }

}
