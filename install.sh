#!/usr/bin/env bash
set -euo pipefail

VERSION="1.0.0"
REPO_URL="https://github.com/nickforshee/m3u8.git"
RELEASE_API="https://api.github.com/repos/homebridge/ffmpeg-for-homebridge/releases/latest"
TEMP_DIR=""
SOURCE_DIR=""

info(){ printf '\033[0;34m[INFO]\033[0m %s\n' "$*"; }
step(){ printf '\n\033[1;36m==> Step %s: %s\033[0m\n' "$1" "$2"; }
action(){ printf '\033[1;35m[ACTION REQUIRED]\033[0m %s\n' "$*" >/dev/tty 2>/dev/null || true; }
success(){ printf '\033[0;32m[SUCCESS]\033[0m %s\n' "$*"; }
warn(){ printf '\033[1;33m[WARNING]\033[0m %s\n' "$*"; }
fail(){ printf '\033[0;31m[ERROR]\033[0m %s\n' "$*" >&2; exit 1; }
cleanup(){ [[ -n "$TEMP_DIR" && -d "$TEMP_DIR" ]] && rm -rf "$TEMP_DIR"; }
trap cleanup EXIT
expand_path(){ case "$1" in "~") printf '%s\n' "$HOME";; "~/"*) printf '%s/%s\n' "$HOME" "${1:2}";; *) printf '%s\n' "$1";; esac; }
prompt(){ local label="$1" default="${2:-}" answer=""; if [[ -r /dev/tty ]]; then action "Please respond below. Press Enter to accept the default."; if [[ -n "$default" ]]; then printf '  %s [%s]: ' "$label" "$default" >/dev/tty; else printf '  %s: ' "$label" >/dev/tty; fi; IFS= read -r answer </dev/tty || true; fi; printf '%s\n' "${answer:-$default}"; }
yesno(){ local label="$1" default="${2:-Y}" answer; answer="$(prompt "$label" "$default")"; [[ "$answer" =~ ^[Yy] ]]; }
script_dir(){ cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd; }

find_source(){ local d; d="$(script_dir || true)"; if [[ -f "$d/m3u8" ]]; then SOURCE_DIR="$d"; return; fi; command -v git >/dev/null || fail "git is required for piped installation."; TEMP_DIR="$(mktemp -d)"; git clone --depth 1 "$REPO_URL" "$TEMP_DIR/source" >/dev/null; SOURCE_DIR="$TEMP_DIR/source"; }
platform_key(){ case "$(uname -s):$(uname -m)" in Darwin:arm64|Darwin:aarch64) echo darwin-arm64;; Darwin:x86_64|Darwin:amd64) echo darwin-x86_64;; Linux:x86_64|Linux:amd64) echo linux-x86_64;; Linux:aarch64|Linux:arm64) echo linux-aarch64;; *) fail "Unsupported platform: $(uname -s) $(uname -m)";; esac; }
asset_name(){ echo "ffmpeg-$(platform_key).tar.gz"; }
asset_url(){ echo "https://github.com/homebridge/ffmpeg-for-homebridge/releases/latest/download/$(asset_name)"; }
linux_asset_url(){ case "$(uname -m)" in x86_64|amd64) echo "https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-linux64-gpl.tar.xz";; aarch64|arm64) echo "https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-linuxarm64-gpl.tar.xz";; *) fail "Unsupported Linux architecture: $(uname -m)";; esac; }
sha256_file(){ if command -v shasum >/dev/null; then shasum -a 256 "$1" | awk '{print $1}'; elif command -v sha256sum >/dev/null; then sha256sum "$1" | awk '{print $1}'; else return 1; fi; }
release_digest(){
  command -v curl >/dev/null || return 1
  local name json segment
  name="$(asset_name)"; json="$(curl -fsSL --retry 3 "$RELEASE_API" 2>/dev/null || true)"; [[ -n "$json" ]] || return 1
  segment="$(printf '%s' "$json" | tr '\n' ' ' | sed 's/},/}\n/g' | grep -F "\"name\": \"$name\"" | head -n1 || true)"
  printf '%s' "$segment" | sed -nE 's/.*"digest": "sha256:([a-fA-F0-9]{64})".*/\1/p'
}
verify_archive(){ local archive="$1" expected actual; expected="${M3U8_FFMPEG_SHA256:-$(release_digest || true)}"; if [[ -z "$expected" ]]; then warn "No published SHA-256 digest was available; TLS download validation still applies."; return; fi; actual="$(sha256_file "$archive" || true)"; [[ -n "$actual" ]] || fail "No SHA-256 utility is available."; [[ "$actual" == "$expected" ]] || fail "FFmpeg checksum verification failed."; success "Verified FFmpeg SHA-256 checksum."; }
try_pkg_manager(){ if command -v apt-get >/dev/null 2>&1; then info "Installing FFmpeg via apt-get..."; sudo apt-get install -y ffmpeg >/dev/null 2>&1 && { FFMPEG_PATH="$(command -v ffmpeg)"; return 0; }; elif command -v dnf >/dev/null 2>&1; then info "Installing FFmpeg via dnf..."; sudo dnf install -y ffmpeg >/dev/null 2>&1 && { FFMPEG_PATH="$(command -v ffmpeg)"; return 0; }; elif command -v yum >/dev/null 2>&1; then info "Installing FFmpeg via yum..."; sudo yum install -y ffmpeg >/dev/null 2>&1 && { FFMPEG_PATH="$(command -v ffmpeg)"; return 0; }; elif command -v pacman >/dev/null 2>&1; then info "Installing FFmpeg via pacman..."; sudo pacman -S --noconfirm ffmpeg >/dev/null 2>&1 && { FFMPEG_PATH="$(command -v ffmpeg)"; return 0; }; elif command -v zypper >/dev/null 2>&1; then info "Installing FFmpeg via zypper..."; sudo zypper install -y ffmpeg >/dev/null 2>&1 && { FFMPEG_PATH="$(command -v ffmpeg)"; return 0; }; fi; return 1; }

