---
name: mac-security-audit
description: Read-only security audit of the Mac you are running on, for developers. Checks macOS security settings and pending updates, everything that autostarts, network listeners and trusted certificates, SSH keys and plaintext credentials, editor and browser extensions, AI-agent hooks and MCP servers, outdated Homebrew/npm/pip packages, runtimes past end of life (Node, Python, Go, OpenSSL and more), and matches lockfiles against this month's supply-chain attacks found by a fresh web search. Produces a tiered upgrade list targeting the latest LTS or stable releases, with exact fix commands for the user to run. Use whenever the user asks to audit, scan, check or harden their Mac, asks "is my Mac secure / up to date", "what should I upgrade", "was I hit by the latest npm worm", or wants a security checkup of their dev machine.
license: MIT
compatibility: macOS 14 or later. Needs only what ships with macOS (bash 3.2, plutil, osascript, perl). Uses Homebrew, npm, pip, osv-scanner when present. Network access for the research step and registry lookups.
metadata:
  author: Vipul Gupta
  version: "0.1.0"
---

# Mac security audit

A read-only audit of this Mac. Collector scripts gather facts into a scan
folder, you research what has been attacked recently, then you judge the facts
against [references/checks.md](references/checks.md) and write one ranked
report with the commands that fix each finding. **The user runs every fix
themselves.**

```
web research ─▶ $SCAN_DIR/iocs.local.tsv ─┐
scripts/run-all.sh ─▶ $SCAN_DIR/*.tsv ────┴─▶ judge (checks.md, targets.md) ─▶ report (report.md)
```

## Rules

- **Read-only, always.** Never install, upgrade, update, uninstall, delete,
  kill, unload, quarantine, change a setting, or run `sudo`. That includes
  `brew update`, `brew upgrade`, `npm i -g`, `softwareupdate -i`, `defaults
  write`, `launchctl`, `tccutil`, and the fix commands in your own report. If
  the user asks you to apply a fix, give them the command and say this skill
  only audits.
- **Names and paths, never contents.** Never print or quote secrets, tokens,
  keys, passwords, env values, command arguments, shell history lines, or the
  contents of credential files. The collectors already mask what they print;
  don't undo that by reading the files yourself.
- **Denied is not clean.** A check that could not look (`denied` rows, missing
  tools, a sandbox error) goes in the report's "Not checked" section with the
  command the user can run to cover it. Never report "nothing found" for it.
- **Exact matches only.** An IOC hit is a real finding. No hit means none of
  the listed versions are present, not that the Mac is clean.
- **Never walk `/` or `~`.** Pass project folders as roots. iCloud and cloud
  drives under the home folder hang recursive scans.
- **Verifying is fine, dumping is not.** To confirm a result you may read
  non-credential config (settings, plists, `mcp.json`) and print key names,
  counts and paths, as the collectors do. Never print values.
- **An unexpected finding is the user's call.** Report a suspicious launch
  agent, certificate or extension with the evidence; don't remove it, and
  don't guess at what it is beyond what the evidence shows.

## Workflow

Do the steps in order: the collectors read the IOC list that step 1 writes.

### 1. Research recent attacks (web)

