import QtQuick
import Quickshell
import Quickshell.Io

// Headless: watches for the Thunderbolt/USB4 PCIe MMIO-starvation firmware
// bug and sends one notification per boot pointing at the bundled fix
// script. Never applies the fix itself -- that needs root, edits boot
// config, and needs a reboot to verify, none of which a background shell
// service should ever do unattended.
Item {
  id: root

  property var shell: null

  readonly property string home: Quickshell.env("HOME")
  readonly property string pluginDir: home + "/.config/omarchy/plugins/thunderbolt-pcie-fix"
  readonly property string fixScript: pluginDir + "/bin/omarchy-thunderbolt-pcie-fix"
  readonly property string notifiedStatePath: home + "/.local/state/omarchy/indicators/thunderbolt-pcie-fix-notified"

  function runCheck() {
    if (checkProcess.running) return
    checkProcess.running = true
  }

  // Only ever notifies once per boot: the marker file lives under
  // ~/.local/state, which does not get cleared on a normal reboot, so a
  // fresh boot without the marker means either this is the first check
  // since boot or the fix already landed and got reverted -- worth telling
  // the user about again either way.
  Process {
    id: checkProcess
    command: ["bash", root.fixScript, "--check", "--quiet"]
    onExited: function(exitCode) {
      if (exitCode !== 1) return
      notifyIfNeededProcess.running = true
    }
  }

  Process {
    id: notifyIfNeededProcess
    command: ["bash", "-c",
      "mkdir -p \"$(dirname " + '"' + root.notifiedStatePath + '"' + ")\"; " +
      "[[ -f \"" + root.notifiedStatePath + "\" ]] && exit 0; " +
      "touch \"" + root.notifiedStatePath + "\"; " +
      "omarchy-notification-send -u normal " +
      "'Thunderbolt dock may need a fix' " +
      "'USB/Ethernet behind a Thunderbolt dock look unbound due to a firmware PCIe bug. Run: " + root.fixScript + "'"
    ]
  }

  Timer {
    // Shortly after shell start covers a dock already connected at login;
    // the slow periodic timer below catches one plugged in later.
    interval: 15000
    running: true
    repeat: false
    onTriggered: root.runCheck()
  }

  Timer {
    interval: 3600000
    running: true
    repeat: true
    onTriggered: root.runCheck()
  }
}
