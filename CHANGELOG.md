# Changelog

All notable changes to omarchy-thunderbolt-pcie-fix. Versions follow [Semantic Versioning](https://semver.org/).
Versions before the release of 2026-09-30 were assigned retroactively from the commit history.

## 1.1.2 – 2026-09-30

### Changed

- Author set to "Claude Code / Thomas Alt" (was "Omarchy"); README: Changelog section; this CHANGELOG.

## 1.1.1 – 2026-09-15

### Fixed

- Notification markers are scoped to the boot (runtime dir), not the home directory, so they can't suppress a later real regression.

## 1.1.0 – 2026-09-15

### Added

- The check distinguishes "fix staged, reboot" (exit 2) from "fix needed" (exit 1).

## 1.0.0 – 2026-09-15

### Added

- Initial release: detect and fix Thunderbolt/USB4 PCIe MMIO starvation (`pci=realloc=on` in the live Limine entry).
