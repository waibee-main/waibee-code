# Waibee Code

Fast, terminal-first AI coding agent. Multi-session TUI, shell-aware
permissions, MCP, skills, hooks, and plugins.

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

Waibee keeps itself up to date automatically - it checks on startup and installs
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

## Use in your editor (ACP)

Waibee speaks the [Agent Client Protocol](https://agentclientprotocol.com/), so
it runs inside any ACP editor as `waibee acp`. On first run, editors that support
it open a prompt to paste your API key; otherwise run `waibee config set-api-key`.

### Zed

1. Run `agent: open settings` → **Add Agent** → **Add Custom Agent** (this opens
   `~/.config/zed/settings.json`).
2. Add the entry:

   ```json
   {
     "agent_servers": {
       "Waibee Code": {
         "type": "custom",
         "command": "waibee",
         "args": ["acp"]
       }
     }
   }
   ```

3. Open the agent panel and pick **Waibee Code**.

### JetBrains IDEs (AI Assistant 2026.1+)

1. Open the **AI Chat** tool window.
2. Click the **⋮** menu (top-right) → **Add Custom Agent** (this opens
   `~/.jetbrains/acp.json`).
3. Add the same entry as Zed:

   ```json
   {
     "agent_servers": {
       "Waibee Code": {
         "type": "custom",
         "command": "waibee",
         "args": ["acp"]
       }
     }
   }
   ```

   If the IDE can't find `waibee`, replace `"command"` with the full path:
   `~/.local/bin/waibee` (macOS/Linux) or
   `%LOCALAPPDATA%\Programs\waibee\waibee.exe` (Windows).
4. Save; **Waibee Code** appears in AI Chat. Restart the IDE if it does not.

## Issues & feedback

Found a bug or have a feature request? Open an issue here — the
[bug](./.github/ISSUE_TEMPLATE/bug_report.md) and
[feature](./.github/ISSUE_TEMPLATE/feature_request.md) templates guide you.
