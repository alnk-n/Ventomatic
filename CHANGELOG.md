# Changelog

All notable changes to "Batch Ventoy Deployer" will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [0.3.0] - 2026-05-20
### Added
- Parallel drive processing: all selected drives now format and copy ISOs simultaneously using background jobs, yielding roughly N-fold speedup for N drives
- Zenity GUI: disk selection uses a checklist dialog and confirmation uses a question dialog when a display is available (`$DISPLAY` or `$WAYLAND_DISPLAY`); terminal prompts are preserved as a full fallback for headless/SSH use
- `--help` flag with lab-friendly output: explains what the tool does, where to place ISOs, and labels the config section as admin-managed; works without sudo
- `Makefile` with `make install`, `make update`, and `make uninstall` targets for easier setup
### Changed
- Per-drive output buffered to temp files and printed in order after each job completes, preventing interleaved log output during parallel processing
- Signal trap now sends `SIGTERM` to the entire process group (`kill -- -$$`) on interrupt, letting background subshells run their own mount cleanup paths
- `ventoy_mnt` scalar replaced with `active_mnts` array to support tracking multiple concurrent mount points
- Per-drive work extracted into a `process_drive()` function
- Cosmetic `sleep 1` before Ventoy installation removed
### Fixed
- `install.sh` was using `cat` to read the marker file, causing the version comparison to fail whenever a summon command was stored on line 2; fixed to use `sed -n '1p'` consistently
- Removed redundant `disk_is_known()` from `lib/disk.sh`; `disk_exists()` is a strict superset and the two checks were always evaluated together

---

## [0.2.0] - 2026-04-12
### Added
- `SUMMON_COMMAND` variable in `defaults.conf` to customise the global command name without editing scripts
- `APP_NAME` variable in `defaults.conf` to decouple the internal system path from the summon command
- `--update` flag to trigger re-setup without manually deleting the marker file
- `--help` flag with usage summary and dependency list
- `install.sh` copies itself to `/usr/local/share/$APP_NAME/` so `--update` can invoke it from the system path
- Signal trap cleans up mount points on interrupt
- System disk guard: script refuses to format the disk hosting the root filesystem
- Input validation against `lsblk` before any disk is touched
- Early abort if no `.iso` files are found in `$ISO_SRC` before any formatting begins
- Disk space check against total ISO size before copying
- SHA-256 checksum verification on Ventoy download
- Post-copy integrity check via `rsync --checksum`
- `[n/total]` progress counter across drives
- All output logged to `/var/log/ventoyfleet.log` via `tee`
### Changed
- Marker file now stores Ventoy version and active summon command, enabling clean rename detection on `--update`
- Old summon command binary removed from `/usr/local/bin/` when `SUMMON_COMMAND` changes between installs
- Per-device confirmation replaced with a single upfront prompt listing all selected devices with model and size, allowing the process to run unattended after one confirmation
- All user-facing output routed through `lib/ui.sh` helper functions in preparation for a Zenity GUI layer
- Support files installed to `/usr/local/share/$APP_NAME/`, main script to `/usr/local/bin/$SUMMON_COMMAND`
### Fixed
- Marker version check was comparing full file contents against version string. It now reads line 1 only via `sed -n '1p'`
- `MARKER_FILE` was resolving to `/root/.local/share/...` under `sudo`. It now uses `/home/$REAL_USER` explicitly
- `REAL_USER` now falls back to `logname` before `$USER` to correctly identify the invoking user under `sudo`
- `sed` and `cat` calls in marker checks protected with `|| true` to prevent `set -euo pipefail` exiting silently
- Ventoy checksum URL corrected to `sha256.txt`. The previously assumed `.sha256` filename returned a 404
- Checksum verification now strips carriage returns via `tr -d '\r'` before piping to `sha256sum -c`
- Tar extraction was deleting the extracted directory instead of the `.tar.gz` archive
- `chmod -R 777` removed. rsync runs without relaxing partition permissions
- `ventoy_mnt` initialised before signal trap to prevent unbound variable errors on early interrupt

---

## [0.1.0] - 2026-04-11
### Added
- A proper release on the project's [Github page](https://github.com/alnk-n/BatchVentoyDeployer)
- Automatic first-run setup: installs curl, Zenity, and downloads Ventoy2Disk
- Automatically copies ISOs  from `~/ISOs` to all selected drives after formatting
- Basic disk listing and text-prompt drive selection
- Proper file structure (config and lib folders, initial install script and a changelog).

---