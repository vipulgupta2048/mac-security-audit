#!/bin/bash
# Outdated packages from each package manager. Read-only: it asks registries
# what is newer and never installs or updates. Usage: packages.sh [--no-network]
. "$(dirname "$0")/lib.sh"
NET=1
[ "${1:-}" = --no-network ] && NET=0
S=packages

# Homebrew. HOMEBREW_NO_AUTO_UPDATE stops `brew outdated` from running
# `brew update` behind our back; report how old its metadata is instead.
if have brew; then
	export HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_ANALYTICS=1 HOMEBREW_NO_ENV_HINTS=1
	api="$(brew --cache 2>/dev/null)/api/formula.jws.json"
	if [ -f "$api" ]; then
		age=$((($(date +%s) - $(stat -f %m "$api")) / 86400))
		[ $age -gt 2 ] && st=warn || st=ok
		row $S brew.metadata $st "${age}d old" "results reflect metadata from $(mtime "$api"); 'brew update' refreshes it (changes nothing installed)"
	fi
	brew outdated --verbose 2>/dev/null | while IFS= read -r line; do
		[ -n "$line" ] || continue
		name=${line%% *}
		row $S brew.outdated warn "$name" "$(printf '%s' "$line" | sed -E 's/^[^ ]+ \((.*)\) [<!]= (.*)$/installed \1 -> \2/')"
	done
	n=$(brew list --formula 2>/dev/null | wc -l | tr -d ' ')
	c=$(brew list --cask 2>/dev/null | wc -l | tr -d ' ')
	row $S brew.installed info "$n formulae, $c casks" ""
	row $S brew.casks info "$(brew list --cask 2>/dev/null | tr '\n' ' ')" ""
	# Third-party taps can ship anything; list them for review.
	brew tap 2>/dev/null | grep -vE '^homebrew/' | while IFS= read -r t; do row $S brew.tap info "$t" "third-party tap"; done
fi

# Mac App Store, when the mas CLI is installed.
if have mas && [ $NET = 1 ]; then
	run_t 60 mas outdated 2>/dev/null | while IFS= read -r line; do
		[ -n "$line" ] && row $S mas.outdated warn "$line" ""
	done
fi

# Global npm packages for every installed Node, since each has its own tree.
for npm in "$HOME"/.nvm/versions/node/*/bin/npm "$(command -v npm 2>/dev/null)" /opt/homebrew/bin/npm /usr/local/bin/npm; do
	[ -x "$npm" ] || continue
	real=$(cd "$(dirname "$npm")" && pwd -P)/$(basename "$npm")
	case " $SEEN " in *" $real "*) continue ;; esac
	SEEN="$SEEN $real"
	bindir=$(dirname "$npm")
	list=$(PATH="$bindir:$PATH" run_t 30 "$npm" ls -g --depth=0 --parseable 2>/dev/null | sed 1d | sed 's#.*/node_modules/##' | tr '\n' ' ')
	row $S npm.global info "${list:-none}" "$npm"
	if [ $NET = 1 ]; then
		PATH="$bindir:$PATH" run_t 60 "$npm" outdated -g --parseable 2>/dev/null | while IFS=: read -r _ _ cur latest _; do
			[ -n "$latest" ] && [ "$cur" != "$latest" ] || continue
			row $S npm.global.outdated warn "${cur%@*}" "installed ${cur##*@} -> latest ${latest##*@} ($npm)"
		done
	fi
done

# Python: user and Homebrew site-packages.
if have python3 && [ $NET = 1 ]; then
	run_t 90 python3 -m pip list --outdated 2>/dev/null | awk 'NR>2 {print $1 "\t" $2 "\t" $3}' | while IFS="$(printf '\t')" read -r n cur lat; do
		row $S pip.outdated warn "$n" "installed $cur -> latest $lat"
	done
fi
have pipx && pipx list --short 2>/dev/null | while IFS= read -r line; do row $S pipx info "$line" ""; done

# VS Code family and browser extensions are in extensions.sh.
exit 0