config_get(){ local file="$1" key="$2" line; [[ -r "$file" ]] || return 1; line="$(grep -E "^${key}=" "$file" | tail -n1 || true)"; [[ -n "$line" ]] || return 1; line="${line#*=}"; line="${line#\"}"; line="${line%\"}"; printf '%s\n' "$line"; }
write_config(){ cat >"$CONFIG_PATH" <<CFG
M3U8_INSTALL_VERSION="$VERSION"
M3U8_INSTALL_ROOT="$INSTALL_ROOT"
M3U8_OUTPUT_DIR="$DOWNLOAD_DIR"
M3U8_FFMPEG="$FFMPEG_PATH"
M3U8_SHELL_PROFILE="$SHELL_PROFILE"
M3U8_ALIAS="$COMMAND_ALIAS"
M3U8_ACCESS_MODE="$ACCESS_MODE"
CFG
chmod 600 "$CONFIG_PATH"; }

profile_candidates(){ case "${SHELL:-}" in */zsh) printf '%s\n' "$HOME/.zprofile" "$HOME/.zshrc";; */bash) [[ "$(uname -s)" == Darwin ]] && printf '%s\n' "$HOME/.bash_profile" "$HOME/.bashrc" "$HOME/.profile" || printf '%s\n' "$HOME/.bashrc" "$HOME/.profile" "$HOME/.bash_profile";; *) printf '%s\n' "$HOME/.profile" "$HOME/.zprofile" "$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.bash_profile";; esac; }
choose_profile(){
  [[ "$ACCESS_MODE" == path ]] || { SHELL_PROFILE=""; return; }
  if [[ -n "${M3U8_SHELL_PROFILE:-}" ]]; then SHELL_PROFILE="$(expand_path "$M3U8_SHELL_PROFILE")"; return; fi
  local arr=() p i default=1 answer; while IFS= read -r p; do arr+=("$p"); done < <(profile_candidates)
  for i in "${!arr[@]}"; do [[ -f "${arr[$i]}" ]] && { default=$((i+1)); break; }; done
  if [[ ! -r /dev/tty ]]; then SHELL_PROFILE="${arr[$((default-1))]}"; return; fi
  action 'Choose exactly one shell configuration file to modify.'
  printf '\nAvailable shell configuration files:\n' >/dev/tty
  for i in "${!arr[@]}"; do [[ -f "${arr[$i]}" ]] && p=exists || p='will be created'; printf '  %d) %s (%s)\n' "$((i+1))" "${arr[$i]}" "$p" >/dev/tty; done
  printf '  c) Custom path\n' >/dev/tty; answer="$(prompt 'Selection' "$default")"
  if [[ "$answer" =~ ^[Cc]$ ]]; then SHELL_PROFILE="$(expand_path "$(prompt 'Shell configuration file' "${arr[$((default-1))]}")")"; elif [[ "$answer" =~ ^[0-9]+$ ]] && ((answer>=1&&answer<=${#arr[@]})); then SHELL_PROFILE="${arr[$((answer-1))]}"; else fail "Invalid profile selection."; fi
}
remove_block(){ local file="$1" tmp; [[ -f "$file" ]] || return; tmp="$(mktemp)"; awk '$0=="# >>> m3u8 installer >>>"{s=1;next} s&&$0=="# <<< m3u8 installer <<<"{s=0;next} !s{print}' "$file" >"$tmp"; cat "$tmp">"$file"; rm -f "$tmp"; }
configure_shell(){ [[ "$ACCESS_MODE" == path ]] || return 0; mkdir -p "$(dirname "$SHELL_PROFILE")"; touch "$SHELL_PROFILE"; remove_block "$SHELL_PROFILE"; local bin target; bin="${BIN_DIR/#$HOME/\$HOME}"; target="${COMMAND_PATH/#$HOME/\$HOME}"; { echo; echo '# >>> m3u8 installer >>>'; printf 'export PATH="%s:$PATH"\n' "$bin"; [[ -n "$COMMAND_ALIAS" ]] && printf "alias %s='%s'\n" "$COMMAND_ALIAS" "$target"; echo '# <<< m3u8 installer <<<' ; } >>"$SHELL_PROFILE"; success "Updated $SHELL_PROFILE"; }
configure_symlink(){ [[ "$ACCESS_MODE" == symlink ]] || return 0; mkdir -p "$SYMLINK_DIR"; ln -sfn "$COMMAND_PATH" "$SYMLINK_DIR/m3u8"; [[ -n "$COMMAND_ALIAS" ]] && ln -sfn "$COMMAND_PATH" "$SYMLINK_DIR/$COMMAND_ALIAS"; success "Created command link(s) in $SYMLINK_DIR"; }

choose_access_mode(){
  local answer
  if [[ -n "${M3U8_ACCESS_MODE:-}" ]]; then ACCESS_MODE="$M3U8_ACCESS_MODE"; else
    action 'Choose how you want to run the command after installation.'
    printf '\nCommand access method:\n  1) Add the install bin directory to PATH\n  2) Create symlink(s) in ~/.local/bin\n  3) Do not configure shell access\n' >/dev/tty 2>/dev/null || true
    answer="$(prompt 'Selection' '1')"; case "$answer" in 1) ACCESS_MODE=path;; 2) ACCESS_MODE=symlink;; 3) ACCESS_MODE=none;; *) fail "Invalid access selection.";; esac
  fi
  SYMLINK_DIR="$(expand_path "${M3U8_SYMLINK_DIR:-$HOME/.local/bin}")"
}
choose_alias(){ [[ "$ACCESS_MODE" == none ]] && { COMMAND_ALIAS=""; return; }; if [[ -n "${M3U8_ALIAS+x}" ]]; then COMMAND_ALIAS="$M3U8_ALIAS"; else COMMAND_ALIAS="$(prompt 'Optional command alias (blank for none)' '')"; fi; [[ -z "$COMMAND_ALIAS" || "$COMMAND_ALIAS" =~ ^[A-Za-z_][A-Za-z0-9_-]*$ ]] || fail "Invalid alias."; }

