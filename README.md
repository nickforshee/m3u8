# m3u8

A self-contained Bash command for downloading authorized HLS (`.m3u8`) streams with FFmpeg on macOS and Linux.

## Highlights

- Native FFmpeg builds for Apple Silicon, Intel macOS, Linux x86-64, and Linux ARM64
- Interactive installer with update, reconfigure, and reinstall modes
- Use bundled FFmpeg, a system FFmpeg, or a custom executable
- PATH, symlink, or no-shell-modification installation modes
- Optional command alias
- Configurable output directory stored outside shell profiles
- Master-playlist quality selection
- URL argument, interactive URL prompt, and optional clipboard detection
- Output naming, collision protection, overwrite mode, audio-only mode, retries, cleanup, diagnostics, and validation

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/nickforshee/m3u8/main/install.sh | bash
```

Or manually:

```bash
git clone https://github.com/nickforshee/m3u8.git
cd m3u8
./install.sh
```

The installer asks for the install parent directory, download directory, command-access method, one shell profile when PATH mode is selected, and an optional alias. Existing installations offer update, reconfigure, reinstall, or cancel.

Default layout:

```text
~/m3u8/
├── bin/m3u8
├── tools/ffmpeg
├── config
└── uninstall.sh
```

Only the binary directory is added to PATH. Runtime settings remain in `config`, which is parsed as known key/value data rather than executed as shell code.

## Command access modes

1. Add `<install-root>/bin` to one selected shell profile.
2. Create `m3u8` and optional alias symlinks in `~/.local/bin`.
3. Make no shell changes and invoke the installed binary by full path.

The PATH block is explicitly marked so uninstalling removes only installer-managed lines.

## Usage

```bash
m3u8 "https://example.com/master.m3u8"
m3u8 download "https://example.com/master.m3u8"
m3u8 download URL -o movie.mp4
m3u8 download URL --output-dir ~/Videos
m3u8 download URL --overwrite
m3u8 download URL --audio-only
m3u8 info URL
m3u8 validate ~/Downloads/movie.mp4
m3u8 --configure
m3u8 --doctor
m3u8 --version
m3u8 --help
```

Running `m3u8` without a URL checks supported clipboard tools and then prompts interactively. For a master playlist, it lists available resolution/bitrate variants and asks which one to download.

Output filenames default to a sanitized name inferred from the URL. Missing extensions are added automatically. Existing files prompt for overwrite, automatic rename, or cancellation unless `--overwrite` is used.

## Reliability

Downloads use FFmpeg reconnect and timeout options. The command first attempts stream-copy remuxing and falls back to AAC audio conversion when necessary. Partial output is removed on failure, and temporary work data is cleaned on success, failure, Ctrl+C, or termination.

## Configuration

```bash
m3u8 --configure
```

This updates the default output directory and FFmpeg executable. One-command overrides are also supported:

```bash
M3U8_OUTPUT_DIR="$HOME/Desktop" m3u8 URL
M3U8_FFMPEG="/usr/local/bin/ffmpeg" m3u8 URL
```

## Diagnostics

```bash
m3u8 --doctor
```

Reports the version, install root, config status, platform, FFmpeg version/path, output-directory writability, shell profile, alias, and curl availability.

## FFmpeg integrity

The installer downloads FFmpeg over TLS and attempts to read the release asset's SHA-256 digest from GitHub's release API. When a digest is available, it verifies the archive before extraction. A checksum may also be forced explicitly:

```bash
M3U8_FFMPEG_SHA256="expected-64-character-sha256" ./install.sh
```

If the upstream release does not publish a digest, the installer prints a warning rather than claiming verification occurred.

## Non-interactive install settings

```bash
M3U8_INSTALL_PARENT="$HOME/.local" \
M3U8_OUTPUT_DIR="$HOME/Videos" \
M3U8_ACCESS_MODE="path" \
M3U8_SHELL_PROFILE="$HOME/.zprofile" \
M3U8_ALIAS="m8" \
./install.sh
```

Other useful values:

```bash
M3U8_ACCESS_MODE="symlink"
M3U8_ACCESS_MODE="none"
M3U8_SYMLINK_DIR="$HOME/.local/bin"
M3U8_FFMPEG="/custom/path/ffmpeg"
```

## Update

Re-run the installer. “Update program files” preserves the current config and FFmpeg selection. “Reconfigure” asks the installation questions again. “Reinstall” replaces everything.

## Uninstall

```bash
~/m3u8/uninstall.sh
~/m3u8/uninstall.sh --yes
~/m3u8/uninstall.sh --keep-files
```

The uninstaller removes only the marked shell block and symlinks that still point to this installation. It then optionally deletes the install directory.

## Requirements

- Bash
- macOS or Linux on a supported architecture
- `curl` and `tar` when downloading FFmpeg
- Git only when the installer needs to clone the repository
- Optional clipboard helpers: `pbpaste`, `wl-paste`, or `xclip`

## Legal note

Only download streams you are authorized to access and save. This utility does not bypass DRM.
