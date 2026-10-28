import QtQuick

// A Loader whose content fades in each time it changes (a panel, a tab). `closeRequested`
// passes on the loaded item's own, if it has one, so the item's owner needn't wire each one.
Loader {
    id: root

    signal closeRequested

    onLoaded: fadeIn.restart()

    Connections {
        target: root.item
        ignoreUnknownSignals: true

        function onCloseRequested(): void {
            root.closeRequested();
        }
    }

    NumberAnimation {
        id: fadeIn
        target: root
        property: "opacity"
        from: 0
        to: 1
        duration: 200
    }
}
