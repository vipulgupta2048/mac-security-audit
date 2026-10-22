# Report template

Write for the person who owns the Mac. Plain words, short sentences, every
finding with the command that fixes it. Keep it to what the scan showed.

```markdown
# Mac security audit: <date>

**Verdict:** <One or two sentences. Compromise indicators found or not; the
single most urgent item.>

## Recent attacks checked
| Date | Incident | This Mac |
|---|---|---|
| <date> | <incident, ecosystem> | Affected / Not affected / Not checked (<why>) |

## Tier 0: fix now
| Finding | Installed | Target | Why | Command |
|---|---|---|---|---|

## Tier 1: this week
| Finding | Installed | Target | Command |
|---|---|---|---|

## Tier 2: plan
| Upgrade | From → To | Notes |
|---|---|---|

## Needs your call
| Item | Evidence | Question |
|---|---|---|
| <launch item / cert / extension / listener you can't attribute> | <path, signer team, dates, port> | <Do you recognise this?> |

## Hygiene
- <finding>: <command or setting path>

## Not checked
- <check>: <why> — run `<command>` to cover it.

## Sources
- [<title>](<url>)

Scan data: `<SCAN_DIR>` (delete when done: `rm -rf "<SCAN_DIR>"`)
```

Rules:

- Tier 0 first, even when it's empty ("Nothing urgent").
- Group many outdated Homebrew packages into one row with a single
  `brew upgrade a b c` command; list security-relevant ones by name.
- Name the evidence for anything suspicious (path, signer team, dates), and
  say plainly when you can't tell what something is.
- No secrets, tokens, file contents or command arguments in the report.
- End with an offer: walk through any Tier 0 item step by step, or re-run
  the audit after fixes.
