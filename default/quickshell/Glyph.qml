import QtQuick

Text {
    property real px: 15
    font.family: Tokens.icons
    font.pixelSize: px
    color: Tokens.bright
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    renderType: Text.NativeRendering
}