install_ffmpeg(){
  local choice archive unpacked found system
  system="$(command -v ffmpeg || true)"
  if [[ -n "${M3U8_FFMPEG:-}" ]]; then FFMPEG_PATH="$(expand_path "$M3U8_FFMPEG")"; [[ -x "$FFMPEG_PATH" ]] || fail "Configured FFmpeg is not executable."; return; fi
  if [[ -n "$system" && -r /dev/tty ]]; then info "Found system FFmpeg at $system"; choice="$(prompt "Use system FFmpeg at $system? (Y/n)" 'Y')"; [[ "$choice" =~ ^[Yy] ]] && { FFMPEG_PATH="$system"; return; }; fi
  FFMPEG_PATH="$TOOLS_DIR/ffmpeg"
  if [[ -f "$SOURCE_DIR/ffmpeg" ]]; then cp "$SOURCE_DIR/ffmpeg" "$FFMPEG_PATH"; chmod 755 "$FFMPEG_PATH"; return; fi
  command -v curl >/dev/null || fail "curl is required."; command -v tar >/dev/null || fail "tar is required."
  [[ -n "$TEMP_DIR" ]] || TEMP_DIR="$(mktemp -d)"; unpacked="$TEMP_DIR/unpacked"
  if [[ "$(uname -s)" == Linux ]]; then
    info "Attempting FFmpeg installation via system package manager..."
    if try_pkg_manager; then success "FFmpeg installed via package manager at $FFMPEG_PATH"; return; fi
    warn "Package manager installation failed or unavailable; downloading static build..."
    command -v xz >/dev/null || fail "xz is required to extract the FFmpeg archive. Install it (e.g. apt-get install xz-utils) and retry."
    archive="$TEMP_DIR/ffmpeg.tar.xz"
    info "Downloading FFmpeg static build for Linux $(uname -m)..."; curl -fL --retry 3 --progress-bar "$(linux_asset_url)" -o "$archive"
    mkdir -p "$unpacked"; tar -xJf "$archive" -C "$unpacked"
  else
    archive="$TEMP_DIR/ffmpeg.tar.gz"; mkdir -p "$unpacked"
    info "Downloading FFmpeg for $(platform_key)..."
    if curl -fL --retry 3 --progress-bar "$(asset_url)" -o "$archive" 2>/dev/null; then
      verify_archive "$archive"; tar -xzf "$archive" -C "$unpacked"
    else
      warn "FFmpeg download failed; trying Homebrew..."
      command -v brew >/dev/null 2>&1 || fail "FFmpeg download failed and Homebrew is not available. Install FFmpeg manually and set M3U8_FFMPEG."
      info "Installing FFmpeg via Homebrew..."; brew install ffmpeg || fail "Homebrew FFmpeg installation failed. Install FFmpeg manually and set M3U8_FFMPEG."
      FFMPEG_PATH="$(command -v ffmpeg)"; success "FFmpeg installed via Homebrew at $FFMPEG_PATH"; return
    fi
  fi
  found="$(find "$unpacked" -type f -name ffmpeg -print -quit)"; [[ -n "$found" ]] || fail "Archive did not contain FFmpeg."; cp "$found" "$FFMPEG_PATH"; chmod 755 "$FFMPEG_PATH"
}

