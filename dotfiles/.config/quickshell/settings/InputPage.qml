import QtQuick
import Quickshell.Io
import qs
import qs.components
import qs.services

// Settings › Keyboard and mouse: keyboard layouts (and the key to switch between them), key
// repeat and Num Lock; pointer speed, acceleration, scrolling and left-handed; and, on a
// laptop, the touchpad. Applied live and saved for login
// (InputSettings, ~/.config/hypr/input.lua). A changed setting gets a reset button beside it.
Column {
    id: root

    // Every layout and variant xkb knows: [{ layout, variant, name }]
    property var allLayouts: []
    property bool hasTouchpad: false

    readonly property var layouts: (InputSettings.get("input.kb_layout") ?? "").split(",").filter(s => s !== "")
    readonly property var variants: (InputSettings.get("input.kb_variant") ?? "").split(",")
    readonly property var kbOptions: (InputSettings.get("input.kb_options") ?? "").split(",").filter(s => s !== "")
    readonly property string switchOption: kbOptions.find(o => o.startsWith("grp:")) ?? ""

    function layoutName(layout: string, variant: string): string {
        return allLayouts.find(l => l.layout === layout && l.variant === (variant ?? ""))?.name ?? (variant ? `${layout} (${variant})` : layout);
    }

    function setLayouts(layouts: var, variants: var): void {
        InputSettings.setMany({ "input.kb_layout": layouts.join(","), "input.kb_variant": variants.join(",") });
        // Two or more layouts need a way to switch; Alt+Shift unless one is set
        if (layouts.length > 1 && switchOption === "")
            setOption("grp:", "grp:alt_shift_toggle");
    }

    // Replaces the kb_options entry starting with `prefix`
    function setOption(prefix: string, value: string): void {
        const kept = kbOptions.filter(o => !o.startsWith(prefix));
        InputSettings.set("input.kb_options", [...kept, ...(value !== "" ? [value] : [])].join(","));
    }

    spacing: 24

    Component.onCompleted: InputSettings.refresh()

    // xkb's list of layouts ("! layout") and variants ("! variant": "  intl  us: English (US, intl.)")
    Process {
        command: ["sh", "-c", "sed -n '/^! layout/,/^$/p;/^! variant/,/^$/p' /usr/share/X11/xkb/rules/evdev.lst"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const list = [];
                for (const line of text.split("\n")) {
                    const variant = line.match(/^\s+(\S+)\s+(\S+): (.+)$/);
                    const layout = line.match(/^\s+(\S+)\s+(.+)$/);
                    if (variant)
                        list.push({ layout: variant[2], variant: variant[1], name: variant[3] });
                    else if (layout)
                        list.push({ layout: layout[1], variant: "", name: layout[2] });
                }
                root.allLayouts = list;
            }
        }
    }

    Process {
        command: ["hyprctl", "devices", "-j"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    // "…-touchpad", or a trackpad (e.g. Apple's)
                    root.hasTouchpad = JSON.parse(text).mice.some(m => /touchpad|trackpad/i.test(m.name));
                } catch (e) {}
            }
        }
    }

    PanelText {
        visible: InputSettings.lastError !== ""
        width: parent.width
        text: `\u{F0026}  ${InputSettings.lastError}`
        wrapMode: Text.WordWrap
        color: Theme.critical
    }

    SettingsGroup {
        title: "Keyboard"

        Item {
            id: layoutBlock

            property bool adding: false
            readonly property var matches: {
                const query = search.text.trim().toLowerCase();
                const list = query === "" ? root.allLayouts : root.allLayouts.filter(l => l.name.toLowerCase().includes(query) || l.layout === query);
                return list.slice(0, 60);
            }

            width: parent.width
            implicitHeight: layoutColumn.implicitHeight + 28

            Column {
                id: layoutColumn
                x: 16
                y: 14
                width: parent.width - 32
                spacing: 10

                Item {
                    width: parent.width
                    height: addButton.height

                    PanelText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.layouts.length > 1 ? "Layouts" : "Layout"
                    }

                    Reset {
                        anchors.right: addButton.left
                        anchors.rightMargin: 8
                        options: ["input.kb_layout", "input.kb_variant", "input.kb_options"]
                    }

                    PanelButton {
                        id: addButton
                        anchors.right: parent.right
                        icon: layoutBlock.adding ? "\u{F077}" : "\u{F0415}"
                        label: "Add"
                        highlighted: layoutBlock.adding
                        onClicked: {
                            layoutBlock.adding = !layoutBlock.adding;
                            if (layoutBlock.adding) {
                                search.text = "";
                                Qt.callLater(search.focusInput);
                            }
                        }
                    }
                }

                // The layouts in use, first is the default; × removes one
                Flow {
                    width: parent.width
                    spacing: 6

                    Repeater {
                        model: root.layouts

                        PanelButton {
                            required property string modelData
                            required property int index
                            label: `${root.layoutName(modelData, root.variants[index])}${root.layouts.length > 1 ? "  \u{F0156}" : ""}`
                            highlighted: index === 0
                            onClicked: {
                                if (root.layouts.length <= 1)
                                    return;
                                const layouts = [...root.layouts];
                                const variants = root.layouts.map((_, i) => root.variants[i] ?? "");
                                layouts.splice(index, 1);
                                variants.splice(index, 1);
                                root.setLayouts(layouts, variants);
                            }
                        }
                    }
                }

                // Adding: search, then pick
                Column {
                    visible: layoutBlock.adding
                    width: parent.width
                    spacing: 6

                    TextField {
                        id: search
                        width: parent.width
                        placeholder: "Search layouts, e.g. \"US\" or \"Dvorak\""
                    }

                    DropdownList {
                        width: parent.width
                        maxHeight: 220
                        localExpanded: true
                        items: layoutBlock.matches.map(l => ({ label: l.name, sublabel: l.variant ? `${l.layout} · ${l.variant}` : l.layout, entry: l }))
                        onChosen: item => {
                            const variants = root.layouts.map((_, i) => root.variants[i] ?? "");
                            root.setLayouts([...root.layouts, item.entry.layout], [...variants, item.entry.variant]);
                            layoutBlock.adding = false;
                        }
                    }
                }
            }
        }

        SettingRow {
            visible: root.layouts.length > 1
            label: "Switch layouts with"

            ChoiceButtons {
                choices: ["grp:alt_shift_toggle", "grp:ctrl_shift_toggle", "grp:shifts_toggle", "grp:caps_toggle"]
                current: root.switchOption
                format: option => ({ "grp:alt_shift_toggle": "Alt+Shift", "grp:ctrl_shift_toggle": "Ctrl+Shift", "grp:shifts_toggle": "Both Shifts", "grp:caps_toggle": "Caps Lock" })[option]
                onChosen: option => root.setOption("grp:", option)
            }
        }

        SliderRow {
            label: "Repeat delay"
            description: "How long a key is held before it repeats."
            option: "input.repeat_delay"
            from: 150
            to: 1000
            step: 10
            format: value => `${value} ms`
        }

        SliderRow {
            label: "Repeat rate"
            description: "Characters per second while a key is held."
            option: "input.repeat_rate"
            from: 10
            to: 80
            step: 1
            format: value => `${value} /s`
        }

        SettingRow {
            label: "Num Lock on at login"

            Row {
                spacing: 8

                Reset {
                    anchors.verticalCenter: parent.verticalCenter
                    options: ["input.numlock_by_default"]
                }

                Toggle {
                    anchors.verticalCenter: parent.verticalCenter
                    checked: InputSettings.get("input.numlock_by_default") ?? false
                    onToggled: InputSettings.set("input.numlock_by_default", !checked)
                }
            }
        }

        SettingRow {
            label: "Try it"

            TextField {
                width: 260
                placeholder: "Type here to test"
            }
        }
    }

    SettingsGroup {
        title: "Mouse"

        SliderRow {
            label: "Pointer speed"
            option: "input.sensitivity"
            from: -1
            to: 1
            step: 0.05
            format: value => value === 0 ? "Default" : value > 0 ? `+${value.toFixed(2)}` : value.toFixed(2)
        }

        SettingRow {
            label: "Acceleration"
            description: "Adaptive speeds the pointer up on fast movements; flat keeps it constant, which suits games."

            Row {
                spacing: 8

                Reset {
                    anchors.verticalCenter: parent.verticalCenter
                    options: ["input.accel_profile"]
                }

                ChoiceButtons {
                    anchors.verticalCenter: parent.verticalCenter
                    choices: ["adaptive", "flat"]
                    current: InputSettings.get("input.accel_profile") || "adaptive"
                    format: profile => profile === "flat" ? "Flat" : "Adaptive"
                    onChosen: profile => InputSettings.set("input.accel_profile", profile)
                }
            }
        }

        SliderRow {
            label: "Scroll speed"
            option: "input.scroll_factor"
            from: 0.25
            to: 3
            step: 0.05
            format: value => `${value.toFixed(2)}×`
        }

        SettingRow {
            label: "Natural scrolling"
            description: "Content moves with the wheel, like on a phone."

            Row {
                spacing: 8

                Reset {
                    anchors.verticalCenter: parent.verticalCenter
                    options: ["input.natural_scroll"]
                }

                Toggle {
                    anchors.verticalCenter: parent.verticalCenter
                    checked: InputSettings.get("input.natural_scroll") ?? false
                    onToggled: InputSettings.set("input.natural_scroll", !checked)
                }
            }
        }

        SettingRow {
            label: "Left-handed"
            description: "Swaps the left and right buttons."

            Row {
                spacing: 8

                Reset {
                    anchors.verticalCenter: parent.verticalCenter
                    options: ["input.left_handed"]
                }

                Toggle {
                    anchors.verticalCenter: parent.verticalCenter
                    checked: InputSettings.get("input.left_handed") ?? false
                    onToggled: InputSettings.set("input.left_handed", !checked)
                }
            }
        }
    }

    SettingsGroup {
        visible: root.hasTouchpad
        title: "Touchpad"

        SettingRow {
            label: "Tap to click"

            Row {
                spacing: 8

                Reset {
                    anchors.verticalCenter: parent.verticalCenter
                    options: ["input.touchpad.tap_to_click"]
                }

                Toggle {
                    anchors.verticalCenter: parent.verticalCenter
                    checked: InputSettings.get("input.touchpad.tap_to_click") ?? false
                    onToggled: InputSettings.set("input.touchpad.tap_to_click", !checked)
                }
            }
        }

        SettingRow {
            label: "Tap and drag"
            description: "Tap, then touch again and move to drag."

            Row {
                spacing: 8

                Reset {
                    anchors.verticalCenter: parent.verticalCenter
                    options: ["input.touchpad.tap_and_drag"]
                }

                Toggle {
                    anchors.verticalCenter: parent.verticalCenter
                    checked: InputSettings.get("input.touchpad.tap_and_drag") ?? false
                    onToggled: InputSettings.set("input.touchpad.tap_and_drag", !checked)
                }
            }
        }

        SettingRow {
            label: "Natural scrolling"

            Row {
                spacing: 8

                Reset {
                    anchors.verticalCenter: parent.verticalCenter
                    options: ["input.touchpad.natural_scroll"]
                }

                Toggle {
                    anchors.verticalCenter: parent.verticalCenter
                    checked: InputSettings.get("input.touchpad.natural_scroll") ?? false
                    onToggled: InputSettings.set("input.touchpad.natural_scroll", !checked)
                }
            }
        }

        SettingRow {
            label: "Ignore while typing"

            Row {
                spacing: 8

                Reset {
                    anchors.verticalCenter: parent.verticalCenter
                    options: ["input.touchpad.disable_while_typing"]
                }

                Toggle {
                    anchors.verticalCenter: parent.verticalCenter
                    checked: InputSettings.get("input.touchpad.disable_while_typing") ?? false
                    onToggled: InputSettings.set("input.touchpad.disable_while_typing", !checked)
                }
            }
        }

        SettingRow {
            label: "Right click"
            description: "Press the bottom-right corner, or click with two fingers anywhere."

            Row {
                spacing: 8

                Reset {
                    anchors.verticalCenter: parent.verticalCenter
                    options: ["input.touchpad.clickfinger_behavior"]
                }

                ChoiceButtons {
                    anchors.verticalCenter: parent.verticalCenter
                    choices: [false, true]
                    current: InputSettings.get("input.touchpad.clickfinger_behavior") ?? false
                    format: fingers => fingers ? "Two fingers" : "Corner"
                    onChosen: fingers => InputSettings.set("input.touchpad.clickfinger_behavior", fingers)
                }
            }
        }

        SliderRow {
            label: "Scroll speed"
            option: "input.touchpad.scroll_factor"
            from: 0.25
            to: 3
            step: 0.05
            format: value => `${value.toFixed(2)}×`
        }
    }

    // Shown once any of `options` has been changed here; puts them back to the config's values
    component Reset: PanelButton {
        property var options: []

        visible: options.some(option => InputSettings.isCustom(option))
        icon: "\u{F0E2}"
        onClicked: InputSettings.reset(options)
    }

    // A slider for a number option, applied once it stops moving
    component SliderRow: SettingRow {
        id: sliderRow

        property string option
        property real from
        property real to
        property real step: 1
        property var format: value => `${value}`

        readonly property real saved: InputSettings.get(option) ?? from
        property real shown: saved

        onSavedChanged: shown = saved

        Row {
            spacing: 10

            Reset {
                anchors.verticalCenter: parent.verticalCenter
                options: [sliderRow.option]
            }

            Slider {
                anchors.verticalCenter: parent.verticalCenter
                width: 220
                from: sliderRow.from
                to: sliderRow.to
                value: sliderRow.shown
                onMoved: value => {
                    sliderRow.shown = Math.round(value / sliderRow.step) * sliderRow.step;
                    commit.restart();
                }
            }

            PanelText {
                anchors.verticalCenter: parent.verticalCenter
                width: 70
                horizontalAlignment: Text.AlignRight
                text: sliderRow.format(Math.round(sliderRow.shown / sliderRow.step) * sliderRow.step)
                dim: true
            }
        }

        Timer {
            id: commit
            interval: 300
            // Whole numbers, or two decimals for fractional steps
            onTriggered: InputSettings.set(sliderRow.option, Number(sliderRow.shown.toFixed(sliderRow.step < 1 ? 2 : 0)))
        }
    }
}
