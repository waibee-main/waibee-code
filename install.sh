#!/usr/bin/env bash
# install.sh — Install waibee from GitHub Releases (waibee-main/waibee-code).
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/waibee-main/waibee-code/main/install.sh | bash
#   WAIBEE_VERSION=v1.2.3 bash install.sh   # pin a specific version
#   bash install.sh --uninstall             # remove the binary
#
# Install directory (in order of precedence):
#   $WAIBEE_INSTALL_DIR  >  $XDG_BIN_HOME  >  $HOME/.local/bin
set -euo pipefail

REPO="waibee-main/waibee-code"
BINARY="waibee"

# ── helpers ────────────────────────────────────────────────────────────────────

say()  { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mWARN\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31mERROR\033[0m %s\n' "$*" >&2; exit 1; }

need() {
    command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

# ── parse flags ────────────────────────────────────────────────────────────────

UNINSTALL=false
for arg in "$@"; do
    case "$arg" in
        --uninstall) UNINSTALL=true ;;
        *) die "Unknown argument: $arg" ;;
    esac
done

# ── detect platform ────────────────────────────────────────────────────────────

OS="$(uname -s)"
ARCH="$(uname -m)"

case "$OS" in
    Darwin) OS_PART="apple-darwin" ;;
    Linux)  OS_PART="unknown-linux-gnu" ;;
    *)      die "Unsupported operating system: $OS" ;;
esac

case "$ARCH" in
    x86_64 | amd64)        ARCH_PART="x86_64" ;;
    aarch64 | arm64)       ARCH_PART="aarch64" ;;
    *)                     die "Unsupported architecture: $ARCH" ;;
esac

TARGET="${ARCH_PART}-${OS_PART}"

# ── install directory ──────────────────────────────────────────────────────────

INSTALL_DIR="${WAIBEE_INSTALL_DIR:-${XDG_BIN_HOME:-$HOME/.local/bin}}"

# ── uninstall path ─────────────────────────────────────────────────────────────

if [[ "$UNINSTALL" == true ]]; then
    BIN_PATH="$INSTALL_DIR/$BINARY"
    if [[ -f "$BIN_PATH" ]]; then
        rm -f "$BIN_PATH"
        say "Removed $BIN_PATH"
        say "Note: configuration and data files are NOT removed."
        say "They typically live in \$HOME/.config/waibee or \$HOME/.local/share/waibee."
    else
        warn "Binary not found at $BIN_PATH — nothing to remove."
    fi
    exit 0
fi

# ── resolve version ────────────────────────────────────────────────────────────

need curl

if [[ -n "${WAIBEE_VERSION:-}" ]]; then
    VERSION="$WAIBEE_VERSION"
    say "Using pinned version: $VERSION"
else
    say "Resolving latest release..."
    VERSION="$(
        curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" \
            | grep '"tag_name"' \
            | head -1 \
            | cut -d'"' -f4
    )"
    [[ -n "$VERSION" ]] || die "Could not resolve latest release tag from GitHub API."
    say "Latest version: $VERSION"
fi

# Strip leading 'v' for the archive filename (version in filenames is bare, e.g. 1.2.3)
VERSION_BARE="${VERSION#v}"

ARCHIVE="waibee-${VERSION_BARE}-${TARGET}.tar.gz"
BASE_URL="https://github.com/${REPO}/releases/download/${VERSION}"
ARCHIVE_URL="${BASE_URL}/${ARCHIVE}"
SHA256_URL="${ARCHIVE_URL}.sha256"

# ── temp workspace ─────────────────────────────────────────────────────────────

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

# ── download ───────────────────────────────────────────────────────────────────

say "Downloading $ARCHIVE..."
if ! curl -fSL --progress-bar -o "$WORKDIR/$ARCHIVE" "$ARCHIVE_URL"; then
    die "No prebuilt binary for '$TARGET' in $VERSION.
  Your platform may not be supported yet. See https://github.com/$REPO/releases"
fi

# Download sha256 sidecar (best-effort — release may not have it yet)
SHA256_AVAILABLE=false
if curl -fsSL -o "$WORKDIR/$ARCHIVE.sha256" "$SHA256_URL" 2>/dev/null; then
    SHA256_AVAILABLE=true
fi

# ── checksum verification ──────────────────────────────────────────────────────

if [[ "$SHA256_AVAILABLE" == true ]]; then
    say "Verifying checksum..."
    EXPECTED="$(awk '{print $1}' "$WORKDIR/$ARCHIVE.sha256")"
    if command -v sha256sum >/dev/null 2>&1; then
        ACTUAL="$(sha256sum "$WORKDIR/$ARCHIVE" | awk '{print $1}')"
    elif command -v shasum >/dev/null 2>&1; then
        ACTUAL="$(shasum -a 256 "$WORKDIR/$ARCHIVE" | awk '{print $1}')"
    else
        warn "sha256sum and shasum not found — skipping checksum verification."
        ACTUAL="$EXPECTED"
    fi
    [[ "$ACTUAL" == "$EXPECTED" ]] \
        || die "Checksum mismatch!\n  expected: $EXPECTED\n  actual:   $ACTUAL"
    say "Checksum OK."
else
    warn "No .sha256 sidecar found — skipping checksum verification."
fi

# ── extract ────────────────────────────────────────────────────────────────────

say "Extracting..."
tar xzf "$WORKDIR/$ARCHIVE" -C "$WORKDIR"

# The archive contains a directory: waibee-<version>-<target>/waibee
STAGING_DIR="$WORKDIR/waibee-${VERSION_BARE}-${TARGET}"
BIN_SRC="$STAGING_DIR/$BINARY"
[[ -f "$BIN_SRC" ]] || die "Binary not found inside archive at $BIN_SRC"

# ── install ────────────────────────────────────────────────────────────────────

mkdir -p "$INSTALL_DIR"
cp "$BIN_SRC" "$INSTALL_DIR/$BINARY"
chmod 755 "$INSTALL_DIR/$BINARY"

# macOS: strip quarantine attribute (ignore errors — non-fatal)
if [[ "$OS" == "Darwin" ]]; then
    xattr -d com.apple.quarantine "$INSTALL_DIR/$BINARY" 2>/dev/null || true
fi

say "Installed $BINARY $VERSION to $INSTALL_DIR/$BINARY"

# ── PATH hint ──────────────────────────────────────────────────────────────────

case ":${PATH}:" in
    *":$INSTALL_DIR:"*) ;;
    *)
        warn "$INSTALL_DIR is not in your PATH."
        warn "Add the following to your shell profile (~/.bashrc, ~/.zshrc, etc.):"
        warn ""
        warn "  export PATH=\"\$PATH:$INSTALL_DIR\""
        warn ""
        ;;
esac

# ── next steps ─────────────────────────────────────────────────────────────────

say "Next step: configure your API key"
say ""
say "  waibee config set-api-key"
say ""
say "Or just run \`waibee\` — it walks you through setup on first launch."
say ""
