import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.services

// The wallpaper on one screen, on the background layer under everything. A new wallpaper loads
// behind the old one and fades in over it; the old one is then dropped.
PanelWindow {
    id: root

    required property ShellScreen modelData

    screen: modelData
    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true
    exclusionMode: ExclusionMode.Ignore
    color: Theme.background
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "quickshell-wallpaper"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // The image showing, and the one loading over it
    property Image front: first
    property Image back: second

    Connections {
        target: Wallpaper

        function onSourceChanged(): void {
            root.back.opacity = 0;
            root.back.z = 1;
            root.front.z = 0;
            root.back.source = Wallpaper.source;
        }
    }

    component Picture: Image {
        id: picture

        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        // Decoded at the screen's size, not the file's
        sourceSize.width: root.width * root.modelData.devicePixelRatio
        sourceSize.height: root.height * root.modelData.devicePixelRatio
        asynchronous: true
        cache: false
        smooth: true

        onStatusChanged: {
            if (status !== Image.Ready || picture !== root.back)
                return;
            fade.target = picture;
            fade.restart();
        }
    }

    Picture {
        id: first
        source: Wallpaper.source
    }

    Picture {
        id: second
        opacity: 0
    }

    NumberAnimation {
        id: fade
        property: "opacity"
        from: 0
        to: 1
        duration: 600
        easing.type: Easing.InOutQuad
        onFinished: {
            const old = root.front;
            root.front = root.back;
            root.back = old;
            old.source = "";
        }
    }
}
