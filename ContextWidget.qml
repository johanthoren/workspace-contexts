import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "io.github.johanthoren.workspace-contexts"

  property var contexts: []
  property int bankSlots: 9
  property var fallbackContextColors: ({
    blue: "#7aa2f7",
    green: "#9ece6a",
    magenta: "#ad8ee6",
    yellow: "#e0af68",
    cyan: "#449dab",
    red: "#f7768e"
  })
  property var contextColors: fallbackContextColors
  property string lastThemeText: ""
  // A dump requested while one is in flight would otherwise be dropped, leaving
  // the bar on stale contexts after a quick second edit.
  property bool dumpPending: false
  // contexts.json did not exist, so the dump seeds it. The FileView has nothing
  // to watch until that lands.
  property bool seedPending: false

  readonly property string parsePath: {
    var path = Qt.resolvedUrl("./parse_contexts.py").toString()
    if (path.indexOf("file://") === 0) path = path.slice(7)
    return path
  }
  readonly property string userContextsPath: Quickshell.env("HOME") + "/.config/omarchy/io.github.johanthoren.workspace-contexts/contexts.json"

  function requestDump() {
    if (parser.running) {
      root.dumpPending = true
      return
    }
    parser.running = true
  }

  function applyDump(raw) {
    var parsed
    try {
      parsed = JSON.parse(String(raw || ""))
    } catch (e) {
      return
    }
    if (!parsed || typeof parsed !== "object" || !Array.isArray(parsed.contexts) || parsed.contexts.length === 0) return

    var next = []
    for (var i = 0; i < parsed.contexts.length; i++) {
      var row = parsed.contexts[i]
      if (!row || typeof row !== "object") continue
      if (typeof row.name !== "string" || row.name.length === 0) continue
      if (typeof row.base !== "number") continue
      if (typeof row.accent !== "string") continue
      next.push({ name: row.name, base: row.base, accent: row.accent })
    }
    if (next.length === 0) return

    // parse_contexts.py already clamps this; the widget re-checks because it
    // validates every other field it reads out of the dump.
    if (typeof parsed.slots === "number" && parsed.slots >= 1) root.bankSlots = Math.min(10, Math.floor(parsed.slots))
    if (parsed.fallback && typeof parsed.fallback === "object") {
      var fallback = {}
      var keys = ["blue", "green", "magenta", "yellow", "cyan", "red"]
      for (var k = 0; k < keys.length; k++) {
        var accentName = keys[k]
        var value = parsed.fallback[accentName]
        fallback[accentName] = (typeof value === "string") ? value : root.fallbackContextColors[accentName]
      }
      root.fallbackContextColors = fallback
    }
    root.contexts = next
    if (root.lastThemeText) root.loadContextColors(root.lastThemeText)
    else root.contextColors = root.fallbackContextColors

    if (root.seedPending) contextsFile.reload()
  }

  function loadContextColors(raw) {
    root.lastThemeText = String(raw || "")
    var colors = {}
    var keys = ["blue", "green", "magenta", "yellow", "cyan", "red"]
    for (var k = 0; k < keys.length; k++) colors[keys[k]] = root.fallbackContextColors[keys[k]]

    var lines = root.lastThemeText.split("\n")
    for (var i = 0; i < lines.length; i++) {
      var match = lines[i].match(/^\s*(blue|green|magenta|yellow|cyan|red)\s*=\s*["'](#[0-9A-Fa-f]{6})/)
      if (match) colors[match[1]] = match[2]
    }
    root.contextColors = colors
  }

  function contextIndexForWorkspace(id) {
    if (id < 1) return -1
    for (var i = 0; i < root.contexts.length; i++) {
      var slot = id - root.contexts[i].base
      if (slot >= 1 && slot <= root.bankSlots) return i
    }
    return -1
  }

  function contextColor(index) {
    var ctx = root.contexts[index]
    if (!ctx) return Color.accent
    return root.contextColors[ctx.accent] || Color.accent
  }

  function workspaceById(id) {
    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++) {
      if (values[i].id === id) return values[i]
    }
    return null
  }

  function workspaceIds() {
    if (!root.activeContext) return []
    var cap = Math.min(5, root.bankSlots)
    var ids = []
    for (var slot = 1; slot <= cap; slot++) ids.push(root.activeContext.base + slot)

    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++) {
      var id = values[i].id
      if (root.contextIndexForWorkspace(id) === root.activeContextIndex && ids.indexOf(id) === -1) ids.push(id)
    }
    ids.sort(function(left, right) { return left - right })
    return ids
  }

  function localSlot(id) {
    if (!root.activeContext) return id
    return id - root.activeContext.base
  }

  function focusWorkspace(id) {
    if (!root.bar) return
    root.bar.run("hyprctl dispatch " + Util.shellQuote("hl.dsp.focus({ workspace = \"" + id + "\" })"))
  }

  function focusSlot(slot) {
    if (!root.activeContext) return
    root.focusWorkspace(root.activeContext.base + slot)
  }

  function focusContext(index) {
    var ctx = root.contexts[index]
    if (!ctx) return
    root.focusWorkspace(ctx.base + 1)
  }

  readonly property int focusedContextIndex: {
    var workspace = Hyprland.focusedWorkspace
    return workspace === null ? -1 : root.contextIndexForWorkspace(workspace.id)
  }
  readonly property int activeContextIndex: focusedContextIndex >= 0 ? focusedContextIndex : 0
  readonly property var activeContext: root.contexts.length > 0 ? root.contexts[root.activeContextIndex] : null
  readonly property color activeContextColor: (root.activeContext && root.contextColors[root.activeContext.accent]) || Color.accent
  readonly property real trailingGap: root.vertical ? 0 : Style.spaceReal(1.5)

  implicitWidth: content.implicitWidth + trailingGap
  implicitHeight: content.implicitHeight

  FileView {
    id: contextsFile
    path: root.userContextsPath
    watchChanges: true
    printErrors: false
    onLoaded: {
      root.seedPending = false
      root.requestDump()
    }
    onFileChanged: reload()
    onLoadFailed: {
      // reload() of a still-missing path emits loadFailed again. Keep the flag
      // set across the dump so that retry does not start another dump.
      if (root.seedPending) {
        root.seedPending = false
        return
      }
      root.seedPending = true
      root.requestDump()
    }
  }

  FileView {
    path: Quickshell.env("HOME") + "/.local/state/omarchy/current/theme/colors.toml"
    watchChanges: true
    printErrors: false
    onLoaded: root.loadContextColors(text())
    onFileChanged: reload()
    onLoadFailed: {
      root.lastThemeText = ""
      root.contextColors = root.fallbackContextColors
    }
  }

  Process {
    id: parser
    command: ["/usr/bin/python3", root.parsePath, "--dump"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyDump(text)
    }
    onExited: {
      if (root.dumpPending) {
        root.dumpPending = false
        root.requestDump()
      }
    }
  }

  Component.onCompleted: root.requestDump()

  GridLayout {
    id: content
    columns: root.vertical ? 1 : 2
    columnSpacing: root.vertical ? 0 : Style.space(3)
    rowSpacing: root.vertical ? Style.space(2) : 0

    GridLayout {
      columns: root.vertical ? 1 : Math.max(1, root.workspaceIds().length)
      columnSpacing: root.vertical ? 0 : Style.space(1)
      rowSpacing: root.vertical ? Style.space(2) : 0
      Layout.alignment: Qt.AlignVCenter

      Repeater {
        model: root.workspaceIds()

        Item {
          id: slot
          required property int modelData

          readonly property var workspace: root.workspaceById(modelData)
          readonly property bool occupied: workspace !== null && workspace.toplevels.values.length > 0
          readonly property bool focused: Hyprland.focusedWorkspace !== null && Hyprland.focusedWorkspace.id === modelData
          readonly property int workspaceNumber: root.localSlot(modelData)

          implicitWidth: button.implicitWidth
          implicitHeight: button.implicitHeight
          opacity: occupied || focused ? 1 : 0.5

          WidgetButton {
            id: button
            anchors.fill: parent
            bar: root.bar
            text: String(slot.workspaceNumber)
            horizontalMargin: 6
            verticalPadding: 6
            fixedWidth: root.vertical ? root.barSize : Style.space(20)
            fixedHeight: root.barSize
            tooltipText: root.activeContext ? root.activeContext.name + " workspace " + slot.workspaceNumber : ""
            onPressed: function() { root.focusSlot(slot.workspaceNumber) }
          }

          Rectangle {
            visible: slot.focused
            width: Math.max(button.labelWidth, Style.space(6))
            height: Style.spacing.hairline
            color: root.activeContextColor
            radius: 0
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Style.space(4)
          }
        }
      }
    }

    GridLayout {
      columns: root.vertical ? 1 : Math.max(1, root.contexts.length)
      columnSpacing: root.vertical ? 0 : Style.space(2)
      rowSpacing: root.vertical ? Style.space(2) : 0
      Layout.alignment: Qt.AlignVCenter

      Repeater {
        model: root.contexts.length

        WidgetButton {
          id: nameButton
          required property int index

          readonly property var ctx: root.contexts[nameButton.index]
          readonly property bool focused: nameButton.index === root.activeContextIndex
          readonly property color accent: root.contextColor(nameButton.index)

          bar: root.bar
          text: nameButton.ctx.name
          fontSize: Style.font.caption
          foreground: nameButton.focused ? nameButton.accent : (root.bar ? root.bar.barForeground : Color.foreground)
          dimmed: !nameButton.focused
          horizontalMargin: 6
          fixedHeight: root.barSize
          tooltipText: nameButton.ctx.name
          onPressed: function() { root.focusContext(nameButton.index) }
        }
      }
    }
  }
}
