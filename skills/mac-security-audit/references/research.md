# Researching recent attacks

Goal: what was compromised or actively exploited in the **last 7 and 30
days** that could touch a developer's Mac, as exact package versions,
extension ids, host paths and CVE ranges, each with a primary source.

## Searches

Run these in parallel. Use today's month and year in the query. Start with a
standard search. Switch to a more thorough mode (and fetch the primary pages)
for any query whose results have no primary source, nothing dated in the
last 30 days, or disagree with each other.

1. `npm supply chain attack malicious packages <Month YYYY>`
2. `PyPI malicious package compromised <Month YYYY>`
3. `VS Code extension malicious Open VSX <Month YYYY>`
4. `Chrome extension compromised malicious update <Month YYYY>`
5. `GitHub Actions compromised workflow tag <Month YYYY>`
6. `Claude Code OR Cursor OR MCP server malicious package hooks <Month YYYY>`
7. `macOS security update exploited vulnerability <Month YYYY>`
8. `CISA KEV added <Month YYYY>` (filter for Apple, Google Chrome, Node.js,
   OpenSSL, Git, curl, Docker, Electron, VS Code)
9. `Node.js security release <Month YYYY>`, and the same for Python, Git,
   OpenSSL and any runtime `toolchain.sh` found

## Sources, in order of trust

- Vendor and registry advisories: GitHub Advisory Database (`MAL-` and
  `GHSA-` ids), osv.dev, Apple security releases (support.apple.com/100100),
  nodejs.org/en/blog/vulnerability, CISA KEV.
- Research teams that publish IOCs: StepSecurity, Socket, Aikido, Wiz,
  Datadog Security Labs, Elastic Security Labs, Checkmarx, Snyk, Microsoft
  Threat Intelligence, Koi Security, Phylum.
- News (The Hacker News, BleepingComputer) only to find the primary report;
  open the primary before you rely on version numbers.

Open each primary report and pull out exact affected versions. Search
summaries get version numbers and dates wrong; don't add an IOC from a
summary alone. When sources conflict, the affected vendor's own advisory
wins (e.g. Apple's security notes decide whether a macOS flaw was exploited);
say in the report when you couldn't confirm a claim.

## Writing iocs.local.tsv

Same six tab-separated columns as `iocs.tsv`:

```
type	name	versions	incident	date	source
npm	some-package	1.2.3,1.2.4	Campaign name	2026-10-20	https://primary.source/report
vscode	publisher.extension	*	Campaign name	2026-10-18	https://primary.source/report
chrome	abcdefghijklmnopabcdefghijklmnop	*	Campaign name	2026-10-18	https://primary.source/report
path	~/Library/LaunchAgents/com.example.agent.plist	-	Campaign name	2026-10-18	https://primary.source/report
```

- `versions`: exact versions, comma-separated; `*` only when every version is
  malicious (typosquats, packages created by the attacker).
- npm scoped names keep the scope (`@scope/name`). PyPI names are normalised
  when matched.
- `path` accepts `~`, `$TMPDIR` and globs.
- Skip Windows-only paths; keep the package entries (install scripts run on
  any OS).
- Domains, IPs, commit authors and workflow names have no TSV type: the
  scripts can't see network traffic or git history across every repo. List
  them in the report's research table, and compare the network ones against
  the `dns`, `proxy` and `hosts` rows yourself.

Write the file with a heredoc and real tab characters, then pass it to
`run-all.sh --iocs` (or `ioc.sh --iocs`).

## For the report

Keep a short table of what you found: date, incident, ecosystem, affected
versions, source URL. In the report, say for each one whether this Mac is
affected, not affected, or not checkable (and why).

## Keeping iocs.tsv current

`iocs.tsv` ships a curated list as of its "Last reviewed" date. When research
turns up a well-sourced entry that will matter for months (a worm family, a
popular package), suggest adding it to the shared list in the skill's repo.
