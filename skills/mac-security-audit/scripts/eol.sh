#!/bin/bash
# Support status and upgrade targets from endoflife.date.
# Usage: eol.sh product:version [product:version ...]
#   e.g. eol.sh macos:26.3.1 nodejs:20.19.6 python:3.14.5
# Network: one GET per product to endoflife.date. Only product names leave the
# machine. Prints, per input: the release line, its latest patch, its EOL date,
# the newest LTS line (where the project has LTS) and the newest line overall.
. "$(dirname "$0")/lib.sh"
S=eol
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

for pair in "$@"; do
	prod=${pair%%:*}
	v=$(printf '%s' "${pair#*:}" | sed -E 's/^[^0-9]*//; s/[^0-9.].*$//')
	case "$prod" in *[!a-z0-9-]*) continue ;; esac
	[ -n "$v" ] || continue
	f="$TMP/$prod.json"
	[ -s "$f" ] || run_t 20 curl -fsS -o "$f" "https://endoflife.date/api/$prod.json" 2>/dev/null
	if [ ! -s "$f" ]; then
		row $S "$prod" denied "$v" "endoflife.date lookup failed"
		continue
	fi
	out=$(jsonq "$f" "(function(){var v='$v';var t=new Date().toISOString().slice(0,10);
var live=function(x){return x.eol===false||(typeof x.eol==='string'&&x.eol>t)};
var c=d.filter(function(x){var y=String(x.cycle);return v===y||v.indexOf(y+'.')===0}).sort(function(a,b){return String(b.cycle).length-String(a.cycle).length})[0];
var l=d.filter(function(x){return x.lts&&(x.lts===true||x.lts<=t)&&live(x)})[0];
return [c?c.cycle:'?',c?c.latest:'?',c?String(c.eol):'?',c?(live(c)?'supported':'eol'):'unknown',l?l.cycle+'@'+l.latest:'-',d[0].cycle+'@'+d[0].latest,c?(c.latestReleaseDate||'?'):'?'].join('|')})()")
	IFS='|' read -r cyc latest eol state lts newest rel <<EOF
$out
EOF
	if [ "$state" = eol ]; then
		st=fail
	elif [ "$state" = supported ] && [ "$latest" != "$v" ]; then
		st=warn
	elif [ "$state" = supported ]; then
		st=ok
	else
		st=info
	fi
	row $S "$prod" $st "$v" "line $cyc ($state, eol $eol) latest-in-line $latest (released $rel) | newest-lts $lts | newest $newest"
done
exit 0
