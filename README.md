# Remmina Hub

An [Omarchy](https://omarchy.org) plugin for the Quattro bar — manage **RDP, SSH, VNC & SPICE** remotes in one place. Import from CSV/TXT, from your existing `~/.ssh/config` and `~/.local/share/remmina/*.remmina`, group & filter, launch with the right tool, and keep the broken Remmina tray icon disabled.

![Remmina Hub panel](preview.png)

## Features

- **Unified hub** — RDP, SSH, VNC, SPICE (and SFTP/HTTP) in a single panel. No passwords stored.
- **Groups + collapsible sections** — e.g. `Windows`, `Linux`, `INFRA`, `Prod`. Each section collapses/expands; `Expand`/`Collapse` all.
- **Counters** — circular gauges: Windows (RDP), Linux (SSH/VNC/SPICE), Total.
- **Search filter** — live filter on name / host / protocol / group / username / notes.
- **Add / Edit / Delete** — `＋ Add Server` form (name*, host*, protocol, port, username, group, notes) + per-row edit/delete with confirmation.
- **Launch stacked right** — per-row glyph: `` SSH → terminal, `` RDP → freerdp/remmina, `󰢹` VNC, `󰹑` SPICE. Uses `xdg-terminal-exec` for SSH so your Omarchy default terminal (Alacritty / Foot / Ghostty / Kitty) is honored.
- **Import**
  - **CSV** — header `name,host,protocol,port,username,group,notes` (e.g. `srv01,host.example.com,RDP,3389,admin,Windows,prod`). Via `zenity` file picker.
  - **TXT** — one per line `name;host;protocol;port;username;group` (`;` `,` `|` or tab).
  - **SSH config** — `Import ~/.ssh/config` parses `Host`/`HostName`/`User`/`Port` (wildcards ignored). Pre-filled group `Linux`.
  - **Remmina** — `Import Remmina files` reads `~/.local/share/remmina/*.remmina` (`name`, `server`, `protocol`, `username`, `group`).
  - Imports are idempotent by `(name, host)` — re-importing skips duplicates.
- **Remmina tray icon disabled** — on load and on every launch the plugin patches `~/.config/remmina/remmina.pref` to `disable_tray_icon=true` (the Remmina tray breaks on Omarchy/Hyprland).
- **Storage** — `~/.config/remmina-panel/servers.json` (mode `600`), no secrets in repo.

## Installation

```bash
omarchy plugin add https://github.com/tug-benson/omarchy-remmina --enable
```

Or symlink during development:

```bash
ln -s /path/to/omarchy-remmina ~/.config/omarchy/plugins/io.github.tug-benson.remmina
omarchy-shell shell rescanPlugins
```

To remove:

```bash
omarchy plugin remove io.github.tug-benson.remmina
```

## Dependencies

All via `pacman` / `yay` — no `snap`:

```bash
omarchy pkg add remmina python3 zenity
# optional per protocol:
omarchy pkg add freerdp        # optimal RDP (xfreerdp / xfreerdp3)
omarchy pkg add virt-viewer    # SPICE + VNC via remote-viewer
omarchy pkg add openssh        # SSH
```

- `remmina` — fallback for RDP/VNC/SPICE URI launch (`remmina -c <uri>`).
- `freerdp` — preferred for RDP (`xfreerdp /v:host:port /u:user`).
- `virt-viewer` (`remote-viewer`) — preferred for SPICE/VNC.
- `python3` — JSON store, CSV/TXT/SSH/Remmina import, launch helpers.
- `zenity` — file picker for CSV/TXT import.
- `xdg-terminal-exec` (comes with Omarchy) — launches SSH in your default terminal.

## Usage

1. Click `󰢹` in the bar to open the hub.
2. Use the search field to filter.
3. `＋ Add Server` — fill `Name`, `Host` (IP or FQDN), `Protocol`, `Port`, `Username`, `Group`, then Add.
4. Click the right-hand glyph on a row to connect:
   - **SSH** → `xdg-terminal-exec -- ssh [user@]host [-p port]` (uses your SSH config / keys; configure `~/.ssh/config` first).
   - **RDP** → `xfreerdp /v:host:port /u:user /cert:ignore +clipboard` if `freerdp` present, otherwise `remmina -c rdp://user@host:port`.
   - **VNC** → `remmina -c vnc://host:port` (or `vncviewer`/`virt-viewer`).
   - **SPICE** → `remote-viewer spice://host:port` or `remmina -c spice://...`.
5. Use the import buttons:
   - `` — CSV/TXT file picker
   - `` — import all `~/.local/share/remmina/*.remmina`
   - `` — import `~/.ssh/config`
6. Toggle groups collapsed/expanded via the header `` or the `Expand`/`Collapse` links.

### CSV example (`servers.csv`)

```csv
name,host,protocol,port,username,group,notes
srv-win-01,host.example.com,RDP,3389,admin,Windows,prod
srv-lab-01,lab.example.com,SSH,22,admin,Linux,lab
vnc-workstation,example.com,VNC,5900,,Linux,
```

### TXT example (`servers.txt`)

```
srv01;host.example.com;RDP;3389;admin;Windows
srv02;lab.example.com;SSH;22;admin;Linux
```

## Prerequisites & SSH notes

- **SSH** does not use Remmina — it invokes your shell's `ssh`. Ensure `~/.ssh/config` is set up with `Host`, `User`, `IdentityFile`, etc. The plugin can import that file to pre-populate the list, but it never reads private keys.
- **Reading `~/.ssh/config` for population is safe**: only `Host`/`HostName`/`User`/`Port` are parsed; no keys or secrets are touched. Only the hub's `servers.json` is written to.
- **RDP/VNC/SPICE** — no credentials stored; authentication happens in `freerdp`/`remmina`/`remote-viewer` dialogs.
- **Tray icon** — the plugin auto-patches `~/.config/remmina/remmina.pref` (`disable_tray_icon=true`). You can also run `~/.config/omarchy/plugins/io.github.tug-benson.remmina/bin/omarchy-remmina-tray-fix` manually.

## Layout

```
omarchy-remmina/
├── manifest.json
├── BarWidget.qml          # bar icon + badge + panel loader
├── Panel.qml              # counters, search, groups, rows, add/edit form, import, confirm
├── Service.qml            # state: servers, filter, groups, CRUD, launch, import, tray fix
├── preview.png
├── LICENSE
├── README.md
└── bin/
    ├── omarchy-remmina-servers    # CRUD + stats (python)
    ├── omarchy-remmina-launch     # protocol-aware launch (python)
    ├── omarchy-remmina-import     # CSV/TXT/SSH/Remmina import (python)
    └── omarchy-remmina-tray-fix   # disable Remmina tray icon (bash)
```

## Security & privacy

- No passwords or private keys are ever written to disk by this plugin. Only `name`, `host`, `protocol`, `port`, `username`, `group`, `notes` are stored in `~/.config/remmina-panel/servers.json` (`600`).
- No network calls — all data stays local.
- No personal data is committed to the public repo (see `.gitignore`).
- All `Process` invocations use `python3` vector args or `bash -lc` with single-quoted JSON via env var — no shell injection from server fields.

## License

MIT