Use your web search and fetch tools (in Claude Code: `WebSearch` and
`WebFetch`; load them with `ToolSearch` if they're deferred). Follow [references/research.md](references/research.md): search the last 7
and 30 days for supply-chain compromises (npm, PyPI, VS Code / Open VSX,
browser extensions, GitHub Actions, Homebrew, AI-agent tooling) and actively
exploited CVEs in macOS and common dev tools. Prefer primary sources. Write
every affected package, extension id and host path you find with a primary
source into `$SCAN_DIR/iocs.local.tsv`, in the same columns as
[references/iocs.tsv](references/iocs.tsv). Keep a list of incidents and CVEs
with their source URLs for the report.

### 2. Run the collectors

```bash
SCAN_DIR="${TMPDIR}mac-security-audit-$(date +%Y%m%d-%H%M%S)"; mkdir -p "$SCAN_DIR"
SCAN_DIR="$SCAN_DIR" bash scripts/run-all.sh --iocs "$SCAN_DIR/iocs.local.tsv" ~/work ~/code
```

- Replace the roots with the folders that hold the user's projects (ask if you
  can't tell). With no roots it uses `~/work ~/code ~/dev ~/src ~/projects …`
  that exist.
- It takes about a minute (`softwareupdate --list` is the slow part). Add
  `--no-network` for an offline pass.
- Every `*.tsv` row is `section  id  status  value  detail`, with status `ok`,
  `warn`, `fail`, `info` or `denied`. A non-empty `*.err` file means a
  collector hit an error; read it.
- If Claude Code's sandbox is on, it may block some read-only system queries
  (`fdesetup`, `softwareupdate`, `codesign`, `lsof`). Only if a collector
  fails with a sandbox error, rerun it with the sandbox disabled; they only
  read.

The collectors, all read-only:

| Script | Covers |
|---|---|
| `posture.sh` | macOS version, pending updates, SIP, Gatekeeper, FileVault, firewall and stealth, XProtect, auto-update settings, screen lock, auto-login, guest, admin use, AirDrop, MDM, system extensions |
| `persistence.sh` | LaunchAgents/Daemons (program, signer, risky arguments), cron, periodic, shell startup files, profiles, auth plugins, login hooks |
| `network.sh` | Listening sockets and sharing services, DNS, proxies, certificates with custom trust, /etc/hosts |
| `credentials.sh` | SSH keys (type, passphrase, permissions), SSH config, plaintext credential files, git credential helper |
| `extensions.sh` | VS Code / Cursor / Windsurf extensions; Chrome, Brave, Edge, Arc, Firefox, Safari extensions with broad permissions |
| `devchain.sh` | Claude Code hooks, MCP servers across agents, installed skills, worm files in projects, auto-run VS Code tasks, GhostAction workflows, npm/pnpm safety settings |
| `ioc.sh` | Lockfiles, global npm and Python installs, extensions and host paths against `references/iocs.tsv` plus your list |
| `toolchain.sh` | Installed versions of runtimes, package managers, dev tools and common apps |
| `packages.sh` | Outdated Homebrew, Mac App Store, global npm (every Node) and pip packages |
| `eol.sh` | End-of-life status and upgrade targets from endoflife.date |
| `projects.sh` | Known CVEs in project lockfiles via osv-scanner, else npm/pnpm audit |

Any collector also runs on its own, e.g. `bash scripts/ioc.sh --iocs extra.tsv ~/work`.

### 3. Judge the findings

- Read every `warn`, `fail` and `denied` row. Use
  [references/checks.md](references/checks.md) for what each check means, when
  a `warn` is fine, and the fix command.
- For versions, apply [references/targets.md](references/targets.md): latest
  patch of a supported line first, latest LTS for runtimes, never a release
  newer than the project's package cooldown.
- Cross-reference: a CVE from step 1 matters only if the installed version is
  in its affected range. Say which installed component it hits.
- Launch items, certificates, extensions and MCP servers: say what each one
  belongs to only when the evidence (signer team, path, bundle id) shows it.
  Flag what you can't attribute.

### 4. Write the report

Use [references/report.md](references/report.md). Lead with the verdict
(compromise indicators found or not), then Tier 0 (security, now), Tier 1
(supported versions, soon), Tier 2 (major upgrades, plan), "Needs your call"
(things you can't attribute), hygiene, "Not checked", and sources. Every row has the exact command the user can run.
Keep the scan folder path in the report; offer to delete it when they're done.

## References

- [references/checks.md](references/checks.md): every check id, what good looks like, false positives, fix commands
- [references/research.md](references/research.md): how to research recent attacks and build `iocs.local.tsv`
- [references/targets.md](references/targets.md): choosing upgrade targets (LTS, supported lines, cooldowns)
- [references/report.md](references/report.md): report template
- [references/iocs.tsv](references/iocs.tsv): curated IOC list with sources
