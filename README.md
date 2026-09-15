# omarchy-thunderbolt-pcie-fix

An [Omarchy](https://omarchy.org/) shell service that detects a firmware bug
affecting some laptops with a Thunderbolt/USB4 dock: the BIOS reserves too
small an MMIO window for the dock's PCIe hotplug bridge, so anything
tunneled behind it with a nontrivial PCIe footprint — typically the dock's
**USB hub** and/or its **built-in Ethernet** — fails to bind a driver, even
though Thunderbolt authorization itself (`boltctl`) succeeds and `lspci`
sees the devices fine. The kernel journal shows a pairing like:

```
pci 0000:0N:00.0: bridge window [mem size 0x00500000]: can't assign; no space
xhci_hcd 0000:07:00.0: init 0000:07:00.0 fail, -16
igc 0000:09:00.0: probe with driver igc failed with error -5
```

Confirmed on a Lenovo T490s/X390 with an HP Thunderbolt Dock G4, but the bug
class isn't specific to that combination — any USB4/TB4 dock with more than
a trivial PCIe footprint can hit it on an under-provisioned BIOS.

No bar icon, no UI. It just watches your kernel journal for the signature
above and sends one desktop notification per boot if it finds it, pointing
you at the bundled fix script — it never touches boot configuration itself.

## The fix

The kernel parameter `pci=realloc=on` makes Linux redo PCIe BAR/window
sizing itself instead of trusting the firmware's undersized reservation.

Getting it to actually take effect is the nonobvious part on a
[Limine](https://limine-bootloader.org/) + mkinitcpio-UKI system (Omarchy's
default): rebuilding the UKI via `kernel-install`/`limine-update` does
**not** reliably embed a brand-new cmdline parameter. Omarchy's
`limine-mkinitcpio` resolves its cmdline via `limine-entry-tool
--get-cmdline`, which on a normal (non-chroot) running system prefers
`/proc/cmdline` — the *live, already-booted* cmdline — over
`/etc/kernel/cmdline`. A brand-new parameter can't get embedded into a
rebuilt UKI until you've already booted with it once: a bootstrapping
deadlock.

The bundled fix script works around this by editing the **live boot
entry's `cmdline:` line directly in `/boot/limine.conf`**, which is what
Limine actually passes as LoadOptions at boot for a `protocol: efi` UKI
entry — independent of whatever is embedded in the UKI's own `.cmdline`
section. Once you've booted successfully with the parameter active once,
`/proc/cmdline` includes it, and every future UKI rebuild (kernel update,
`omarchy refresh limine`, etc.) keeps embedding it correctly on its own.
This is a one-time bootstrapping fix, not an ongoing maintenance burden.

On GRUB, the script instead edits `GRUB_CMDLINE_LINUX_DEFAULT` and
regenerates `grub.cfg`. On plain systemd-boot (no UKI embedding involved),
`kernel-install add-all` alone is generally sufficient, since its
`options` line is sourced from `/etc/kernel/cmdline` directly.

## Install

```
omarchy plugin add https://github.com/Thomster/omarchy-thunderbolt-pcie-fix.git
```

## Usage

Once installed and enabled, it runs in the background and, if it detects
the bug, sends a notification telling you to run:

```
sudo ~/.config/omarchy/plugins/thunderbolt-pcie-fix/bin/omarchy-thunderbolt-pcie-fix
```

That backs up every file it touches before editing it, refuses to do
anything if it can't find the bug's signature in this boot's kernel
journal (pass `--force` to override that gate), and prints exactly what it
changed plus how to verify after a reboot.

You can also run the read-only check yourself any time, without root:

```
~/.config/omarchy/plugins/thunderbolt-pcie-fix/bin/omarchy-thunderbolt-pcie-fix --check
```

Exit code `0` means either already fixed or no symptoms found; `1` means
the bug's signature was detected and the fix hasn't been applied yet.

## Requirements

- `bolt`/`boltctl` (Thunderbolt authorization — present by default on most
  Thunderbolt-capable installs)
- `systemd-journal` read access for the background detection check (the
  default on most desktop installs; if your journal is locked down further,
  the automatic notification won't fire, but the manual `--check`/fix
  commands above still work when run with `sudo`)
- One of: Limine, GRUB, or systemd-boot

## Related

Unlike my other Omarchy plugins, this one isn't a bar widget or a
UI-adjacent background service — it's a hardware/firmware workaround.
Nothing else in my other repos depends on it or is required by it.

## How this came to be

This is a personal customization for my own Omarchy setup, built with the
help of [Claude Code](https://claude.com/claude-code) (Anthropic's AI coding
agent) while chasing down exactly this bug on my own dock. I'm not a
professional plugin developer or a kernel/firmware engineer — please read
through the source before installing, especially since it edits boot
configuration, and open an issue if something looks off on your hardware.

## License

MIT
