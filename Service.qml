import QtQuick
import Quickshell
import Quickshell.Io

// Headless: watches for the Thunderbolt/USB4 PCIe MMIO-starvation firmware
// bug and sends one notification per boot -- pointing at the bundled fix
// script if it hasn't been run yet, or telling you to just reboot if it
// has (the two are distinguished by the fix script's own --check exit
// code; see its own comments for why the unprivileged distinction is only
// approximate). Never applies the fix itself -- that needs root, edits
// boot config, and needs a reboot to verify, none of which a background
// shell service should ever do unattended.
Item {
  id: root

  property var shell: null

  readonly property string home: Quickshell.env("HOME")
  readonly property string pluginDir: home + "/.config/omarchy/plugins/thunderbolt-pcie-fix"
  readonly property string fixScript: pluginDir + "/bin/omarchy-thunderbolt-pcie-fix"
  // Boot-scoped (tmpfs, cleared automatically every boot/logout) rather than
  // ~/.local/state: these markers exist only to dedupe repeat notifications
  // within a single boot, and a marker that outlived its boot would
  // permanently suppress the notification for a real future regression.
  readonly property string stateDir: Quickshell.env("XDG_RUNTIME_DIR") + "/omarchy/indicators"
  // Separate marker per exit code, not one shared marker: a boot can
  // legitimately pass through "needs fix" (1) and, once you've run it,
  // "staged, reboot" (2) in the same session, and each transition is worth
  // its own one-time notification rather than only ever firing once total.
  readonly property string neededMarker: stateDir + "/thunderbolt-pcie-fix-notified-needed"
  readonly property string stagedMarker: stateDir + "/thunderbolt-pcie-fix-notified-staged"

  function runCheck() {
    if (checkProcess.running) return
    checkProcess.running = true
  }

  function notifyOnce(marker, title, body) {
    notifyProcess.command = ["bash", "-c",
      "mkdir -p " + JSON.stringify(root.stateDir) + "; " +
      "[[ -f " + JSON.stringify(marker) + " ]] && exit 0; " +
      "touch " + JSON.stringify(marker) + "; " +
      "omarchy-notification-send -u normal " + JSON.stringify(title) + " " + JSON.stringify(body)
    ]
    notifyProcess.running = true
  }

  Process {
    id: checkProcess
    command: ["bash", root.fixScript, "--check", "--quiet"]
    onExited: function(exitCode) {
      if (exitCode === 1) {
        root.notifyOnce(root.neededMarker,
          "Thunderbolt dock may need a fix",
          "USB/Ethernet behind a Thunderbolt dock look unbound due to a firmware PCIe bug. Run: " + root.fixScript)
      } else if (exitCode === 2) {
        root.notifyOnce(root.stagedMarker,
          "Thunderbolt dock fix needs a reboot",
          "The PCIe fix has already been applied but isn't active yet. Reboot to finish: systemctl reboot")
      }
    }
  }

  Process {
    id: notifyProcess
  }

  Timer {
    // Shortly after shell start covers a dock already connected at login;
    // the slow periodic timer below catches one plugged in later, or a
    // needed -> staged transition after you've run the fix mid-session.
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
