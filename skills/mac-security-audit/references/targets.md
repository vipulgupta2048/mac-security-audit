# Choosing upgrade targets

Recommend the newest release that is **supported, stable, and long-lived**,
not simply the newest. Get the facts from `eol.tsv` (endoflife.date) and the
project's own release page; never from memory.

| Component | Target |
|---|---|
| macOS | Latest point release of the installed major first (that's where security fixes land). A new major (e.g. 26 → 27) is Tier 2: optional, after the user's critical apps support it. |
| Node.js | Newest **Active LTS** line, latest patch (`newest-lts` in `eol.tsv`). If a new LTS line was promoted in the last few weeks, offer both: the new line for new work, the previous LTS's latest patch for projects that pin it. Remove versions past EOL from version managers once nothing uses them. Match `@types/node` and CI images to the same major. |
| Python | Latest patch of the newest line that has had at least one bug-fix release (x.y.1+). Python has no LTS; every line gets 5 years. |
| OpenSSL | The current LTS line (`newest-lts`), unless a dependency needs the newer one. |
| Go, Ruby, PHP, Kubernetes client | Latest patch of a supported line; prefer the newest line when nothing pins an old one. |
| Java | Latest LTS (17, 21, 25…) patch from the vendor the user already uses. |
| Package managers (npm, pnpm, yarn, bun, uv) | Latest stable within the major the project pins (`packageManager`, `engines`); a new major is Tier 2. |
| Git, gh, curl, Docker / OrbStack, editors, browsers | Latest stable. Browsers and editors self-update; the fix is usually "restart to finish updating". |
| Homebrew formulae | Whatever `brew outdated` reports. Versioned formulae (`node@22`, `python@3.13`) stay on their line. |
| Project dependencies | The fixed version from the advisory, the smallest bump that clears it. Majors are Tier 2. |

## Cooldowns

Brand-new releases are where worms land. `eol.tsv` gives each line's latest
release date (`released`); for packages, `npm view <pkg> time --json` or the
release page has it. Don't recommend a release published less than 24 hours
ago (7 days for package majors) unless it fixes an actively
exploited vulnerability, and say so when you do. If a project sets
`minimumReleaseAge` (pnpm) or similar, respect it.

## Tiers

- **Tier 0, now**: IOC hits, exploited CVEs that apply, pending macOS
  security updates, runtimes past EOL, protections turned off.
- **Tier 1, this week**: supported lines behind on patches, security-relevant
  Homebrew and pip packages, plaintext credential fixes.
- **Tier 2, plan**: major upgrades and anything with breaking changes.
