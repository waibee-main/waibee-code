# Waibee Code

Fast, terminal-first AI coding agent, written in Rust. Multi-session TUI, shell-aware
permissions, MCP, skills, hooks, and plugins.

This is the public distribution repo: it hosts the release binaries, the install
scripts, and the auto-update manifest. The source lives in a separate private repo.

## Install

**macOS / Linux**

```bash
curl -fsSL https://raw.githubusercontent.com/waibee-main/waibee-code/main/install.sh | bash
```

**Windows (PowerShell)**

```powershell
irm https://raw.githubusercontent.com/waibee-main/waibee-code/main/install.ps1 | iex
```

The installer downloads the right binary for your platform from the latest
[release](https://github.com/waibee-main/waibee-code/releases), verifies its
checksum, and installs it to `~/.local/bin` (`%LOCALAPPDATA%\Programs\waibee` on
Windows). Pin a version with `WAIBEE_VERSION=vX.Y.Z`.

> **macOS Gatekeeper:** when installed via the script there's no prompt (curl
> downloads don't set the quarantine flag). If you download a binary manually
> from the Releases page instead, run `xattr -d com.apple.quarantine "$(which waibee)"`.

## Update

Waibee keeps itself up to date automatically — it checks on startup and installs
new releases in the background. No action needed.

## Changelog

Release notes for every version are on the
[Releases page](https://github.com/waibee-main/waibee-code/releases). The app also
shows a "What's New" summary after it updates.

## Getting started

```bash
waibee                      # interactive TUI
waibee run "fix the bug"    # headless one-shot — prints the result and exits
waibee --help               # all commands
```

## License

Proprietary — see [LICENSE](./LICENSE) (End User License Agreement). Waibee Code is
closed-source; the binaries are provided for use under the EULA (no redistribution,
reverse engineering, or modification). Bundled third-party open-source components
retain their own licenses, credited with each release.

## Issues & feedback

Found a bug or have a feature request? Open an issue here — the
[bug](./.github/ISSUE_TEMPLATE/bug_report.md) and
[feature](./.github/ISSUE_TEMPLATE/feature_request.md) templates guide you. (The
source repo is private; user issues live here.)
