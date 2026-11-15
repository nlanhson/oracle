import QtQuick

// Now Playing module: art, title, artist, previous / play-pause / next, and (when the player can seek) a draggable progress bar with times.
// Used in the Control Center and in the pop-up that follows a media key. `player` = a Quickshell Mpris player.
Card {
    id: np
    property var player: null
    readonly property bool seekable: !!player && player.canSeek && player.lengthSupported && player.length > 0
    readonly property bool playing: !!player && player.isPlaying
    property real pos: 0
    property bool dragging: false
    width: 316
    height: seekable ? 112 : 76

    function fmt(s) { s = Math.max(0, Math.round(s)); var m = Math.floor(s / 60), r = s % 60; return m + ":" + (r < 10 ? "0" : "") + r }
    function sync() { if (player && player.positionSupported) { player.positionChanged(); if (!dragging) pos = player.position } else if (!dragging) pos = 0 }
    onPlayerChanged: sync()
    Connections { target: np.player; ignoreUnknownSignals: true; function onTrackTitleChanged() { np.sync() } function onPlaybackStateChanged() { np.sync() } }
    Timer { interval: 500; repeat: true; running: np.visible && np.playing; triggeredOnStart: true; onTriggered: np.sync() }

    Rectangle {
        x: 12; y: 12; width: 52; height: 52; radius: 8; clip: true
        color: Tokens.alpha(Tokens.bright, 0.10)
        Glyph { anchors.centerIn: parent; text: "󰎆"; px: 22; color: Tokens.alpha(Tokens.bright, 0.6); visible: art.status !== Image.Ready }
        Image { id: art; anchors.fill: parent; source: np.player ? np.player.trackArtUrl : ""; fillMode: Image.PreserveAspectCrop; asynchronous: true; visible: status === Image.Ready }
    }
    Column {
        x: 76; y: 14; width: parent.width - 76 - 112 - 4; spacing: 2
        Text { width: parent.width; elide: Text.ElideRight; renderType: Text.NativeRendering
            text: np.player ? (np.player.trackTitle || "Not playing") : ""
            font.family: Tokens.font; font.pixelSize: 13; font.weight: Font.DemiBold; color: Tokens.bright }
        Text { width: parent.width; elide: Text.ElideRight; renderType: Text.NativeRendering
            text: np.player ? np.player.trackArtist : ""
            font.family: Tokens.font; font.pixelSize: 11; color: Tokens.alpha(Tokens.bright, 0.55) }
    }
    Row {
        x: parent.width - 8 - width; y: 15; spacing: 0
        Repeater {
            model: [ { g: "󰒮", a: 0 }, { g: np.playing ? "󰏤" : "󰐊", a: 1 }, { g: "󰒭", a: 2 } ]
            Item {
                required property var modelData
                width: 34; height: 34
                Glyph { anchors.centerIn: parent; text: parent.modelData.g; px: 20; color: Tokens.alpha(Tokens.bright, tap.pressed ? 0.5 : 0.9) }
                TapHandler { id: tap; onTapped: { var p = np.player; if (!p) return; if (parent.modelData.a === 0) p.previous(); else if (parent.modelData.a === 1) p.togglePlaying(); else p.next() } }
            }
        }
    }

    Item { // progress: 5 px track, knob shows while hovering or dragging
        visible: np.seekable
        x: 12; y: 76; width: parent.width - 24; height: 16
        readonly property real frac: np.seekable ? Math.max(0, Math.min(1, np.pos / np.player.length)) : 0
        Rectangle { y: 5.5; width: parent.width; height: 5; radius: 2.5; color: Tokens.alpha(Tokens.bright, 0.15) }
        Rectangle { y: 5.5; width: parent.frac * parent.width; height: 5; radius: 2.5; color: Tokens.alpha(Tokens.bright, 0.85) }
        Rectangle { visible: bar.containsMouse || np.dragging; x: parent.frac * parent.width - 5; y: 3; width: 10; height: 10; radius: 5; color: Tokens.bright }
        MouseArea {
            id: bar
            anchors.fill: parent; anchors.topMargin: -6; anchors.bottomMargin: -6; hoverEnabled: true
            function at(x) { return np.player.length * Math.max(0, Math.min(1, x / width)) }
            onPressed: (m) => { np.dragging = true; np.pos = at(m.x) }
            onPositionChanged: (m) => { if (np.dragging) np.pos = at(m.x) }
            onReleased: { np.player.position = np.pos; np.dragging = false }
            onCanceled: np.dragging = false
        }
    }
    Text { visible: np.seekable; x: 12; y: 92; text: np.fmt(np.pos); font.family: Tokens.font; font.pixelSize: 10; color: Tokens.alpha(Tokens.bright, 0.55); renderType: Text.NativeRendering }
    Text { visible: np.seekable; x: parent.width - 12 - width; y: 92; text: np.seekable ? "-" + np.fmt(np.player.length - np.pos) : ""; font.family: Tokens.font; font.pixelSize: 10; color: Tokens.alpha(Tokens.bright, 0.55); renderType: Text.NativeRendering }
}
