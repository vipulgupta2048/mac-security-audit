#!/bin/bash
# Editor and browser extensions: id, version, name. Read-only, offline.
# ioc.sh matches these ids against the IOC list; the agent judges the rest.
. "$(dirname "$0")/lib.sh"
S=extensions

# VS Code and its forks keep one folder per extension: publisher.name-version.
for dir in "$HOME/.vscode/extensions" "$HOME/.vscode-insiders/extensions" "$HOME/.cursor/extensions" \
	"$HOME/.windsurf/extensions" "$HOME/.vscode-oss/extensions" "$HOME/.kiro/extensions" "$HOME/.antigravity/extensions"; do
	[ -d "$dir" ] || continue
	editor=$(basename "$(dirname "$dir")" | sed 's/^\.//')
	n=0
	for e in "$dir"/*/; do
		[ -f "$e/package.json" ] || continue
		n=$((n + 1))
		base=$(basename "$e")
		id=$(printf '%s' "$base" | sed -E 's/-[0-9]+\.[0-9]+\.[0-9]+.*$//')
		v=$(printf '%s' "$base" | sed -E 's/^.*-([0-9]+\.[0-9]+\.[0-9]+[^-]*).*$/\1/')
		row $S "ide.$editor" info "$id" "version $v | modified $(mtime "$e")"
	done
	row $S "ide.$editor.count" info "$n" "$dir"
done

# Chromium browsers: Profile/Extensions/<id>/<version>/manifest.json
chromium_root() {
	case "$1" in
	chrome) printf '%s' "$HOME/Library/Application Support/Google/Chrome" ;;
	brave) printf '%s' "$HOME/Library/Application Support/BraveSoftware/Brave-Browser" ;;
	edge) printf '%s' "$HOME/Library/Application Support/Microsoft Edge" ;;
	arc) printf '%s' "$HOME/Library/Application Support/Arc/User Data" ;;
	vivaldi) printf '%s' "$HOME/Library/Application Support/Vivaldi" ;;
	chromium) printf '%s' "$HOME/Library/Application Support/Chromium" ;;
	opera) printf '%s' "$HOME/Library/Application Support/com.operasoftware.Opera" ;;
	esac
}
for b in chrome brave edge arc vivaldi chromium opera; do
	root=$(chromium_root $b)
	[ -d "$root" ] || continue
	for ext in "$root"/*/Extensions/*/; do
		[ -d "$ext" ] || continue
		id=$(basename "$ext")
		profile=$(basename "$(dirname "$(dirname "$ext")")")
		m=$(ls -d "$ext"*/manifest.json 2>/dev/null | tail -1)
		[ -n "$m" ] || continue
		name=$(jsonq "$m" "d.name")
		v=$(jsonq "$m" "d.version")
		perms=$(jsonq "$m" "[].concat(d.permissions||[],d.host_permissions||[]).filter(function(p){return /<all_urls>|^\*:|nativeMessaging|debugger|cookies|webRequest|proxy|clipboardRead|management/.test(p)}).join(' ')")
		case "$name" in
		__MSG_*)
			key=$(printf '%s' "$name" | sed 's/^__MSG_//; s/__$//')
			for loc in en en_US en_GB; do
				msg="$(dirname "$m")/_locales/$loc/messages.json"
				[ -f "$msg" ] || continue
				name=$(jsonq "$msg" "(function(){var k=Object.keys(d).filter(function(x){return x.toLowerCase()==='$key'.toLowerCase()})[0];return k?d[k].message:''})()")
				break
			done
			;;
		esac
		st=info
		[ -n "$perms" ] && st=warn
		row $S "browser.$b" $st "$id" "$name $v | profile $profile | broad perms: ${perms:-none}"
	done
done

# Firefox keeps a JSON index per profile.
for f in "$HOME"/Library/Application\ Support/Firefox/Profiles/*/extensions.json; do
	[ -f "$f" ] || continue
	jsonq "$f" "d.addons.filter(function(a){return a.type==='extension'&&!a.location.startsWith('app-')}).map(function(a){return a.id+'|'+(a.defaultLocale&&a.defaultLocale.name||'')+' '+a.version+(a.active?'':' (disabled)')})" |
		while IFS='|' read -r id rest; do row $S browser.firefox info "$id" "$rest"; done
done

# Safari web extensions are app extensions registered with pluginkit.
pluginkit -mAv -p com.apple.Safari.web-extension 2>/dev/null | awk '$1 !~ /^\(/ {print $1}' | while IFS= read -r id; do
	[ -n "$id" ] && row $S browser.safari info "$id" ""
done
exit 0
