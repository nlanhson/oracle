//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Mpris

// Oracle Control Center. `oracle panel` = open/close (qs ipc call panel toggle). Tokens: Tokens.qml. State: `oracle panel state`, polled only while open.
ShellRoot {
    id: root
    readonly property var player: { // the one that plays, else the first
        var v = Mpris.players.values, i
        for (i = 0; i < v.length; i++) if (v[i].isPlaying) return v[i]
        return v.length ? v[0] : null
    }

    PanelWindow {
        id: win
        property bool open: false
        property real prog: 0
        readonly property int pad: 24 // room for the shadow around the 340 px card
        readonly property bool hypr: !!Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE")

        visible: open || prog > 0
        color: "transparent"
        anchors { top: true; right: true }
        margins { top: 6 - 0; right: 8 - pad }
        implicitWidth: 340 + 2 * pad
        implicitHeight: panel.height + pad * 2
        exclusionMode: ExclusionMode.Normal
        WlrLayershell.namespace: "oracle-panel"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

        onOpenChanged: {
            if (open) { sys.refresh(); pollTimer.start() } else pollTimer.stop()
        }
        NumberAnimation on prog { id: anim }
        function setOpen(v) {
            if (v === open) return
            open = v
            anim.stop(); anim.from = prog; anim.to = v ? 1 : 0
            anim.duration = v ? 180 : 120
            anim.easing.type = Easing.OutCubic
            anim.start()
        }

        Loader {
            active: win.hypr
            sourceComponent: HyprlandFocusGrab { windows: [win]; active: win.open; onCleared: win.setOpen(false) }
        }

        IpcHandler {
            target: "panel"
            function toggle(): void { win.setOpen(!win.open) }
            function open(): void { win.setOpen(true) }
            function close(): void { win.setOpen(false) }
        }

        FocusScope {
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: win.setOpen(false)

            Item {
                id: frame
                x: win.pad; y: 0; width: 340; height: panel.height + win.pad * 2
                opacity: win.prog
                scale: 0.96 + 0.04 * win.prog
                transformOrigin: Item.TopRight

                Repeater { // soft shadow without shaders: stacked, fading rounded rects
                    model: 6
                    Rectangle {
                        required property int index
                        x: -index * 2.5; y: 8 - index * 2.5 + 2; width: panel.width + index * 5; height: panel.height + index * 5
                        radius: 20 + index * 2.5; color: Tokens.alpha("#000000", 0.022)
                    }
                }
                Rectangle {
                    id: panel
                    width: 340; height: col.implicitHeight + 24
                    radius: 20
                    color: Tokens.alpha(Tokens.bg, 0.62)
                    Rectangle { anchors.fill: parent; radius: parent.radius; color: "transparent"; border.width: 1; border.color: Tokens.alpha(Tokens.bright, 0.10) }

                    Column {
                        id: col
                        x: 12; y: 12; width: 316; spacing: 12

                        Row { // Wi-Fi / Bluetooth / Night Light | Do Not Disturb, Settings
                            spacing: 12
                            Card {
                                width: 152; height: 152
                                Column {
                                    x: 12; y: 7; width: parent.width - 24
                                    ToggleRow { title: "Wi-Fi"; subtitle: sys.wifi ? (sys.ssid || "Not connected") : "Off"; glyph: "󰖩"; on: sys.wifi
                                        onToggled: sys.set("wifi", !sys.wifi); onOpened: sys.detail("settings network") }
                                    ToggleRow { title: "Bluetooth"; subtitle: sys.bt ? (sys.btdev || "On") : "Off"; glyph: "󰂯"; on: sys.bt
                                        onToggled: sys.set("bt", !sys.bt); onOpened: sys.detail("settings devices") }
                                    ToggleRow { title: "Night Light"; subtitle: sys.night === "evening" ? "Evening" : sys.night === "off" ? "Off" : "Always"; glyph: "󰖔"; on: sys.night !== "off"
                                        onToggled: sys.set("night", sys.night === "off"); onOpened: sys.cycleNight() }
                                }
                            }
                            Column {
                                spacing: 12
                                Card {
                                    width: 152; height: 70; pressable: true
                                    onClicked: sys.set("dnd", !sys.dnd)
                                    RoundButton { x: 12; anchors.verticalCenter: parent.verticalCenter; glyph: "󰂛"; on: sys.dnd; enabled: false }
                                    Column {
                                        x: 50; width: parent.width - 58; anchors.verticalCenter: parent.verticalCenter; spacing: 1
                                        Label { text: "Do Not Disturb"; width: parent.width; title: true }
                                        Label { text: sys.dnd ? "On" : "Off"; width: parent.width }
                                    }
                                }
                                Tile { width: 152; label: "Settings"; glyph: "󰒓"; onClicked: sys.detail("settings") }
                            }
                        }

                        Card {
                            width: 316; height: 70
                            Label { x: 12; y: 9; text: "Display"; title: true }
                            Slider {
                                x: 12; y: 34; width: parent.width - 24; glyph: "󰃟"
                                value: sys.bright; minValue: 5
                                onMoved: (v) => sys.live("bright", v)
                            }
                        }

                        Card {
                            width: 316; height: 70
                            Label { x: 12; y: 10; text: "Sound"; title: true }
                            Slider {
                                x: 12; y: 34; width: parent.width - 24 - 36; glyph: sys.mute ? "󰝟" : "󰕾"
                                dimGlyph: sys.mute; glyphTap: true
                                value: sys.vol
                                onMoved: (v) => sys.live("vol", v)
                                onGlyphClicked: sys.set("mute", !sys.mute)
                            }
                            RoundButton { x: parent.width - 12 - 28; y: 32.5; glyph: "󰓃"; onClicked: sys.detail("output") }
                        }

                        Card {
                            visible: sys.bat >= 0
                            width: 316; height: visible ? 70 : 0
                            Label { x: 12; y: 10; text: "Battery"; title: true }
                            Label { y: 11; x: parent.width - 12 - width; width: 220; horizontalAlignment: Text.AlignRight // live while dragging the slider
                                text: sys.bat + "% · " + (sys.batstate === "Charging" ? "Charging" : sys.batstate === "Full" ? "Full" : sys.batstate === "Not charging" ? "Plugged in" : "On battery") + " · Limit " + Math.round(sys.limit) + "%" }
                            Slider {
                                x: 12; y: 34; width: parent.width - 24; glyph: "󰂄"
                                from: 20; to: 100; value: sys.limit
                                onMoved: (v) => sys.limit = v
                                onReleased: sys.charge()
                            }
                            Label { visible: false }
                        }

                        NowPlaying { visible: root.player !== null; player: root.player; height: visible ? (seekable ? 112 : 76) : 0 }
                    }
                }
            }
        }
    }

    // Now Playing pop-up: under the bar's right side. `oracle panel media pop` (a media key) shows it for 3 s; `oracle panel media` (bar item) keeps it until you click away
    PanelWindow {
        id: pop
        property bool shown: false
        property bool sticky: false
        property real prog: 0
        readonly property int pad: 24
        readonly property bool hypr: !!Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE")
        visible: shown || prog > 0
        color: "transparent"
        anchors { top: true; right: true }
        margins { top: 6; right: 8 - pad }
        implicitWidth: 340 + 2 * pad
        implicitHeight: card.height + 24 + pad * 2
        exclusionMode: ExclusionMode.Normal
        WlrLayershell.namespace: "oracle-media"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: shown && sticky ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
        NumberAnimation on prog { id: popAnim }
        function setShown(v) {
            if (v === shown) return
            shown = v
            popAnim.stop(); popAnim.from = prog; popAnim.to = v ? 1 : 0; popAnim.duration = v ? 180 : 120; popAnim.easing.type = Easing.OutCubic; popAnim.start()
        }
        Timer { id: popHide; interval: 3000; onTriggered: if (!pop.sticky && !popHover.hovered) pop.setShown(false); else if (!pop.sticky) popHide.restart() }
        Loader { active: pop.hypr; sourceComponent: HyprlandFocusGrab { windows: [pop]; active: pop.shown && pop.sticky; onCleared: pop.setShown(false) } }
        IpcHandler {
            target: "media"
            function key(): void { if (!root.player || win.open) return; pop.sticky = false; pop.setShown(true); popHide.restart() }
            function toggle(): void { if (!root.player) return; if (pop.shown && pop.sticky) pop.setShown(false); else { pop.sticky = true; pop.setShown(true); popHide.stop() } }
        }
        FocusScope {
            anchors.fill: parent; focus: true
            Keys.onEscapePressed: pop.setShown(false)
            Item {
                x: pop.pad; y: 0; width: 340; height: card.height + 24 + pop.pad * 2
                opacity: pop.prog; scale: 0.96 + 0.04 * pop.prog; transformOrigin: Item.TopRight
                HoverHandler { id: popHover }
                Repeater {
                    model: 6
                    Rectangle {
                        required property int index
                        x: -index * 2.5; y: 8 - index * 2.5 + 2; width: popframe.width + index * 5; height: popframe.height + index * 5
                        radius: 20 + index * 2.5; color: Tokens.alpha("#000000", 0.022)
                    }
                }
                Rectangle {
                    id: popframe
                    width: 340; height: card.height + 24; radius: 20
                    color: Tokens.alpha(Tokens.bg, 0.62)
                    Rectangle { anchors.fill: parent; radius: parent.radius; color: "transparent"; border.width: 1; border.color: Tokens.alpha(Tokens.bright, 0.10) }
                    NowPlaying { id: card; x: 12; y: 12; player: root.player }
                }
            }
        }
    }

    // ---- state ----
    QtObject {
        id: sys
        property bool wifi: false
        property string ssid: ""
        property bool bt: false
        property string btdev: ""
        property bool dnd: false
        property string night: "off"
        property real bright: 50
        property real vol: 50
        property bool mute: false
        property real bat: -1
        property string batstate: ""
        property real limit: 100
        property bool busy: false // dragging or just changed: ignore polls
        property var pending: ({})

        function parse(txt) {
            if (busy) return
            var l = txt.split("\n"), i, k, v, p
            for (i = 0; i < l.length; i++) {
                p = l[i].indexOf("="); if (p < 0) continue
                k = l[i].slice(0, p); v = l[i].slice(p + 1)
                if (k === "wifi") wifi = v === "on"
                else if (k === "ssid") ssid = v
                else if (k === "bt") bt = v === "on"
                else if (k === "btdev") btdev = v
                else if (k === "dnd") dnd = v === "true"
                else if (k === "night") night = v === "" ? "off" : v
                else if (k === "bright") bright = Number(v)
                else if (k === "vol") vol = Number(v)
                else if (k === "mute") mute = v === "true"
                else if (k === "bat") bat = Number(v)
                else if (k === "batstate") batstate = v
                else if (k === "limit") limit = Number(v)
            }
        }
        function refresh() { if (!poll.running) poll.running = true }
        function run(args) { Quickshell.execDetached(["oracle", "panel"].concat(args)) }
        function set(what, val) { // optimistic: flip now, ask the system, read the truth back shortly
            sys[what] = val
            run([what, val ? "true" : "false"])
            hold.restart()
        }
        function live(what, v) { sys.pending[what] = v; sys.busy = true; throttle.start(); hold.restart() }
        function flush() { var w; for (w in sys.pending) run([w, String(sys.pending[w])]); sys.pending = ({}) }
        function charge() { run(["charge", String(Math.round(limit))]); hold.restart() }
        function cycleNight() { night = night === "off" ? "evening" : night === "evening" ? "always" : "off"; run(["night", "cycle"]); hold.restart() }
        function detail(a) { // open the floating Settings pop-up (or the sound picker), close the panel
            win.setOpen(false)
            if (a === "output") run(["output"]); else run(a.split(" "))
        }
    }
    Process { id: poll; command: ["oracle", "panel", "state"]; stdout: StdioCollector { onStreamFinished: sys.parse(text) } }
    Timer { id: pollTimer; interval: 2000; repeat: true; onTriggered: sys.refresh() }
    Timer { id: throttle; interval: 60; repeat: true; onTriggered: { if (Object.keys(sys.pending).length) sys.flush(); else stop() } }
    Timer { id: hold; interval: 700; onTriggered: { sys.flush(); sys.busy = false; sys.refresh() } }

    component Label: Text {
        property bool title: false
        font.family: Tokens.font
        font.pixelSize: title ? 13 : 11
        font.weight: title ? Font.DemiBold : Font.Normal
        color: title ? Tokens.bright : Tokens.alpha(Tokens.bright, 0.55)
        elide: Text.ElideRight
        renderType: Text.NativeRendering
    }
    component Control: Item {
        property string glyph
        signal clicked()
        width: 34; height: 34
        Glyph { anchors.centerIn: parent; text: parent.glyph; px: 20; color: Tokens.alpha(Tokens.bright, tap.pressed ? 0.5 : 0.9) }
        TapHandler { id: tap; onTapped: parent.clicked() }
    }
    component ToggleRow: Item {
        id: r
        property string title
        property string subtitle
        property string glyph
        property bool on
        signal toggled()
        signal opened()
        width: parent.width; height: 46
        RoundButton { anchors.verticalCenter: parent.verticalCenter; glyph: r.glyph; on: r.on; onClicked: r.toggled() }
        Item {
            x: 38; width: parent.width - 38; height: parent.height
            Column {
                width: parent.width; anchors.verticalCenter: parent.verticalCenter; spacing: 1
                Label { text: r.title; width: parent.width; title: true }
                Label { text: r.subtitle; width: parent.width }
            }
            TapHandler { onTapped: r.opened() }
        }
    }
    component Tile: Card {
        id: t
        property string label
        property string glyph
        property bool on: false
        width: 70; height: 70; pressable: true
        Glyph { x: 0; y: 5; width: parent.width; height: 22; px: 20; text: t.glyph; color: Tokens.alpha(Tokens.bright, t.on ? 0.95 : 0.45) }
        Label { x: 4; y: 34; width: parent.width - 8; text: t.label; horizontalAlignment: Text.AlignHCenter; maximumLineCount: 2; wrapMode: Text.WordWrap; lineHeight: 16; lineHeightMode: Text.FixedHeight
            font.pixelSize: 12; font.weight: Font.Medium; color: Tokens.alpha(Tokens.bright, 0.85); elide: Text.ElideNone }
    }
}
