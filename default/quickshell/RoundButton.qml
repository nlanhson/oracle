import QtQuick

// 28 px circle: grey when off, accent with a dark glyph when on
Item {
    id: b
    property string glyph
    property bool on: false
    property real size: 28
    property real glyphPx: 15
    signal clicked()
    implicitWidth: size
    implicitHeight: size
    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: b.on ? Tokens.accent : Tokens.alpha(Tokens.bright, tap.pressed ? 0.20 : 0.12)
        Behavior on color { ColorAnimation { duration: 150 } }
    }
    Glyph {
        anchors.centerIn: parent
        text: b.glyph
        px: b.glyphPx
        color: b.on ? Tokens.bg : Tokens.alpha(Tokens.bright, 0.85)
        Behavior on color { ColorAnimation { duration: 150 } }
    }
    TapHandler { id: tap; onTapped: b.clicked() }
}
