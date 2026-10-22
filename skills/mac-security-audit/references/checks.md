# Checks: what they mean and how to fix them

Ids match the second column of the collector output. "Fix" commands are for
the **user** to run; never run them yourself. Commands that need `sudo` ask
for the user's password.

Severity guide for the report:

- **critical**: indicator of compromise (IOC hit, worm file, risky launch
  item), or an exploited CVE that applies to an installed version.
- **high**: protection off (FileVault, firewall, SIP, Gatekeeper), runtime
  past end of life, pending macOS security update, plaintext secret with loose
  permissions.
- **medium**: supported but behind on patches, broad-permission extensions
  you can't attribute, services listening on all interfaces.
- **low**: hardening and hygiene, e.g. `firewall.stealth` off, `airdrop`
  Everyone, `ssh.dir` not 700, `sudo.touchid` off.

Before giving an upgrade command, look at the install path in the row's
detail column and use that installer: `/opt/homebrew` or `/usr/local/Cellar`
→ Homebrew; `~/.nvm`, `~/.volta`, `~/.local/share/fnm`, `mise`, `asdf` → that
version manager; `/usr/local/go` → the go.dev installer; `/Applications/*.app`
→ the app's own updater; `/usr/bin` → part of macOS (only a macOS update
changes it). If you can't tell how it was installed, say so and give the
vendor's download page.

## posture

| id | Good | Fix |
|---|---|---|
| `os.pending` | none | System Settings > General > Software Update, or `softwareupdate --list` then `sudo softwareupdate -i '<Label>' --restart`. Install the point release of the current major first (security fixes); a new major is a separate decision. |
| `sip` | enabled | Boot to Recovery, Terminal: `csrutil enable`, restart. Disabled SIP is rare outside kernel development; ask why. |
| `gatekeeper` | enabled | `sudo spctl --global-enable` |
| `filevault` | on | System Settings > Privacy & Security > FileVault > Turn On (or `sudo fdesetup enable`). Store the recovery key somewhere safe. |
| `firewall` | enabled | `sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on` |
| `firewall.stealth` | on | `sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setstealthmode on` (low; stops replying to probes). |
| `xprotect`, `xprotect.bundle` | updated within ~2 weeks | Stale data means background updates are off: turn on "Install Security Responses and system files" in Software Update > Automatic updates. |
| `autoupdate.*` | on or default | System Settings > General > Software Update > Automatic updates (i). `CriticalUpdateInstall` and `ConfigDataInstall` off are **high**: they carry XProtect and Rapid Security Responses. `AutomaticallyInstallMacOSUpdates` off is a common, acceptable choice if the user patches promptly. |
| `screenlock` | immediate | System Settings > Lock Screen > "Require password after screen saver begins or display is turned off": Immediately. |
| `autologin` | off | System Settings > Users & Groups > Automatically log in as: Off. Auto-login also disables FileVault's pre-boot protection. |
| `guest` | off | `sudo sysadminctl -guestAccount off` |
| `user.admin` | info | Daily admin use is normal on personal Macs; mention a separate standard account only as low. |
| `airdrop` | Contacts Only | Control Center > AirDrop > Contacts Only. |
| `mdm` | info | Enrolled means an organisation can manage the Mac. Note the server host; only flag if the user doesn't recognise it. |
| `sudo.touchid` | info | Optional convenience: `sudo cp /etc/pam.d/sudo_local.template /etc/pam.d/sudo_local`, then uncomment the `pam_tid.so` line. |
| `sysext` | info | Third-party system/network extensions see traffic or files. Flag ones whose team or bundle id the user can't attribute. |

## persistence

| id | Reading it | Fix |
|---|---|---|
| `launchd` | `info` with an attributable signer team is normal. `warn`: interpreter as the program, odd location (`/tmp`, `/Users/Shared`, hidden folders), unsigned or ad-hoc binary. `fail`: risky arguments (curl-pipe-shell, base64 decode, `osascript -e`, `/dev/tcp`) or a known IOC label. `missing-binary`: leftover from an uninstalled app (low). | Review the plist (`plutil -p <path>`). Stop it: `launchctl bootout gui/$(id -u) <plist>` for `~/Library/LaunchAgents`, `sudo launchctl bootout system <plist>` for `/Library/LaunchDaemons` (`gui/<uid>` for `/Library/LaunchAgents`), then move the plist out. Homebrew services (`homebrew.mxcl.*`): `brew services stop <name>`. Ad-hoc signatures are normal for Homebrew builds; flag them elsewhere. **If it is `gh-token-monitor` or anything with risky args, follow "Incident" below first.** |
| `btm` | denied without root | `sudo sfltool dumpbtm`, or System Settings > General > Login Items & Extensions. |
| `cron` | none | `crontab -l` to review, `crontab -e` to edit. |
| `periodic` | none | Non-standard scripts in `/etc/periodic` run daily/weekly as root; review them. |
| `shellrc` | no risky lines | Open the file at the listed line. `eval "$(brew shellenv)"`-style lines are filtered out; anything that downloads and runs code at shell start is not normal. |
| `profile`, `profile.system` | info / denied | `sudo profiles list -all`, or System Settings > Privacy & Security > Profiles. Unknown profiles can install root certificates, proxies and DNS. |
| `authplugin`, `loginhook` | none | Authorization plugins and login hooks run at login for every user; anything not from a known security vendor is suspicious. |

