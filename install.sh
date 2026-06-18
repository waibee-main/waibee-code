#!/usr/bin/env bash
# install.sh — install waibee from GitHub Releases.
#
#   curl -fsSL https://raw.githubusercontent.com/waibee-main/waibee-code/main/install.sh | bash
#   WAIBEE_VERSION=v1.2.3 bash install.sh   # pin a version
#   bash install.sh --uninstall             # remove the binary
#
# Install dir precedence: $WAIBEE_INSTALL_DIR > $XDG_BIN_HOME > $HOME/.local/bin

# Must run under bash (pipefail / [[ ]] below). Guard before `set` so `| sh` fails clean.
[ -n "${BASH_VERSION:-}" ] || { echo "This installer needs bash:  curl -fsSL <url> | bash" >&2; exit 1; }
set -euo pipefail

REPO="waibee-main/waibee-code"
BINARY="waibee"

say()  { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mWARN\033[0m %b\n' "$*" >&2; }
die()  { printf '\033[1;31mERROR\033[0m %b\n' "$*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"; }

UNINSTALL=false
for arg in "$@"; do
    case "$arg" in
        --uninstall) UNINSTALL=true ;;
        *) die "Unknown argument: $arg" ;;
    esac
done

OS="$(uname -s)"
ARCH="$(uname -m)"

case "$OS" in
    Darwin) OS_PART="apple-darwin" ;;
    Linux)
        OS_PART="unknown-linux-gnu"
        # We publish glibc binaries only; a musl host would fail cryptically at runtime.
        if command -v ldd >/dev/null 2>&1 && ldd --version 2>&1 | grep -qi musl; then
            die "musl libc detected (Alpine?). Only glibc binaries are published — build from source or use a glibc-based image."
        fi
        ;;
    *)  die "Unsupported operating system: $OS" ;;
esac

case "$ARCH" in
    x86_64 | amd64)   ARCH_PART="x86_64" ;;
    aarch64 | arm64)  ARCH_PART="aarch64" ;;
    *)                die "Unsupported architecture: $ARCH" ;;
esac

TARGET="${ARCH_PART}-${OS_PART}"
INSTALL_DIR="${WAIBEE_INSTALL_DIR:-${XDG_BIN_HOME:-$HOME/.local/bin}}"

if [[ "$UNINSTALL" == true ]]; then
    BIN_PATH="$INSTALL_DIR/$BINARY"
    if [[ -f "$BIN_PATH" ]]; then
        rm -f "$BIN_PATH"
        say "Removed $BIN_PATH"
        say "Note: settings, history, and your saved key in \$HOME/.waibee are NOT removed."
    else
        warn "Binary not found at $BIN_PATH — nothing to remove."
    fi
    exit 0
fi

need curl
need tar

if [[ -n "${WAIBEE_VERSION:-}" ]]; then
    VERSION="$WAIBEE_VERSION"
    say "Using pinned version: $VERSION"
else
    say "Resolving latest release..."
    # Separate the request from parsing: under `set -e`+`pipefail` a rate-limit
    # body (no tag_name) would otherwise abort the script with no message.
    API_JSON="$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest")" \
        || die "GitHub API request failed (network, or rate-limited — retry later or set WAIBEE_VERSION=vX.Y.Z)."
    VERSION="$(printf '%s\n' "$API_JSON" | grep '"tag_name"' | head -n1 | cut -d'"' -f4 || true)"
    [[ -n "$VERSION" ]] || die "Could not parse the latest release tag from the GitHub API."
    say "Latest version: $VERSION"
fi

VERSION_BARE="${VERSION#v}"
ARCHIVE="waibee-${VERSION_BARE}-${TARGET}.tar.gz"
BASE_URL="https://github.com/${REPO}/releases/download/${VERSION}"

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

say "Downloading $ARCHIVE..."
PROGRESS="-s"; [ -t 2 ] && PROGRESS="--progress-bar"
if ! curl -fSL "$PROGRESS" -o "$WORKDIR/$ARCHIVE" "${BASE_URL}/${ARCHIVE}"; then
    die "No prebuilt binary for '$TARGET' in $VERSION.\n  Your platform may not be supported yet — see https://github.com/$REPO/releases"
fi

if curl -fsSL -o "$WORKDIR/$ARCHIVE.sha256" "${BASE_URL}/${ARCHIVE}.sha256" 2>/dev/null; then
    say "Verifying checksum..."
    HASH_CMD=""
    if command -v sha256sum >/dev/null 2>&1; then HASH_CMD="sha256sum"
    elif command -v shasum >/dev/null 2>&1; then HASH_CMD="shasum -a 256"; fi
    if [[ -n "$HASH_CMD" ]]; then
        EXPECTED="$(awk '{print $1}' "$WORKDIR/$ARCHIVE.sha256")"
        ACTUAL="$($HASH_CMD "$WORKDIR/$ARCHIVE" | awk '{print $1}')"
        [[ "$ACTUAL" == "$EXPECTED" ]] || die "Checksum mismatch!\n  expected: $EXPECTED\n  actual:   $ACTUAL"
        say "Checksum OK."
    else
        warn "No sha256sum or shasum found — cannot verify integrity (skipping)."
    fi
else
    warn "No .sha256 sidecar found — skipping checksum verification."
fi

say "Extracting..."
tar xzf "$WORKDIR/$ARCHIVE" -C "$WORKDIR"

# Locate the binary anywhere in the archive — don't assume the wrapping dir name.
BIN_SRC="$(find "$WORKDIR" -type f -name "$BINARY" | head -n1)"
[[ -n "$BIN_SRC" && -f "$BIN_SRC" ]] || die "Binary '$BINARY' not found inside the archive."

mkdir -p "$INSTALL_DIR"
cp "$BIN_SRC" "$INSTALL_DIR/$BINARY"
chmod 755 "$INSTALL_DIR/$BINARY"

if [[ "$OS" == "Darwin" ]]; then
    xattr -d com.apple.quarantine "$INSTALL_DIR/$BINARY" 2>/dev/null || true
fi

say "Installed $BINARY $VERSION to $INSTALL_DIR/$BINARY"

# Put waibee on PATH by appending an export to the shell's rc file. A `curl | bash`
# subshell can't change the parent's PATH, so this takes effect in new terminals.
# Opt out with WAIBEE_NO_MODIFY_PATH to manage PATH yourself.
EXPORT_LINE="export PATH=\"\$PATH:$INSTALL_DIR\""
case ":${PATH}:" in
    *":$INSTALL_DIR:"*) ON_PATH=true ;;
    *)                  ON_PATH=false ;;
esac
if [[ "$ON_PATH" == false ]]; then
    case "${SHELL##*/}" in
        zsh)  PROFILE="$HOME/.zshrc" ;;
        bash) PROFILE="$HOME/.bashrc" ;;
        *)    PROFILE="$HOME/.profile" ;;
    esac
    if [[ -n "${WAIBEE_NO_MODIFY_PATH:-}" ]]; then
        warn "$INSTALL_DIR is not in your PATH. Add to $PROFILE:"
        warn "  $EXPORT_LINE"
    elif grep -qsF "$INSTALL_DIR" "$PROFILE"; then
        say "Restart your terminal (or 'source $PROFILE') to use \`waibee\`."
    else
        printf '\n%s\n' "$EXPORT_LINE" >> "$PROFILE"
        say "Added $INSTALL_DIR to PATH in $PROFILE."
        say "Restart your terminal (or 'source $PROFILE') to use \`waibee\`."
    fi
fi

say ""
say "Next: configure your API key →  waibee config set-api-key"
say "Or just run \`waibee\` — it walks you through setup on first launch."
