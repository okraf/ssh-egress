---
name: ssh-egress
description: Route web requests (curl, scraping scripts, API calls, any CLI) through the public IP of the user's own server via an SSH SOCKS5 tunnel, instead of the user's home/office IP. Use when the user asks to "use another IP", "go through the VPS/server", "avoid getting banned", or when a site rate-limits, blocks or bans the current IP (429, 403 after many requests).
---

# ssh-egress

`ssh-egress` opens an SSH SOCKS5 tunnel to a server the user owns, so traffic leaves from that server's IP. It is opt-in: nothing is routed until a command below is used.

## Before using it
- Run `ssh-egress list` to see the configured profiles (one profile = one server = one exit IP).
- If the command is not found, try `~/.local/bin/ssh-egress` (that directory is often missing from PATH).
- No profile yet: ask the user for the SSH host, then `ssh-egress init <ssh-host>`. Do not guess hosts, users or keys.

## Commands
```
ssh-egress [-p <profile>] ip                # check: direct IP vs exit IP
ssh-egress [-p <profile>] curl <curl args>  # one request through the server
ssh-egress [-p <profile>] exec -- <cmd...>  # any command, with *_proxy set (socks5h)
ssh-egress [-p <profile>] down              # close the tunnel when done
```
The tunnel opens automatically on first use and closes on its own after the idle timeout.

## Rules
- Use it only when the user asks or when the current IP is being blocked; otherwise go direct.
- If a server's IP is banned too, switch to another profile with `-p`.
- Your built-in web tools (WebFetch, WebSearch, browser tools) do NOT go through the tunnel. To fetch through it, use `ssh-egress curl` from Bash.
- `exec` only works for programs that honor `ALL_PROXY`/`HTTPS_PROXY` with `socks5h://` (curl, Python `requests[socks]`/`httpx[socks]`, git over https, most CLIs). For others, pass the proxy explicitly (`socks5h://127.0.0.1:<port>`, port shown by `ssh-egress list`).
- If the tunnel fails to open, report the error and stop; do not retry in a loop (servers with fail2ban ban repeated SSH failures).
- Close it with `ssh-egress down` when the task is finished.
- The exit IP belongs to the user's server and is traceable to them: respect the target site's terms of use and rate limits.
