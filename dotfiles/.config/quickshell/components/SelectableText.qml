import QtQuick
import qs

// Read-only text that can be selected and copied (drag, then Ctrl+C), with web addresses
// turned into clickable links. Give it plain text in `plainText`.
TextEdit {
    id: root

    property string plainText: ""
    property bool dim: false

    // Escapes the text for rich text, turns URLs into links and keeps line breaks
    function linkify(source: string): string {
        const escaped = source.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
        const linked = escaped.replace(/\b(https?:\/\/[^\s<]+[^\s<.,;:!?)\]'"])/g, `<a href="$1" style="color: ${Theme.accent}">$1</a>`);
        return linked.replace(/\n/g, "<br>");
    }

    readOnly: true
    selectByMouse: true
    wrapMode: TextEdit.Wrap
    textFormat: TextEdit.RichText
    text: linkify(plainText)
    color: dim ? Theme.subtext : Theme.text
    selectionColor: Theme.accent
    selectedTextColor: Theme.background
    font.family: Theme.fontFamily
    font.pixelSize: Theme.panelFontSize

    onLinkActivated: link => Qt.openUrlExternally(link)

    HoverHandler {
        cursorShape: root.hoveredLink !== "" ? Qt.PointingHandCursor : Qt.IBeamCursor
    }
}
