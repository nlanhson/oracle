pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Oracle look tokens (~/.config/oracle/look/tokens.json, written by `oracle look`). Reloads when the file changes.
Singleton {
    id: root
    property var t: ({})
    function col(k, d) { return t[k] !== undefined ? t[k] : d }
    function num(k, d) { return t[k] !== undefined ? Number(t[k]) : d }
    function alpha(c, a) { var x = Qt.color(c); return Qt.rgba(x.r, x.g, x.b, a) }

    readonly property color bg: col("bg", "#000000")
    readonly property color bright: col("bright", "#ffffff")
    readonly property color accent: col("accent", bright)
    readonly property color error: col("error", "#8b2e2e")
    readonly property string font: col("font_ui", "Inter")
    readonly property real frost: num("frost_alpha", 0.75)
    readonly property string icons: "JetBrainsMono Nerd Font Propo"

    FileView {
        path: Quickshell.env("HOME") + "/.config/oracle/look/tokens.json"
        blockLoading: true
        watchChanges: true
        onFileChanged: reload()
        onLoaded: { try { root.t = JSON.parse(text()) } catch (e) { root.t = ({}) } }
    }
}
