import QtQuick
import QtQuick.Controls
import Quickshell
import qs
import qs.components
import qs.services

// Opened from the clock: a month calendar you can page through. Clicking a day opens its
// notes beside the calendar (see Todos): that day's notes, overdue ones on today, and the
// ongoing list, with a field to add more. Notes are like git messages: the first line is the
// title, and clicking it shows the rest. The notes scroll on their own; the calendar stays put.
Row {
    id: root

    signal closeRequested

    readonly property date today: clock.date
    property int month: today.getMonth()
    property int year: today.getFullYear()
    readonly property bool showingToday: month === today.getMonth() && year === today.getFullYear()

    // yyyy-MM-dd of the day whose notes are open, "" when closed
    property string selectedDay: ""
    readonly property int notesWidth: 300
    // Notes whose body is showing, by id
    property var expandedNotes: ({})

    function toggleNote(id: real): void {
        expandedNotes = Object.assign({}, expandedNotes, { [id]: !expandedNotes[id] });
    }

    function shiftMonth(delta: int): void {
        const shifted = month + delta;
        year += Math.floor(shifted / 12);
        month = ((shifted % 12) + 12) % 12;
    }

    function goToToday(): void {
        month = today.getMonth();
        year = today.getFullYear();
    }

    function selectDay(day: string): void {
        selectedDay = selectedDay === day ? "" : day;
    }

    // "2026-10-01" -> a Date at local midnight
    function parseDay(day: string): date {
        const [y, m, d] = day.split("-").map(Number);
        return new Date(y, m - 1, d);
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    // --- Calendar ---
    Column {
        id: calendar
        width: 290
        spacing: 10

        // ‹  Month Year  ›
        Item {
            width: parent.width
            height: previous.implicitHeight

            PanelButton {
                id: previous
                icon: "\u{F053}"
                onClicked: root.shiftMonth(-1)
            }

            PanelText {
                anchors.centerIn: parent
                text: Qt.formatDate(new Date(root.year, root.month, 1), "MMMM yyyy")
            }

            PanelButton {
                anchors.right: parent.right
                icon: "\u{F054}"
                onClicked: root.shiftMonth(1)
            }
        }

        Column {
            width: parent.width

            DayOfWeekRow {
                width: parent.width
                locale: grid.locale
                delegate: PanelText {
                    required property string shortName
                    text: shortName.slice(0, 2)
                    dim: true
                    horizontalAlignment: Text.AlignHCenter
                }
            }

            MonthGrid {
                id: grid
                width: parent.width
                month: root.month
                year: root.year
                locale: Qt.locale("en_GB")
                spacing: 2

                delegate: Item {
                    id: cell

                    required property int day
                    required property int month
                    required property bool today
                    required property var date

                    readonly property string key: Todos.dayKey(date)
                    readonly property bool selected: key === root.selectedDay

                    implicitWidth: 36
                    implicitHeight: 32

                    Rectangle {
                        anchors.centerIn: parent
                        width: 30
                        height: 30
                        radius: 15
                        color: cell.today ? Theme.accent : dayMouse.containsMouse ? Theme.surface : "transparent"
                        border.width: cell.selected ? 2 : 0
                        border.color: cell.today ? Theme.text : Theme.accent
                    }

                    PanelText {
                        anchors.centerIn: parent
                        text: cell.day
                        opacity: cell.month === grid.month ? 1 : 0.3
                        color: cell.today ? Theme.background : Theme.text
                        font.bold: cell.today
                    }

                    // Has open notes
                    Rectangle {
                        visible: Todos.busyDays[cell.key] ?? false
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 4
                        width: 4
                        height: 4
                        radius: 2
                        color: cell.today ? Theme.background : Theme.accent
                    }

                    MouseArea {
                        id: dayMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.selectDay(cell.key)
                    }
                }
            }
        }

        Row {
            spacing: 8

            PanelButton {
                visible: !root.showingToday
                label: "Today"
                onClicked: root.goToToday()
            }
        }
    }

    // --- Notes for the selected day, sliding out to the right ---
    // Same height as the calendar: the title and add field stay put, the notes between scroll
    Item {
        width: root.selectedDay !== "" ? root.notesWidth : 0
        height: calendar.height
        clip: true

        Behavior on width {
            NumberAnimation { duration: Theme.panelAnimDuration; easing.type: Easing.OutCubic }
        }

        // Laid out at full width so it slides in rather than reflowing
        Item {
            x: 16
            width: root.notesWidth - 16
            height: parent.height

            // Date and close
            Item {
                id: notesHeader
                width: parent.width
                height: dayTitle.implicitHeight + 8

                PanelText {
                    id: dayTitle
                    text: root.selectedDay !== "" ? Qt.formatDate(root.parseDay(root.selectedDay), "dddd d MMMM") : ""
                    font.bold: true
                }

                PanelText {
                    anchors.right: parent.right
                    text: "\u{F00D}"
                    color: closeMouse.containsMouse ? Theme.accent : Theme.subtext

                    MouseArea {
                        id: closeMouse
                        anchors.fill: parent
                        anchors.margins: -4
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.selectedDay = ""
                    }
                }
            }

            Flickable {
                id: noteList
                y: notesHeader.height
                width: parent.width
                height: parent.height - notesHeader.height - noteInput.height - 8
                contentHeight: noteColumn.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                clip: true

                Column {
                    id: noteColumn
                    // Room for the scrollbar
                    width: noteList.width - 8
                    spacing: 4

                    Repeater {
                        model: root.selectedDay !== "" ? Todos.forDay(root.selectedDay) : []

                        NoteRow {
                            required property var modelData
                            note: modelData
                        }
                    }

                    PanelText {
                        visible: root.selectedDay !== "" && Todos.forDay(root.selectedDay).length === 0
                        text: "Nothing on this day"
                        dim: true
                    }

                    PanelSection {
                        visible: Todos.ongoing.length > 0
                        topPadding: 8
                        text: "Ongoing"
                    }

                    Repeater {
                        model: Todos.ongoing

                        NoteRow {
                            required property var modelData
                            note: modelData
                        }
                    }
                }
            }

            // Scrollbar, when the notes don't fit
            Rectangle {
                visible: noteList.contentHeight > noteList.height
                anchors.right: parent.right
                y: noteList.y + noteList.visibleArea.yPosition * noteList.height
                width: 4
                height: noteList.visibleArea.heightRatio * noteList.height
                radius: 2
                color: Theme.subtext
            }

            NoteInput {
                id: noteInput
                anchors.bottom: parent.bottom
                width: parent.width
            }
        }
    }

    // Checkbox, title (the first line; struck through when done), overdue tag and delete on
    // hover. Notes with more lines show an arrow; it or a click on the title reveals the rest.
    // Text can be selected (drag) and copied, and links clicked.
    component NoteRow: Item {
        id: noteRow

        property var note
        readonly property var lines: note.text.split("\n")
        readonly property string title: lines[0]
        readonly property string body: lines.slice(1).join("\n").trim()
        readonly property bool hasBody: body !== ""
        readonly property bool expanded: hasBody && (root.expandedNotes[note.id] ?? false)
        readonly property bool overdue: note.date && note.date < Todos.today && !note.done
        // Title and arrow light up together when either is hovered
        readonly property bool toggleHovered: hasBody && (titleHover.hovered || expandMouse.containsMouse)

        width: parent?.width ?? 0
        implicitHeight: content.implicitHeight + 6
        height: implicitHeight

        HoverHandler {
            id: rowHover
        }

        PanelText {
            y: 3
            text: noteRow.note.done ? "\u{F14A}" : "\u{F096}"
            color: noteRow.note.done ? Theme.accent : Theme.subtext

            MouseArea {
                anchors.fill: parent
                anchors.margins: -4
                cursorShape: Qt.PointingHandCursor
                onClicked: Todos.toggle(noteRow.note.id)
            }
        }

        Column {
            id: content
            x: 26
            y: 3
            width: parent.width - x - 44
            spacing: 2

            // A click shows/hides the rest of the note; dragging selects text to copy instead
            SelectableText {
                id: titleText
                width: parent.width
                plainText: noteRow.title
                font.strikeout: noteRow.note.done
                dim: noteRow.note.done
                color: noteRow.toggleHovered ? Theme.accent : (noteRow.note.done ? Theme.subtext : Theme.text)

                HoverHandler {
                    id: titleHover
                }

                TapHandler {
                    enabled: noteRow.hasBody
                    gesturePolicy: TapHandler.DragThreshold
                    onTapped: {
                        // Not on links, and only the first click of a double-click
                        if (titleText.hoveredLink === "" && tapCount === 1)
                            root.toggleNote(noteRow.note.id);
                    }
                }
            }

            PanelText {
                visible: noteRow.overdue
                text: noteRow.overdue ? `overdue · ${Qt.formatDate(root.parseDay(noteRow.note.date), "d MMM")}` : ""
                color: Theme.accent
                font.pixelSize: Theme.panelFontSize - 2
            }

            // The rest of the note, with a line down its left edge
            Item {
                visible: noteRow.expanded
                width: parent.width
                height: bodyText.implicitHeight + 4

                Rectangle {
                    width: 2
                    height: parent.height
                    radius: 1
                    color: Theme.surfaceHover
                }

                SelectableText {
                    id: bodyText
                    x: 10
                    y: 2
                    width: parent.width - x
                    plainText: noteRow.body
                    dim: true
                    font.pixelSize: Theme.panelFontSize - 1
                }
            }
        }

        // Show or hide the rest of the note
        PanelText {
            visible: noteRow.hasBody
            x: parent.width - 38
            y: 3
            text: noteRow.expanded ? "\u{F077}" : "\u{F078}"
            color: noteRow.toggleHovered ? Theme.accent : Theme.subtext
            font.pixelSize: Theme.panelFontSize - 2

            MouseArea {
                id: expandMouse
                anchors.fill: parent
                anchors.margins: -6
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggleNote(noteRow.note.id)
            }
        }

        PanelText {
            visible: rowHover.hovered
            anchors.right: parent.right
            y: 3
            text: "\u{F00D}"
            color: deleteMouse.containsMouse ? Theme.accent : Theme.subtext

            MouseArea {
                id: deleteMouse
                anchors.fill: parent
                anchors.margins: -4
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Todos.remove(noteRow.note.id)
            }
        }
    }

    // Field for a new note: Enter (or +) adds it to the selected day, or to Ongoing when that's
    // switched on. Shift+Enter starts a new line; the first line is the note's title. Grows to
    // about five lines, then scrolls to keep the cursor in view.
    component NoteInput: Column {
        id: noteInput

        property bool ongoing: false

        function submit(): void {
            Todos.add(input.text, noteInput.ongoing ? "" : root.selectedDay);
            input.text = "";
        }

        spacing: 6

        Row {
            width: parent.width
            spacing: 8

            Rectangle {
                width: parent.width - addButton.width - parent.spacing
                height: Math.max(addButton.height, inputScroll.height + 14)
                radius: 8
                color: Theme.surface
                border.width: input.activeFocus ? 1 : 0
                border.color: Theme.accent

                Flickable {
                    id: inputScroll

                    // Scroll so the cursor's line is in view
                    function ensureVisible(rect: rect): void {
                        if (contentY >= rect.y)
                            contentY = rect.y;
                        else if (contentY + height <= rect.y + rect.height)
                            contentY = rect.y + rect.height - height;
                    }

                    x: 10
                    y: 7
                    width: parent.width - 20
                    height: Math.min(input.contentHeight, 5 * input.font.pixelSize * 1.3)
                    contentWidth: width
                    contentHeight: input.contentHeight
                    boundsBehavior: Flickable.StopAtBounds
                    clip: true

                    TextEdit {
                        id: input
                        width: inputScroll.width
                        wrapMode: TextEdit.Wrap
                        color: Theme.text
                        selectionColor: Theme.accent
                        selectedTextColor: Theme.background
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.panelFontSize
                        onCursorRectangleChanged: inputScroll.ensureVisible(cursorRectangle)

                        Keys.onReturnPressed: event => {
                            if (event.modifiers & Qt.ShiftModifier)
                                event.accepted = false;
                            else
                                noteInput.submit();
                        }
                        Keys.onEnterPressed: event => noteInput.submit()

                        PanelText {
                            visible: input.text === ""
                            text: noteInput.ongoing ? "Add an ongoing note…" : "Add a note…"
                            dim: true
                        }
                    }
                }
            }

            PanelButton {
                id: addButton
                icon: "\u{F067}"
                onClicked: noteInput.submit()
            }
        }

        Item {
            width: parent.width
            height: ongoingToggle.height

            Toggle {
                id: ongoingToggle
                checked: noteInput.ongoing
                onToggled: noteInput.ongoing = !noteInput.ongoing
            }

            PanelText {
                anchors.verticalCenter: parent.verticalCenter
                x: ongoingToggle.width + 8
                text: "Ongoing (no date)"
                dim: true
                font.pixelSize: Theme.panelFontSize - 1
            }
        }
    }
}