## network

| id | Reading it | Fix |
|---|---|---|
| `listen` | Loopback is fine. All-interfaces listeners are reachable from the local network: Apple services (`rapportd`, `ControlCenter` for AirPlay), Spotify, VPN and container tools are common. Sharing ports (22, 445, 548, 3283, 5900) mean a sharing service is on. "owned by another user" is a root or system process. | Turn off unused sharing in System Settings > General > Sharing. AirPlay Receiver: System Settings > General > AirDrop & Handoff. Dev servers: bind to `127.0.0.1`. |
| `dns`, `proxy` | Your router or a known resolver; no proxy | A proxy or resolver the user didn't set is a classic interception sign: System Settings > Network > (interface) > Details > Proxies / DNS. |
| `trusted.cert` | Only certs the user installed on purpose | Debugging proxies (Proxyman, Charles, mitmproxy) install a CA that can read all TLS; keep it only while in use. Anything unrecognised: Keychain Access > search the name > delete or set Trust to "Use System Defaults". |
| `hosts` | default or a known blocklist | Review `/etc/hosts`; large counts usually mean an ad-block list. |

## credentials

| id | Fix |
|---|---|
| `ssh.dir` | `chmod 700 ~/.ssh` |
| `ssh.key` | No passphrase: `ssh-keygen -p -f ~/.ssh/<key>` (add `UseKeychain yes` / `AddKeysToAgent yes` to `~/.ssh/config` for convenience). RSA under 3072 bits or DSA/ECDSA: make a new one with `ssh-keygen -t ed25519` and replace it where it's registered. Wrong mode: `chmod 600 ~/.ssh/<key>`. |
| `ssh.authorized_keys` | Others can log in if Remote Login is on; review each key. |
| `ssh.config` | `StrictHostKeyChecking no` and `ForwardAgent yes` for broad hosts expose you to MITM and agent hijacking; scope them to specific hosts. |
| `npmrc`, `yarnrc` | Use a granular, expiring token; put `//registry.npmjs.org/:_authToken=${NPM_TOKEN}` in `~/.npmrc` and keep the token in the keychain or a secrets manager. `chmod 600 ~/.npmrc`. |
| `git-credentials`, `git.credential.helper=store` | `git config --global credential.helper osxkeychain`, then delete `~/.git-credentials` after confirming the keychain has them. |
| `docker` | Add `"credsStore": "osxkeychain"` to `~/.docker/config.json` and log in again. |
| `aws`, `gcloud`, `azure`, `kube` | Prefer short-lived credentials (AWS SSO / `aws-vault`, `gcloud auth login` without long-lived keys). `chmod 600` the files. |
| `gh` | `gh auth login` stores the token in the keychain by default; a token in `hosts.yml` means it was set up with `--insecure-storage`. |
| `netrc`, `pypirc`, `cargo`, `gem`, `claude` | Plaintext tokens; `chmod 600`, rotate if the file was ever shared or synced. |

## extensions

| id | Reading it | Fix |
|---|---|---|
| `ide.*` | info: list, check against the research step. | Remove: `code --uninstall-extension <id>` (or `cursor`). |
| `browser.*` | `warn` = broad permissions (all sites, cookies, webRequest, native messaging, clipboard). Password managers, ad blockers and dark-mode tools legitimately need them. | Flag extensions the user can't attribute or no longer uses. Remove from the browser's extensions page. |

## devchain

