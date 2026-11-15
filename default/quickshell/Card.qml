import QtQuick

// One module of the panel: soft white tile, inner hairline, optional press feedback
Rectangle {
    id: card
    property bool pressable: false
    property bool pressed: false
    signal clicked()
    radius: 14
    color: Tokens.alpha(Tokens.bright, 0.07 + (pressed ? 0.04 : hover.hovered && pressable ? 0.04 : 0))
    Behavior on color { ColorAnimation { duration: 120 } }
    Rectangle { anchors.fill: parent; radius: parent.radius; color: "transparent"; border.width: 1; border.color: Tokens.alpha(Tokens.bright, 0.06) }
    HoverHandler { id: hover; enabled: card.pressable }
    TapHandler { enabled: card.pressable; onTapped: card.clicked(); onPressedChanged: card.pressed = pressed }
}
