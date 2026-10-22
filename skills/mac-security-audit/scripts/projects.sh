#!/bin/bash
# Known CVEs in the projects on this Mac. Read-only: sends lockfile contents
# to the vulnerability databases (OSV, or the npm registry's audit endpoint),
# installs and changes nothing.
# Usage: projects.sh [--max N] [project roots...]
. "$(dirname "$0")/lib.sh"
S=projects
MAX=40
if [ "${1:-}" = --max ]; then
	MAX=$2
	shift 2
fi
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

project_roots "$@" | while IFS= read -r root; do
	[ -d "$root" ] || continue
	find "$root" -maxdepth 5 \( -name node_modules -o -name .git -o -name .venv -o -name vendor \) -prune -o -type f \
		\( -name pnpm-lock.yaml -o -name package-lock.json -o -name yarn.lock -o -name bun.lock -o -name poetry.lock \
		-o -name uv.lock -o -name 'requirements*.txt' -o -name Cargo.lock -o -name go.sum -o -name Gemfile.lock \) -print 2>/dev/null
done | head -n "$MAX" >"$TMP/locks"
total=$(wc -l <"$TMP/locks" | tr -d ' ')
row $S scanned info "$total lockfiles" "capped at $MAX; pass --max to raise"

if have osv-scanner; then
	while IFS= read -r f; do
		run_t 180 osv-scanner scan source --format json -L "$f" >"$TMP/o.json" 2>/dev/null
		out=$(jsonq "$TMP/o.json" "(d.results||[]).map(function(r){var p=r.packages||[];var n=0;var top=p.slice(0,8).map(function(x){n+=x.vulnerabilities.length;return x.package.name+'@'+x.package.version+' '+x.vulnerabilities.map(function(v){return v.id}).slice(0,3).join(',')});return p.length+'|'+top.join('; ')})")
		if [ -z "$out" ]; then
			row $S osv ok "$f" "no known vulnerabilities"
		else
			n=${out%%|*}
			row $S osv warn "$f" "$n vulnerable packages: ${out#*|}"
		fi
	done <"$TMP/locks"
	exit 0
fi

row $S osv info "osv-scanner not installed" "npm-only fallback; 'brew install osv-scanner' covers every ecosystem (ask first)"
while IFS= read -r f; do
	d=$(dirname "$f")
	case "$f" in
	*package-lock.json)
		(cd "$d" && run_t 120 npm audit --package-lock-only --json) >"$TMP/a.json" 2>/dev/null
		;;
	*pnpm-lock.yaml)
		have pnpm || continue
		(cd "$d" && run_t 120 pnpm audit --json) >"$TMP/a.json" 2>/dev/null
		;;
	*) continue ;;
	esac
	sev=$(jsonq "$TMP/a.json" "(function(){var m=(d.metadata||{}).vulnerabilities;if(!m)return '';return ['critical','high','moderate','low'].map(function(k){return k+'='+(m[k]||0)}).join(' ')})()")
	if [ -z "$sev" ]; then
		row $S audit denied "$f" "audit failed: offline, or the package manager needs a newer Node than the default (try: nvm exec 24 pnpm audit, in that folder)"
	else
		case "$sev" in *"critical=0 high=0"*) st=info ;; *) st=warn ;; esac
		row $S audit $st "$f" "$sev"
	fi
done <"$TMP/locks"
exit 0
