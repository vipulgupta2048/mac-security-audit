#!/bin/bash
# Everything that starts on its own: launchd items, cron, shell startup files,
# profiles. Read-only, no sudo. Prints program paths and flags, never the full
# command line (arguments can carry tokens).
. "$(dirname "$0")/lib.sh"
S=persistence

# Patterns that are unusual in a legitimate autostart item.
RISKY='(curl|wget)[^|]*\|[[:space:]]*(sudo[[:space:]]+)?(ba|z|fi|da)?sh|base64[[:space:]]+(-d|-D|--decode)|osascript[[:space:]]+-e|python[0-9.]*[[:space:]]+-c|/dev/tcp/|nc[[:space:]]+-[el]|eval[^#]*(curl|wget|base64)|DYLD_INSERT'

plist_program() {
	local p=$1 prog
	prog=$(plutil -extract Program raw -o - "$p" 2>/dev/null)
	[ -n "$prog" ] || prog=$(plutil -extract ProgramArguments.0 raw -o - "$p" 2>/dev/null)
	printf '%s' "$prog"
}

for dir in "$HOME/Library/LaunchAgents" /Library/LaunchAgents /Library/LaunchDaemons; do
	[ -d "$dir" ] || continue
	if ! ls "$dir" >/dev/null 2>&1; then
		row $S launchd denied "$dir" "not readable"
		continue
	fi
	for p in "$dir"/*.plist; do
		[ -e "$p" ] || continue
		label=$(plutil -extract Label raw -o - "$p" 2>/dev/null)
		prog=$(plist_program "$p")
		flags=""
		st=info
		base=$(basename "$prog")
		case "$base" in
		sh | bash | zsh | fish | dash | python* | perl | ruby | node | bun | deno | osascript | env)
			flags="$flags interpreter"
			st=warn
			;;
		esac
		case "$prog" in
		/tmp/* | /private/tmp/* | /var/tmp/* | /Users/Shared/* | "$HOME"/.* | */.*/*)
			flags="$flags odd-location"
			st=warn
			;;
		esac
		if [ -z "$prog" ]; then
			flags="$flags no-program"
		elif [ ! -e "$prog" ]; then
			flags="$flags missing-binary"
		else
			sig=$(signer "$prog")
			flags="$flags signer=$sig"
			case "$sig" in unsigned | adhoc) st=warn ;; esac
		fi
		if plutil -convert xml1 -o - "$p" 2>/dev/null | grep -Eq "$RISKY"; then
			flags="$flags risky-args"
			st=fail
		fi
		case "$label" in *gh-token-monitor*) st=fail flags="$flags known-ioc" ;; esac
		row $S launchd $st "$label" "$p -> $prog |$flags | modified $(mtime "$p")"
	done
done

# Login items and background items live in a database only root can dump.
row $S btm denied "" "login/background items need: sudo sfltool dumpbtm (or System Settings > General > Login Items)"

# User crontab: count and flag, never print the lines.
ct=$(crontab -l 2>/dev/null | grep -v '^[[:space:]]*#' | grep -c .)
if [ "${ct:-0}" -gt 0 ]; then
	r=$(crontab -l 2>/dev/null | grep -Ec "$RISKY")
	[ "$r" -gt 0 ] && row $S cron fail "$ct entries" "$r match risky patterns" || row $S cron info "$ct entries" ""
else
	row $S cron ok none ""
fi
for f in /etc/periodic/daily/* /etc/periodic/weekly/* /etc/periodic/monthly/* /usr/local/etc/periodic/*/*; do
	[ -f "$f" ] || continue
	case "$f" in /etc/periodic/*/[0-9][0-9][0-9].*) continue ;; esac
	row $S periodic warn "$f" "non-standard periodic script, modified $(mtime "$f")"
done

# Shell startup files: report line numbers of risky patterns only.
for f in "$HOME/.zshrc" "$HOME/.zprofile" "$HOME/.zshenv" "$HOME/.zlogin" "$HOME/.bashrc" "$HOME/.bash_profile" "$HOME/.profile" \
	"$HOME/.config/fish/config.fish" "$HOME"/.config/fish/conf.d/*.fish /etc/zshrc /etc/zprofile /etc/profile; do
	[ -f "$f" ] || continue
	lines=$(grep -nE "$RISKY" "$f" 2>/dev/null | cut -d: -f1 | tr '\n' ',' | sed 's/,$//')
	[ -n "$lines" ] && row $S shellrc warn "$f" "risky pattern on line(s) $lines"
done

# Configuration profiles installed for this user (system ones need root).
out=$(profiles list 2>/dev/null | grep -E 'attribute: profileIdentifier' | sed 's/.*profileIdentifier: //')
if [ -n "$out" ]; then
	printf '%s\n' "$out" | while IFS= read -r id; do row $S profile info "$id" "user profile"; done
fi
row $S profile.system denied "" "system profiles need: sudo profiles list -all (or System Settings > Privacy & Security > Profiles)"

# Authorization plugins and login hooks can run code at login for every user.
for f in /Library/Security/SecurityAgentPlugins/*; do
	[ -e "$f" ] && row $S authplugin warn "$(basename "$f")" "$(signer "$f")"
done
v=$(defaults read /Library/Preferences/com.apple.loginwindow LoginHook 2>/dev/null)
[ -n "$v" ] && row $S loginhook fail "$v" "legacy login hook set"
exit 0
