# mac-security-audit

A Claude Code skill that audits a developer's Mac for security problems and
tells you exactly what to upgrade. **Read-only**: it never installs,
updates or changes anything. You run the fixes.

It checks:

- **macOS**: pending updates, SIP, Gatekeeper, FileVault, firewall, XProtect,
  auto-updates, screen lock, sharing, AirDrop, MDM.
- **Persistence**: launch agents and daemons (signer, risky arguments), cron,
  shell startup files, profiles.
- **Network**: listening services, DNS and proxies, certificates someone
  added trust to.
- **Credentials**: SSH key strength and passphrases, plaintext tokens on disk
  (npm, git, Docker, cloud CLIs).
- **Extensions**: VS Code / Cursor / Windsurf, plus Chrome, Brave, Edge, Arc,
  Firefox and Safari extensions with broad permissions.
- **Dev supply chain**: Claude Code hooks, MCP servers, files planted by the
  2026 npm worms, auto-run VS Code tasks, npm/pnpm safety settings.
- **Recent attacks**: searches the web for this week's and this month's
  supply-chain compromises, then matches your lockfiles, global packages and
  extensions against them and a curated list.
- **Versions**: outdated Homebrew, App Store, npm and pip packages, runtimes
  past end of life, and known CVEs in your projects. Upgrade targets are the
  latest LTS or stable releases.

You get one report: a verdict, then **Tier 0** (fix now), **Tier 1** (this
week), **Tier 2** (plan), each with the command to run.

## Install

```bash
git clone <this repo> ~/src/mac-security-audit
mkdir -p ~/.claude/skills
ln -s ~/src/mac-security-audit/skills/mac-security-audit ~/.claude/skills/mac-security-audit
```

Then, in Claude Code: **"audit my Mac"** (or `/mac-security-audit`). Tell it
where your projects live, e.g. "my code is in ~/work and ~/oss".

Requirements: macOS 14+, nothing else. It uses Homebrew, npm, pip and
[osv-scanner](https://github.com/google/osv-scanner) when they're installed
(`brew install osv-scanner` makes the project CVE check cover every
ecosystem).

### Without Claude

The collectors run on their own and print tab-separated rows:

```bash
bash skills/mac-security-audit/scripts/run-all.sh ~/work
```

Each row is `section  id  status  value  detail`; look at `warn`, `fail` and
`denied`. [references/checks.md](skills/mac-security-audit/references/checks.md)
explains every check and its fix.

## What it sends over the network

- Apple's update servers (`softwareupdate --list`).
- endoflife.date: product names only (`nodejs`, `python`, …).
- The npm and PyPI registries, to see what's outdated.
- Your project lockfiles to OSV (osv-scanner) or the npm audit endpoint.
- Web searches for recent attacks (from Claude, not the scripts).

`--no-network` skips all of the script-side calls.

## Privacy

Reports name files, paths and settings, never their contents. Tokens in
anything the scripts print are masked. Scan data goes to a private folder in
`$TMPDIR`; delete it when you're done.

## Safety

- Read the scripts before you run them; they're short. `tests/selftest.sh`
  checks that no collector contains an install, update, `sudo` or write
  command, and that IOC matching and secret masking work.
- Some checks need root (login items, system profiles). The skill lists those
  under "Not checked" with the command, rather than asking for your password.

## Keeping the IOC list current

[references/iocs.tsv](skills/mac-security-audit/references/iocs.tsv) holds
known-bad package versions, extension ids and file paths, each with a primary
source. Add entries by pull request; never without a source.

## Tests

```bash
bash tests/selftest.sh
```

## License

MIT
