#!/usr/bin/env bash
set -euo pipefail

REPO="jolexxa/bestie"
INSTALL_DIR="$HOME/.local/lib/bestie"
BIN_DIR="$HOME/.local/bin"
BIN_LINK="$BIN_DIR/bestie"

info() { printf '\033[1;34m%s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m%s\033[0m\n' "$*"; }
action() { printf '\033[1;32m%s\033[0m\n' "$*"; }
error() { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

# Detect platform 
OS="$(uname -s)"
ARCH="$(uname -m)"

case "$OS" in
  Darwin)
    case "$ARCH" in
      arm64) PLATFORM="macos_arm64"; EXT="zip" ;;
      *) error "Unsupported macOS architecture: $ARCH (only Apple Silicon is supported)" ;;
    esac
    ;;
  Linux)
    case "$ARCH" in
      x86_64) PLATFORM="linux_x64"; EXT="tar.gz" ;;
      *) error "Unsupported Linux architecture: $ARCH (only x64 is supported)" ;;
    esac
    ;;
  *) error "Unsupported OS: $OS" ;;
esac

info "Detected platform: $PLATFORM"

# Download latest release 
URL="https://github.com/$REPO/releases/latest/download/bestie-${PLATFORM}.${EXT}"
TMPDIR="$(mktemp -d)"
ARCHIVE="$TMPDIR/bestie.$EXT"

cleanup() { rm -rf "$TMPDIR"; }
trap cleanup EXIT

info "Downloading $URL"
curl -fSL "$URL" -o "$ARCHIVE"

# Extract 
info "Extracting archive"
EXTRACT_DIR="$TMPDIR/bestie"
mkdir -p "$EXTRACT_DIR"

if [ "$EXT" = "zip" ]; then
  unzip -qo "$ARCHIVE" -d "$EXTRACT_DIR"
else
  tar -xzf "$ARCHIVE" -C "$EXTRACT_DIR"
fi

# Install 
info "Installing to $INSTALL_DIR"
rm -rf "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR" "$BIN_DIR"
cp -R "$EXTRACT_DIR"/* "$INSTALL_DIR"/
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
  # Detect the user's profile file based on $SHELL.
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

# Done
info ""
info "Installed bestie to $BIN_LINK"

# Prominent call-to-action if the user needs to refresh their shell.
if [ -n "$REFRESH" ]; then
  echo
  action "────────────────────────────────────────────────"
  action "  Please run the command below to use bestie now:"
  action ""
  action "    $REFRESH"
  action "────────────────────────────────────────────────"
  echo
elif [ -n "$MANUAL_PATH_LINE" ]; then
  echo
  warn "────────────────────────────────────────────────"
  warn "  Could not detect your shell. Add this line to"
  warn "  your shell config, then restart your shell:"
  warn ""
  warn "    $MANUAL_PATH_LINE"
  warn "────────────────────────────────────────────────"
  echo
else
  echo
  action "────────────────────────────────────────────────"
  action "  You can now run: bestie"
  action "────────────────────────────────────────────────"
  echo
fi