| id | Reading it | Fix |
|---|---|---|
| `claude.hooks` | Hooks run commands automatically. User hooks the user wrote are fine; a project hook running `node .claude/setup.mjs` or `.vscode/setup.mjs` is the ChainDrop/Tensorlake worm. | Review the hook command; remove unknown hooks from the settings file. |
| `mcp` | Each MCP server is code an agent runs with your permissions. | Remove servers the user doesn't recognise from that agent's config. |
| `agent.skills` | info | Skills are instructions plus scripts an agent will run; review third-party ones before use. |
| `worm.file` | **critical** | "Incident" below. |
| `vscode.folderOpen` | A task that runs when a folder opens. Legitimate for watch tasks; the worm uses one named "Environment Setup". | Review the task; delete the `runOptions.runOn` entry if unwanted. |
| `ghostaction.workflow` | Workflow name used by GhostAction. | Check `git log --follow <file>` for who added it; GhostAction workflows send repo secrets to an outside server. |
| `npm.ignore-scripts`, `pnpm.minimum-release-age` | Hardening | `npm config set ignore-scripts true` (some packages need install scripts; allow them per project). pnpm: `minimumReleaseAge: 1440` in `pnpm-workspace.yaml` or global config delays brand-new versions by a day, which catches most worm releases. |

## ioc

| id | Reading it | Fix |
|---|---|---|
| `package.npm`, `package.pypi` | **critical**: a listed malicious version is in a lockfile or installed. | "Incident" below. Then pin the clean version named in the advisory (not "latest"; in some campaigns latest was the payload), delete `node_modules`, reinstall from the fixed lockfile. |
| `extension` | **critical** | Remove the extension, then "Incident". |
| `path` | **critical** | "Incident". |
| `coverage` | Check the lockfile count and roots: zero lockfiles means the scan didn't look. | Rerun with the right project roots. |

## packages, toolchain, eol, projects

| id | Fix |
|---|---|
| `brew.metadata` | Stale metadata makes `brew.outdated` incomplete: `brew update` refreshes it without changing installed software. |
| `brew.outdated` | `brew upgrade <name>` for the Tier 0/1 items, or `brew upgrade` for all. Security-relevant formulae first: openssl, ca-certificates, curl, libssh, gnupg, cloudflared, git, node, python. |
| `brew.tap` | Third-party taps can ship anything; keep the ones you know. `brew untap <tap>`. |
| `mas.outdated` | `mas upgrade`, or the App Store's Updates page. |
| `npm.global.outdated` | `npm i -g <pkg>@latest` using that Node (`nvm use <version>` first). |
| `pip.outdated` | Security-relevant first (certifi, urllib3, requests, cryptography). Homebrew Python: `brew upgrade python@3.x`; pip packages there belong in a venv or `pipx`. |
| `eol` `fail` | Past end of life: no more security fixes. Node: `nvm install <lts-major> && nvm alias default <lts-major>`, then `nvm uninstall <old>` once projects move. Others: the same installer that put it there (see the install-path rule above). System Ruby/Python under `/usr/bin` belong to macOS; ignore them. |
| `eol` `warn` | Supported line, behind on patches: upgrade within the line (e.g. Node 24.18 → 24.22). |
| `projects` `osv` / `audit` | Upgrade the affected dependency to the fixed version from the advisory; for transitive deps use `overrides` (npm/pnpm) or `resolutions` (yarn). |

## Incident: an IOC, worm file or risky launch item was found

Tell the user plainly, then give these steps in this order. Don't run them.

1. **Disconnect from the network** if a live payload is likely (risky launch
   item, `gh-token-monitor`, worm file in a project they opened recently).
2. **Remove persistence before revoking anything.** The ChainDrop/Tensorlake
   `gh-token-monitor` wipes the home folder when its stolen GitHub token stops
   working. `launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/com.user.gh-token-monitor.plist`,
   then move the plist, `~/.local/bin/gh-token-monitor.sh` and
   `~/.config/gh-token-monitor/` out. Confirm with `launchctl list | grep -i token`.
3. **Remove the malicious package**: delete `node_modules`, pin the clean
   version, reinstall. Remove planted `.claude/settings.json` hooks,
   `.claude/setup.mjs`, `.vscode/setup.mjs` and `runOn: folderOpen` tasks, and
   check `git log` for commits by `claude <claude@users.noreply.github.com>`
   the user didn't make.
4. **Rotate credentials from a clean machine**: GitHub (tokens, SSH keys,
   OAuth apps), npm, cloud keys, AI provider keys, anything in the files
   `credentials.sh` listed. Check GitHub for repos named like
   "Shai-Hulud" and for unexpected workflow runs.
5. **Report it** to the user's security team or the package's maintainers.
