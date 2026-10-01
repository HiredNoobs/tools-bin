import QtQuick
import QtQuick.Shapes
import qs

// Background for anything that drops out of the bar (panels, notification popups).
// Attached (Theme.panelsAttached): body with rounded bottom corners and concave fillets of
// width `fillet` joining it to the bar. Floating: a rounded rectangle with the accent border.
Item {
    id: root

    readonly property bool attached: Theme.panelsAttached
    readonly property real fillet: attached ? Theme.radius : 0

    // Floating style
    Rectangle {
        visible: !root.attached
        anchors.fill: parent
        radius: Theme.radius
        color: Theme.panelBackground
        // Matches Hyprland's active window border (general.lua)
        border.width: 2
        border.color: Theme.accent
    }

    // Attached style
    Shape {
        id: shape

        readonly property real f: root.fillet
        readonly property real w: width
        readonly property real h: height
        // Bottom corner radius, shrunk while still growing
        readonly property real r: Math.max(0, Math.min(Theme.radius, (h - f) / 2))

        visible: root.attached
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: Theme.panelBackground
            strokeColor: "transparent"
            strokeWidth: 0

            startX: 0
            startY: 0
            PathLine { x: shape.w; y: 0 }
            PathArc { x: shape.w - shape.f; y: shape.f; radiusX: shape.f; radiusY: shape.f; direction: PathArc.Counterclockwise }
            PathLine { x: shape.w - shape.f; y: shape.h - shape.r }
            PathArc { x: shape.w - shape.f - shape.r; y: shape.h; radiusX: shape.r; radiusY: shape.r }
            PathLine { x: shape.f + shape.r; y: shape.h }
            PathArc { x: shape.f; y: shape.h - shape.r; radiusX: shape.r; radiusY: shape.r }
            PathLine { x: shape.f; y: shape.f }
            PathArc { x: 0; y: 0; radiusX: shape.f; radiusY: shape.f; direction: PathArc.Counterclockwise }
        }
    }
}
