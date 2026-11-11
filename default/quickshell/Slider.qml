import QtQuick

// Sequoia-style slider: 22 px track, white fill ending in a 22 px knob, dark glyph inside the left end
Item {
    id: s
    property real from: 0
    property real to: 100
    property real value: 0
    property real minValue: from
    property string glyph
    property bool dimGlyph: false
    property bool glyphTap: false
    property bool dragging: area.pressed && !area.onGlyph
    signal moved(real v)
    signal released()
    signal glyphClicked()
    readonly property real d: 25
    readonly property real frac: Math.max(0, Math.min(1, (value - from) / (to - from)))
    implicitHeight: d

    function set(v) {
        v = Math.round(Math.max(minValue, Math.min(to, v)))
        if (v !== value) { value = v; moved(v) }
    }

    Rectangle { anchors.fill: parent; radius: s.d / 2; color: Tokens.alpha(Tokens.bright, 0.12) }
    Rectangle {
        id: fill
        height: s.d; radius: s.d / 2
        width: s.d + s.frac * (s.width - s.d)
        color: Tokens.bright
    }
    Rectangle { // knob shadow, faint
        x: fill.width - s.d - 0.5; y: 0.5; width: s.d + 1; height: s.d + 1; radius: width / 2
        color: Tokens.alpha("#000000", 0.10); z: 1
    }
    Rectangle { x: fill.width - s.d; width: s.d; height: s.d; radius: s.d / 2; color: Tokens.bright; z: 2 }
    Glyph {
        x: (s.d - 18) / 2; width: 18; height: s.d; z: 3
        text: s.glyph; px: 14
        color: Tokens.alpha(Tokens.bg, s.dimGlyph ? 0.45 : 0.85)
    }

    MouseArea {
        id: area
        anchors.fill: parent
        property bool onGlyph: false
        property bool travelled: false
        property real px0: 0
        function pos(x) { return s.from + (s.to - s.from) * Math.max(0, Math.min(1, (x - s.d / 2) / (s.width - s.d))) }
        onPressed: (m) => { px0 = m.x; travelled = false; onGlyph = s.glyphTap && m.x < 28; if (!onGlyph) s.set(pos(m.x)) }
        onPositionChanged: (m) => {
            if (Math.abs(m.x - px0) > 4) travelled = true
            if (onGlyph && travelled) onGlyph = false
            if (!onGlyph) s.set(pos(m.x))
        }
        onReleased: { if (onGlyph && !travelled) s.glyphClicked(); else s.released() }
        onWheel: (w) => { s.set(s.value + (w.angleDelta.y > 0 ? 5 : -5)); s.released() }
    }
}
