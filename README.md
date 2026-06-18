# Waibee Code

An AI coding agent for your terminal and your editor. It writes code, runs
commands, handles chores, and digs through a repo. Run several sessions at once.
It asks before touching your shell, and connects to MCP servers, skills, hooks,
and plugins.

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

> **macOS Gatekeeper:** the script sets no prompt, since curl downloads don't add
> the quarantine flag. If you download a binary by hand from the Releases page,
> run `xattr -d com.apple.quarantine "$(which waibee)"`.

## Update

Waibee updates itself. It checks on startup and installs new releases in the
background, so you don't have to.

## Uninstall

Waibee is a single binary. Just delete it. No network needed.

**macOS / Linux**

```bash
rm -f ~/.local/bin/waibee     # the binary (or wherever `which waibee` points)
rm -rf ~/.waibee              # settings, history, saved key (optional)
```

The installer also appends a line to your shell profile (`~/.zshrc`, `~/.bashrc`,
or `~/.profile`). Delete the `export PATH=...waibee...` line if you want.

**Windows (PowerShell)**

```powershell
Remove-Item "$env:LOCALAPPDATA\Programs\waibee" -Recurse -Force   # the binary
Remove-Item "$env:APPDATA\waibee"               -Recurse -Force   # data (optional)
```

Saved your key in the OS keychain? Remove the `waibee` entry too: Keychain Access
on macOS, Credential Manager on Windows.

Prefer the installer? It removes the binary for you:

```bash
curl -fsSL https://raw.githubusercontent.com/waibee-main/waibee-code/main/install.sh | bash -s -- --uninstall
```

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/waibee-main/waibee-code/main/install.ps1))) -Uninstall
```

## Changelog

Release notes for every version live on the
[Releases page](https://github.com/waibee-main/waibee-code/releases). The app also
shows a What's New summary after it updates.

## Getting started

```bash
waibee                      # interactive TUI
waibee run "fix the bug"    # headless one-shot, prints the result and exits
waibee --help               # all commands
```

## API key

Waibee needs an API key. Set it any of these ways, highest priority first:

1. **`WAIBEE_API_KEY` environment variable.** Overrides everything else. Good for
   CI, shared machines, or pasting the key into an editor's agent config.
2. **In the app.** Run `waibee` and paste the key when prompted, or run
   `waibee config set-api-key`. It saves to your OS keychain (or `~/.waibee/secrets.json`).

The environment variable always wins, so you can override a saved key for one
session without changing what's stored.

## Use in your editor (ACP)

Waibee speaks the [Agent Client Protocol](https://agentclientprotocol.com/), so it
runs in any ACP client as `waibee acp`, not just IDEs. Zed and JetBrains are set up
below; the same `waibee acp` works in Neovim, Obsidian, and the rest of the
[client list](https://agentclientprotocol.com/get-started/clients). Set your
[API key](#api-key) before you prompt.

### Zed

1. Run `agent: open settings` then **Add Agent** then **Add Custom Agent** (this
   opens `~/.config/zed/settings.json`).
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
4. **API key.** No key yet? Use the agent's **Reauthenticate** option (⋮ menu) and
   Zed opens a terminal where you paste it. You can also put it in the entry above
   with `"env": { "WAIBEE_API_KEY": "<your-key>" }`.

### JetBrains IDEs (AI Assistant 2026.1+)

1. Open the **AI Chat** tool window.
2. Click the **⋮** menu (top-right) then **Add Custom Agent** (this opens
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
4. Save. **Waibee Code** appears in AI Chat. Restart the IDE if it doesn't.
5. **API key.** JetBrains has no in-chat sign-in, so set the key first. Run
   `waibee` once (or `waibee config set-api-key`), or add it to the entry above:

   ```json
   {
     "agent_servers": {
       "Waibee Code": {
         "type": "custom",
         "command": "waibee",
         "args": ["acp"],
         "env": { "WAIBEE_API_KEY": "<your-key>" }
       }
     }
   }
   ```

### Other ACP clients

Every [ACP client](https://agentclientprotocol.com/get-started/clients) wires up
the same way: point it at the command `waibee` with the argument `acp`. That
covers Neovim, Obsidian, and more.

VS Code has no built-in ACP support, but the
[ACP extension](https://github.com/formulahendry/vscode-acp)
([setup guide](https://zed.dev/acp/editor/vscode)) adds it. Install the extension,
then set `waibee` with `acp` as the agent.

## Issues & feedback

Found a bug or have a feature request? Open an issue here. The
[bug](./.github/ISSUE_TEMPLATE/bug_report.md) and
[feature](./.github/ISSUE_TEMPLATE/feature_request.md) templates guide you.
