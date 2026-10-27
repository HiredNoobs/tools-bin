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

    // An error from earlier in the session isn't shown again
    Component.onCompleted: {
        InputSettings.lastError = "";
        InputSettings.refresh();
    }

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

    Banner {
        text: InputSettings.lastError
        closable: true
        onClosed: InputSettings.lastError = ""
    }

    SettingsGroup {
        title: "Keyboard"

        SettingsBlock {
            id: layoutBlock

            property bool adding: false
            readonly property var matches: {
                const query = search.text.trim().toLowerCase();
                const list = query === "" ? root.allLayouts : root.allLayouts.filter(l => l.name.toLowerCase().includes(query) || l.layout === query);
                return list.slice(0, 60);
            }

            BlockHeader {
                title: root.layouts.length > 1 ? "Layouts" : "Layout"

                // ↺ for the layouts, their variants and the switching key together
                PanelButton {
                    visible: ["input.kb_layout", "input.kb_variant", "input.kb_options"].some(option => InputSettings.isCustom(option))
                    icon: "\u{F0E2}"
                    onClicked: InputSettings.reset(["input.kb_layout", "input.kb_variant", "input.kb_options"])
                }

                PanelButton {
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

        ChoiceRow {
            visible: root.layouts.length > 1
            label: "Switch layouts with"
            choices: ["grp:alt_shift_toggle", "grp:ctrl_shift_toggle", "grp:shifts_toggle", "grp:caps_toggle"]
            current: root.switchOption
            format: option => ({ "grp:alt_shift_toggle": "Alt+Shift", "grp:ctrl_shift_toggle": "Ctrl+Shift", "grp:shifts_toggle": "Both Shifts", "grp:caps_toggle": "Caps Lock" })[option]
            onChosen: option => root.setOption("grp:", option)
        }

        OptionSlider {
            label: "Repeat delay"
            description: "How long a key is held before it repeats."
            option: "input.repeat_delay"
            from: 150
            to: 1000
            step: 10
            format: value => `${value} ms`
        }

        OptionSlider {
            label: "Repeat rate"
            description: "Characters per second while a key is held."
            option: "input.repeat_rate"
            from: 10
            to: 80
            step: 1
            format: value => `${value} /s`
        }

        OptionToggle {
            label: "Num Lock on at login"
            option: "input.numlock_by_default"
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

        OptionSlider {
            label: "Pointer speed"
            option: "input.sensitivity"
            from: -1
            to: 1
            step: 0.05
            format: value => value === 0 ? "Default" : value > 0 ? `+${value.toFixed(2)}` : value.toFixed(2)
        }

        OptionChoice {
            label: "Acceleration"
            description: "Adaptive speeds the pointer up on fast movements; flat keeps it constant, which suits games."
            option: "input.accel_profile"
            fallback: "adaptive"
            choices: ["adaptive", "flat"]
            format: profile => profile === "flat" ? "Flat" : "Adaptive"
        }

        OptionSlider {
            label: "Scroll speed"
            option: "input.scroll_factor"
            from: 0.25
            to: 3
            step: 0.05
            format: value => `${value.toFixed(2)}×`
        }

        OptionToggle {
            label: "Natural scrolling"
            description: "Content moves with the wheel, like on a phone."
            option: "input.natural_scroll"
        }

        OptionToggle {
            label: "Left-handed"
            description: "Swaps the left and right buttons."
            option: "input.left_handed"
        }
    }

    SettingsGroup {
        visible: root.hasTouchpad
        title: "Touchpad"

        OptionToggle {
            label: "Tap to click"
            option: "input.touchpad.tap_to_click"
        }

        OptionToggle {
            label: "Tap and drag"
            description: "Tap, then touch again and move to drag."
            option: "input.touchpad.tap_and_drag"
        }

        OptionToggle {
            label: "Natural scrolling"
            option: "input.touchpad.natural_scroll"
        }

        OptionToggle {
            label: "Ignore while typing"
            option: "input.touchpad.disable_while_typing"
        }

        OptionChoice {
            label: "Right click"
            description: "Press the bottom-right corner, or click with two fingers anywhere."
            option: "input.touchpad.clickfinger_behavior"
            fallback: false
            choices: [false, true]
            format: fingers => fingers ? "Two fingers" : "Corner"
        }

        OptionSlider {
            label: "Scroll speed"
            option: "input.touchpad.scroll_factor"
            from: 0.25
            to: 3
            step: 0.05
            format: value => `${value.toFixed(2)}×`
        }
    }

    // Rows for one Hyprland option (InputSettings), applied live; ↺ once it's been changed
    // here puts the config's value back
    component OptionToggle: ToggleRow {
        property string option

        checked: InputSettings.get(option) ?? false
        changed: InputSettings.isCustom(option)
        onToggled: on => InputSettings.set(option, on)
        onReset: InputSettings.reset([option])
    }

    component OptionChoice: ChoiceRow {
        property string option
        // Unset options read as nothing (or an empty string)
        property var fallback
        readonly property var saved: InputSettings.get(option)

        current: saved === undefined || saved === null || saved === "" ? fallback : saved
        changed: InputSettings.isCustom(option)
        onChosen: value => InputSettings.set(option, value)
        onReset: InputSettings.reset([option])
    }

    // Applied once it stops moving
    component OptionSlider: SliderRow {
        property string option

        value: InputSettings.get(option) ?? from
        commitDelay: 300
        changed: InputSettings.isCustom(option)
        onCommitted: value => InputSettings.set(option, value)
        onReset: InputSettings.reset([option])
    }
}
