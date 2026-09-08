#!/usr/bin/env bash
#
# Portable bestie installer.
#
# Ships at the top level of a release archive, beside the bundle it installs:
#
#   <unzipped folder>/
#     install_portable.sh    <- this script
#     bin/bestie             <- the binary
#     lib/, ...              <- the rest of the bundle
#
# Run it from anywhere — it locates its own folder, so you can double-click
# or `bash /any/path/install_portable.sh`. It copies the bundle into
# ~/.local/lib/bestie, links it onto your PATH, and then you can delete the
# download.
set -euo pipefail

INSTALL_DIR="$HOME/.local/lib/bestie"
BIN_DIR="$HOME/.local/bin"
BIN_LINK="$BIN_DIR/bestie"

info() { printf '\033[1;34m%s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m%s\033[0m\n' "$*"; }
action() { printf '\033[1;32m%s\033[0m\n' "$*"; }
error() { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

# Resolve this script's own directory so we can be run from anywhere.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$SCRIPT_DIR"

[ -x "$SOURCE_DIR/bin/bestie" ] || error "Couldn't find bin/bestie next to this script. Run it from the unzipped download."

OS="$(uname -s)"

# Install (copy, don't move — the download stays intact and disposable).
info "Installing bestie to $INSTALL_DIR"
rm -rf "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR" "$BIN_DIR"
cp -R "$SOURCE_DIR"/* "$INSTALL_DIR"/
rm -f "$INSTALL_DIR/install_portable.sh"
chmod +x "$INSTALL_DIR/bin/bestie"
ln -sf "$INSTALL_DIR/bin/bestie" "$BIN_LINK"

# macOS: de-quarantine so Gatekeeper doesn't block launch.
if [ "$OS" = "Darwin" ]; then
  xattr -rd com.apple.quarantine "$INSTALL_DIR" 2>/dev/null || true
fi

# Ensure ~/.local/bin is on PATH.
REFRESH=""
MANUAL_PATH_LINE=""

if ! echo "$PATH" | tr ':' '\n' | grep -qx "$BIN_DIR"; then
  PROFILE=""
  if [ "${SHELL#*zsh}" != "${SHELL-}" ]; then
    PROFILE="${ZDOTDIR:-$HOME}/.zshrc"
  elif [ "${SHELL#*bash}" != "${SHELL-}" ]; then
    [ -f "$HOME/.bashrc" ] && PROFILE="$HOME/.bashrc" || PROFILE="$HOME/.bash_profile"
  elif [ "${SHELL#*fish}" != "${SHELL-}" ]; then
    PROFILE="$HOME/.config/fish/config.fish"
  fi

  if [ -z "$PROFILE" ]; then
    MANUAL_PATH_LINE='export PATH="$HOME/.local/bin:$PATH"'
  else
    case "$PROFILE" in
      *config.fish) SOURCE_LINE='set -gx PATH $HOME/.local/bin $PATH' ;;
      *)            SOURCE_LINE='export PATH="$HOME/.local/bin:$PATH"' ;;
    esac
    mkdir -p "$(dirname "$PROFILE")"
    touch "$PROFILE"
    printf '\n# added by bestie installer — https://github.com/jolexxa/bestie\n%s\n' "$SOURCE_LINE" >> "$PROFILE"
    info "Added ~/.local/bin to PATH in $PROFILE"
    REFRESH="source $PROFILE"
  fi
fi

# Done — the copy is complete, so the download is now disposable.
echo
action "────────────────────────────────────────────────"
action "  bestie has been copied to $BIN_LINK"
action "  You may now delete this download."
action "────────────────────────────────────────────────"

if [ -n "$REFRESH" ]; then
  echo
  action "  To use bestie in this shell right now, run:"
  action ""
  action "    $REFRESH"
elif [ -n "$MANUAL_PATH_LINE" ]; then
  echo
  warn "  Could not detect your shell. Add this line to your"
  warn "  shell config, then restart your shell:"
  warn ""
  warn "    $MANUAL_PATH_LINE"
else
  echo
  action "  You can now run: bestie"
fi
echo
