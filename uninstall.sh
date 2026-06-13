#!/usr/bin/env bash
set -euo pipefail
info(){ printf '\033[0;34m[INFO]\033[0m %s\n' "$*"; }
success(){ printf '\033[0;32m[SUCCESS]\033[0m %s\n' "$*"; }
warn(){ printf '\033[1;33m[WARNING]\033[0m %s\n' "$*"; }
fail(){ printf '\033[0;31m[ERROR]\033[0m %s\n' "$*" >&2; exit 1; }
usage(){ cat <<'TXT'
Usage: uninstall.sh [--yes] [--keep-files] [--help]
  --yes         Delete installed files without prompting
  --keep-files  Remove shell access but retain the installation
TXT
}
script_dir(){ cd "$(dirname "${BASH_SOURCE[0]}")" && pwd; }
config_get(){ local file="$1" key="$2" line; [[ -r "$file" ]] || return 1; line="$(grep -E "^${key}=" "$file" | tail -n1 || true)"; [[ -n "$line" ]] || return 1; line="${line#*=}"; line="${line#\"}"; line="${line%\"}"; printf '%s\n' "$line"; }
remove_block(){ local file="$1" tmp; [[ -f "$file" ]] || return 0; grep -Fq '# >>> m3u8 installer >>>' "$file" || return 0; tmp="$(mktemp)"; awk '$0=="# >>> m3u8 installer >>>"{s=1;next} s&&$0=="# <<< m3u8 installer <<<"{s=0;next} !s{print}' "$file" >"$tmp"; cat "$tmp">"$file"; rm -f "$tmp"; success "Removed shell configuration from $file"; }
remove_link_if_ours(){ local link="$1" expected="$2" target; [[ -L "$link" ]] || return 0; target="$(readlink "$link")"; [[ "$target" == "$expected" ]] && { rm -f "$link"; success "Removed $link"; }; }
confirm(){ [[ "$YES" == true ]] && return 0; [[ -r /dev/tty ]] || return 1; local a; printf 'Delete installation directory %s? [Y/n]: ' "$INSTALL_ROOT" >/dev/tty; IFS= read -r a </dev/tty || true; [[ "${a:-Y}" =~ ^[Yy] ]]; }

YES=false; KEEP=false
while (($#)); do case "$1" in --yes|-y) YES=true;; --keep-files) KEEP=true;; --help|-h) usage; exit 0;; *) fail "Unknown option: $1";; esac; shift; done
INSTALL_ROOT="$(script_dir)"; CONFIG="$INSTALL_ROOT/config"; COMMAND="$INSTALL_ROOT/bin/m3u8"
PROFILE="$(config_get "$CONFIG" M3U8_SHELL_PROFILE || true)"; ALIAS="$(config_get "$CONFIG" M3U8_ALIAS || true)"; MODE="$(config_get "$CONFIG" M3U8_ACCESS_MODE || echo path)"; SYMLINK_DIR="${M3U8_SYMLINK_DIR:-$HOME/.local/bin}"
if [[ -n "$PROFILE" ]]; then remove_block "$PROFILE"; else for p in "$HOME/.zprofile" "$HOME/.zshrc" "$HOME/.bash_profile" "$HOME/.bashrc" "$HOME/.profile"; do remove_block "$p"; done; fi
remove_link_if_ours "$SYMLINK_DIR/m3u8" "$COMMAND"; [[ -n "$ALIAS" ]] && remove_link_if_ours "$SYMLINK_DIR/$ALIAS" "$COMMAND"
if [[ "$KEEP" == true ]]; then success "Shell access removed; files retained at $INSTALL_ROOT"; exit 0; fi
if confirm; then cd "$HOME"; rm -rf "$INSTALL_ROOT"; success "Removed $INSTALL_ROOT"; else warn "Installed files were retained."; fi
printf 'Open a new terminal or reload your shell profile.\n'