existing_action(){
  local existing="$1" answer
  [[ -d "$existing" ]] || { INSTALL_ACTION=fresh; return; }
  action 'An existing installation was found. Choose what to do next.'
  printf '\nExisting installation found at %s\n  1) Update program files and preserve configuration\n  2) Reconfigure installation\n  3) Reinstall everything\n  4) Cancel\n' "$existing" >/dev/tty 2>/dev/null || true
  answer="$(prompt 'Selection' '1')"; case "$answer" in 1) INSTALL_ACTION=update;; 2) INSTALL_ACTION=reconfigure;; 3) INSTALL_ACTION=reinstall;; 4) exit 0;; *) fail "Invalid selection.";; esac
}

main(){
  printf '\n\033[1mM3U8 Installer v%s\033[0m\n' "$VERSION"
  printf 'This installer will guide you through each setup choice.\n'
  step 1 'Locate installation source'
  info 'Preparing installer files...'
  find_source
  local parent old_config old_output old_profile old_alias old_mode
  step 2 'Choose installation location'
  parent="$(expand_path "${M3U8_INSTALL_PARENT:-$(prompt 'Install parent directory' '~')}")"; INSTALL_ROOT="$parent/m3u8"; info "Install directory will be $INSTALL_ROOT"; existing_action "$INSTALL_ROOT"
  old_config="$INSTALL_ROOT/config"
  step 3 'Choose download and command settings'
  if [[ "$INSTALL_ACTION" == update && -r "$old_config" ]]; then
    DOWNLOAD_DIR="$(config_get "$old_config" M3U8_OUTPUT_DIR || echo "$HOME/Downloads")"; SHELL_PROFILE="$(config_get "$old_config" M3U8_SHELL_PROFILE || true)"; COMMAND_ALIAS="$(config_get "$old_config" M3U8_ALIAS || true)"; ACCESS_MODE="$(config_get "$old_config" M3U8_ACCESS_MODE || echo path)"
  else
    DOWNLOAD_DIR="$(expand_path "${M3U8_OUTPUT_DIR:-$(prompt 'Default download directory' '~/Downloads')}")"; choose_access_mode; choose_profile; choose_alias
  fi
  info "Default downloads will go to $DOWNLOAD_DIR"
  step 4 'Install command files'
  BIN_DIR="$INSTALL_ROOT/bin"; TOOLS_DIR="$INSTALL_ROOT/tools"; CONFIG_PATH="$INSTALL_ROOT/config"; COMMAND_PATH="$BIN_DIR/m3u8"
  info 'Creating directories and copying scripts...'
  mkdir -p "$BIN_DIR" "$TOOLS_DIR" "$DOWNLOAD_DIR"; cp "$SOURCE_DIR/m3u8" "$COMMAND_PATH"; cp "$SOURCE_DIR/uninstall.sh" "$INSTALL_ROOT/uninstall.sh"; chmod 755 "$COMMAND_PATH" "$INSTALL_ROOT/uninstall.sh"
  step 5 'Configure FFmpeg'
  if [[ "$INSTALL_ACTION" == update && -x "$(config_get "$old_config" M3U8_FFMPEG 2>/dev/null || true)" ]]; then FFMPEG_PATH="$(config_get "$old_config" M3U8_FFMPEG)"; else install_ffmpeg; fi
  step 6 'Configure shell access'
  configure_shell; configure_symlink
  info 'Writing installation configuration...'
  write_config
  step 7 'Finish'
  success "m3u8 $VERSION installed at $INSTALL_ROOT"; echo "Run: $COMMAND_PATH --doctor"; [[ "$ACCESS_MODE" != none ]] && echo "Open a new terminal, then run: m3u8 --help"
}
main "$@"
