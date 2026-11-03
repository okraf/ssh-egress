# ssh-egress

**Make your requests leave from your server's IP, not yours.** One command opens an SSH tunnel to a server you own (a VPS, a box at a friend's place…) and routes `curl`, scripts or any CLI through it. Nothing to install on the server.

```console
$ ssh-egress ip
direct            : 198.51.100.23
via tunnel (IPv4) : 203.0.113.10
via tunnel (any)  : 2001:db8::10

$ ssh-egress curl -s https://example.com
```

Built to be used by AI coding agents such as [Claude Code](https://claude.com/claude-code), and by humans.

## Why
- **Scraping, monitoring, API calls**: a site bans or rate-limits your home IP? Send the traffic out through your server instead, and keep browsing normally from home.
- **Several exit IPs**: one profile per server. If one IP gets blocked, switch to another with `-p`.
- **Opt-in**: nothing goes through the server unless you ask. Your normal traffic stays direct.
- **No VPN, no proxy software**: it is only `ssh -D` (SOCKS5), wrapped so that it is easy and safe to use.

## How it works
```
 your machine                               your server                 the internet
┌──────────────────────────┐   SSH (one TCP   ┌─────────────┐
│ ssh-egress curl ...      │   connection)    │   sshd      │ ──────►  example.com
│   └► socks5h://127.0.0.1 │ ═══════════════► │ (unchanged) │   seen from the server's IP
└──────────────────────────┘                  └─────────────┘
```
- `ssh -D` opens a local SOCKS5 proxy (`127.0.0.1:1080` by default). DNS is resolved on the server side (`socks5h`).
- A control socket (`ControlMaster`) keeps a single SSH connection that every command reuses. The tunnel opens on first use and closes by itself after 10 minutes without traffic.
- `BatchMode=yes` + `IdentitiesOnly=yes` (when a key is set): one key, one authentication attempt, never a password prompt. Servers protected by fail2ban stay happy.

## Requirements
- macOS or Linux, `bash`, `ssh` (OpenSSH) and `curl`.
- A server you can reach with an **SSH key** (password login is not supported on purpose). If the key has a passphrase, load it in `ssh-agent`.
- On the server, TCP forwarding allowed: `AllowTcpForwarding yes` in `sshd_config`, which is the OpenSSH default.

## Install
```sh
git clone https://github.com/okraf/ssh-egress.git
cd ssh-egress
./install.sh            # installs ~/.local/bin/ssh-egress
./install.sh --claude   # same, plus the Claude Code skill (see below)
```
Other location: `./install.sh --prefix /usr/local/bin`. Or simply copy the `ssh-egress` file anywhere in your `PATH`: it is a single, dependency-free script.

## Quick start
```sh
ssh-egress init my-vps.example.com   # create the default profile
ssh-egress ip                        # check: your IP vs the server's IP
ssh-egress curl -sI https://example.com
ssh-egress exec -- python3 scrape.py # any program honoring *_proxy variables
ssh-egress down                      # close the tunnel (optional: it times out)
```
The host can be an alias from your `~/.ssh/config`: user, key and port are then taken from there.

## Commands
| Command | What it does |
|---|---|
| `init <ssh-host> [port]` | create a profile (picks a free local port if omitted) |
| `up` / `down` | open / close the tunnel |
| `status` | is the tunnel open? (default command) |
| `ip` | your direct IP vs the exit IP (IPv4 and IPv6) |
| `curl <args>` | run `curl` through the tunnel |
| `exec -- <cmd>` | run a command with `ALL_PROXY`, `HTTP(S)_PROXY` set to the tunnel |
| `env` | print the proxy `export` lines, to use with `eval "$(ssh-egress env)"` |
| `list` | list profiles and which tunnels are open |

Every command accepts `-p <profile>` (default profile: `default`).

## Profiles (several servers, several IPs)
One profile = one server = one local SOCKS port. Profiles are plain files in `~/.config/ssh-egress/<profile>.conf`:
```sh
SSH_HOST=my-vps.example.com      # required (hostname, IP or ~/.ssh/config alias)
SSH_USER=ubuntu                  # optional
SSH_KEY=$HOME/.ssh/id_ed25519    # optional; when set, only this key is offered
SSH_PORT=22                      # optional
SOCKS_PORT=1080                  # local port, unique per profile
IDLE_TIMEOUT=600                 # seconds without traffic before the tunnel closes
```
```sh
ssh-egress init my-vps.example.com          # -> default.conf, port 1080
ssh-egress -p backup init 203.0.113.7       # -> backup.conf,  port 1081
ssh-egress -p backup curl -s https://api.ipify.org
```
Several tunnels can be open at the same time. See [`examples/profile.conf.example`](examples/profile.conf.example).

## Use it with Claude Code
Claude runs shell commands, so it can use `ssh-egress` directly. Three steps:

**1. Install the skill**, so that Claude knows the tool exists and when to use it (when a site blocks your IP, or when you ask it to "go through the VPS"):
```sh
./install.sh --claude    # copies claude/SKILL.md to ~/.claude/skills/ssh-egress/
```
You can also put it in a single project: copy `claude/SKILL.md` to `<project>/.claude/skills/ssh-egress/SKILL.md`.

**2. Allow the command** without a confirmation each time, in `~/.claude/settings.json`:
```json
{
  "permissions": {
    "allow": ["Bash(ssh-egress:*)"]
  }
}
```

**3. Check that Claude finds it.** Claude's shell may not load your full `PATH` (`~/.local/bin` is often missing). Ask Claude to run `ssh-egress list`; if it is not found, install with `--prefix /usr/local/bin`, or tell Claude the full path.

Then simply ask: *"scrape these 200 pages, go through my VPS"*, or *"this site blocks us, use another IP"*.

No MCP server is needed: a CLI plus a skill is enough, and it works the same in any agent that can run shell commands.

**Limits to know**
- Claude's built-in web tools (WebFetch, WebSearch, Claude in Chrome) do **not** go through the tunnel. Claude must use `ssh-egress curl` or `ssh-egress exec` from the shell; the skill tells it so.
- Do not launch Claude itself inside `ssh-egress exec`: Claude Code does not support SOCKS proxies for its own traffic.

## Good to know
- **IPv4 vs IPv6**: if your server has IPv6, sites reachable in IPv6 will see the server's IPv6 address, others its IPv4. `ssh-egress ip` shows both.
- **Which programs follow `exec`**: those honoring `ALL_PROXY`/`HTTPS_PROXY` with `socks5h://` (curl, git over HTTPS, Python `requests[socks]` or `httpx[socks]`, most CLIs). For others, give them `socks5h://127.0.0.1:<port>` explicitly.
- **It is your IP**: traffic leaves from a server rented in your name. This is not an anonymity tool; respect the terms of use and rate limits of the sites you query.
- **Shared server**: the tunnel uses very few resources, but if it is a production machine, close it with `down` after use.
- Host keys: a new server is trusted on first connection (`StrictHostKeyChecking=accept-new`); a changed key is refused.

## Uninstall
```sh
ssh-egress down; rm ~/.local/bin/ssh-egress
rm -r ~/.config/ssh-egress ~/.claude/skills/ssh-egress
```

## License
[MIT](LICENSE)
