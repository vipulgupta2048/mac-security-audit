#!/bin/bash
# Matches this Mac against known-bad package versions, extension ids and file
# paths. Read-only, offline.
# Usage: ioc.sh [--iocs FILE]... [project roots...]
#   --iocs defaults to references/iocs.tsv; pass it again to add a list you
#   built from today's advisories (same format).
# Exact name@version matching only: a clean report means "none of the listed
# versions", not "no malware".
. "$(dirname "$0")/lib.sh"
S=ioc
IOCS=""
ROOTS=""
while [ $# -gt 0 ]; do
	case "$1" in
	--iocs)
		IOCS="$IOCS
$2"
		shift 2
		;;
	*)
		ROOTS="$ROOTS
$1"
		shift
		;;
	esac
done
[ -n "$IOCS" ] || IOCS=$(cd "$LIB_DIR/../references" && pwd)/iocs.tsv
# fd 3 keeps the real stdout for rows printed inside redirected loops.
exec 3>&1
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# One table of type<TAB>name<TAB>versions<TAB>incident<TAB>source.
printf '%s\n' "$IOCS" | while IFS= read -r f; do
	[ -n "$f" ] || continue
	[ -f "$f" ] || { row $S iocs.missing warn "$f" "IOC file not found; its entries were not checked" >&3; continue; }
	awk -F'\t' '$1 !~ /^#/ && $1 != "type" && NF>=6 {print $1 "\t" $2 "\t" $3 "\t" $4 " (" $5 ")\t" $6}' "$f"
done >"$TMP/iocs"
row $S iocs.loaded info "$(wc -l <"$TMP/iocs" | tr -d ' ') entries" "$(printf '%s' "$IOCS" | tr '\n' ' ')"


# Pull name<TAB>version pairs out of every lockfile under the roots.
: >"$TMP/npm"
: >"$TMP/pypi"
counts=""
# shellcheck disable=SC2086
roots=$(printf '%s\n' "$ROOTS" | sed '/^$/d')
[ -n "$roots" ] || roots=$(project_roots)
printf '%s\n' "$roots" | while IFS= read -r root; do
	[ -d "$root" ] || continue
	find "$root" -maxdepth 6 \( -name node_modules -o -name .git -o -name .venv -o -name venv -o -name vendor \) -prune -o -type f \
		\( -name pnpm-lock.yaml -o -name package-lock.json -o -name npm-shrinkwrap.json -o -name yarn.lock -o -name bun.lock \
		-o -name 'requirements*.txt' -o -name poetry.lock -o -name uv.lock \) -print 2>/dev/null
done >"$TMP/lockfiles"

while IFS= read -r f; do
	case "$f" in
	*pnpm-lock.yaml)
		sed -nE "s#^  '?/?((@[^/@' ]+/)?[^/@' ]+)[@/]([0-9][^:'( ]*).*#\1	\3	$f#p" "$f" >>"$TMP/npm"
		;;
	*package-lock.json | *npm-shrinkwrap.json)
		jsonq "$f" "Object.keys(d.packages||{}).filter(function(k){return k&&d.packages[k].version}).map(function(k){return k.replace(/^.*node_modules\//,'')+'\t'+d.packages[k].version}).concat(Object.keys(d.dependencies||{}).map(function(k){return k+'\t'+d.dependencies[k].version}))" |
			awk -v f="$f" '{print $0 "\t" f}' >>"$TMP/npm"
		;;
	*yarn.lock)
		awk -v f="$f" '
			/^[^ #]/ { spec=$0; sub(/:$/, "", spec); split(spec, a, ", "); s=a[1]; gsub(/"/, "", s); n=s; sub(/@[^@]*$/, "", n); name=n; next }
			/^  version:? / { v=$2; gsub(/"/, "", v); if (name != "") print name "\t" v "\t" f; name="" }' "$f" >>"$TMP/npm"
		;;
	*bun.lock)
		grep -oE '\["(@?[^"@]+)@([0-9][^"]*)"' "$f" | sed -E "s#^\[\"(@?[^\"@]+)@([^\"]*)\"#\1	\2	$f#" >>"$TMP/npm"
		;;
	*requirements*.txt)
		sed -nE "s#^[[:space:]]*([A-Za-z0-9_.-]+)(\[[^]]*\])?[[:space:]]*==[[:space:]]*([^ ;\#]+).*#\1	\3	$f#p" "$f" >>"$TMP/pypi"
		;;
	*poetry.lock | *uv.lock)
		awk -v f="$f" '/^name = / {n=$3; gsub(/"/,"",n)} /^version = / && n!="" {v=$3; gsub(/"/,"",v); print n "\t" v "\t" f; n=""}' "$f" >>"$TMP/pypi"
		;;
	esac
done <"$TMP/lockfiles"

# Globally installed npm packages, nested dependencies included.
for g in "$HOME"/.nvm/versions/node/*/lib/node_modules /opt/homebrew/lib/node_modules /usr/local/lib/node_modules \
	"$HOME/.npm-global/lib/node_modules" "$HOME/.bun/install/global/node_modules"; do
	[ -d "$g" ] || continue
	# One awk over every package.json: the package name is the path after the
	# last node_modules/, the version is the first "version" key.
	find "$g" -maxdepth 8 -name package.json -path '*/node_modules/*' -not -path '*/test/*' -print0 2>/dev/null |
		xargs -0 awk '
			FNR==1 { done=0; d=FILENAME; sub(/\/package\.json$/, "", d); n=d; sub(/.*\/node_modules\//, "", n)
				bad = (n ~ /\/.*\// || (n ~ /\// && n !~ /^@/)) }
			!done && !bad && /^[[:space:]]*"version"[[:space:]]*:/ { v=$0; sub(/^[^:]*:[[:space:]]*"/, "", v); sub(/".*/, "", v); print n "\t" v "\t" d; done=1 }'
done >>"$TMP/npm"

# Installed Python distributions.
for sp in /opt/homebrew/lib/python3*/site-packages /usr/local/lib/python3*/site-packages "$HOME"/Library/Python/*/lib/python/site-packages \
	"$HOME"/.pyenv/versions/*/lib/python3*/site-packages; do
	[ -d "$sp" ] || continue
	for di in "$sp"/*.dist-info; do
		[ -d "$di" ] || continue
		b=$(basename "$di" .dist-info)
		printf '%s\t%s\t%s\n' "${b%-*}" "${b##*-}" "$sp"
	done
done >>"$TMP/pypi"

awk -F'\t' '{ n=tolower($1); gsub(/[-_.]+/, "-", n); print n "\t" $2 "\t" $3 }' "$TMP/pypi" >"$TMP/pypi.n"

row $S coverage info "$(wc -l <"$TMP/lockfiles" | tr -d ' ') lockfiles" "$(wc -l <"$TMP/npm" | tr -d ' ') npm entries, $(wc -l <"$TMP/pypi" | tr -d ' ') python entries; roots: $(printf '%s' "$roots" | tr '\n' ' ')"

# Join packages against the IOC table.
match() {
	local type=$1 data=$2
	awk -F'\t' -v t="$type" -v norm="$([ "$type" = pypi ] && echo 1)" '
		function pn(s) { s=tolower(s); gsub(/[-_.]+/, "-", s); return s }
		FNR==NR { if ($1==t) { k=(norm ? pn($2) : $2); vers[k]=$3; inc[k]=$4; src[k]=$5 } next }
		($1 in vers) {
			hit = (vers[$1]=="*")
			if (!hit) { n=split(vers[$1], vs, ","); for (i=1;i<=n;i++) if (vs[i]==$2) hit=1 }
			if (hit) print $1 "@" $2 "\t" inc[$1] " | " $3 " | " src[$1]
		}' "$TMP/iocs" "$data" | sort -u
}
hits=0
for t in npm pypi; do
	data="$TMP/npm"
	[ $t = pypi ] && data="$TMP/pypi.n"
	match $t "$data" >"$TMP/hits.$t"
	while IFS="$(printf '\t')" read -r pkg detail; do
		row $S "package.$t" fail "$pkg" "$detail"
	done <"$TMP/hits.$t"
	hits=$((hits + $(wc -l <"$TMP/hits.$t")))
done

# Extension ids (VS Code family: publisher.name; Chromium: 32-char id).
awk -F'\t' '$1=="vscode" || $1=="chrome" {print $1 "\t" tolower($2) "\t" $4 "\t" $5}' "$TMP/iocs" | while IFS="$(printf '\t')" read -r t id inc src; do
	if [ "$t" = vscode ]; then
		set -- "$HOME"/.vscode/extensions/"$id"-* "$HOME"/.cursor/extensions/"$id"-* "$HOME"/.windsurf/extensions/"$id"-* "$HOME"/.vscode-insiders/extensions/"$id"-*
	else
		set -- "$HOME"/Library/Application\ Support/*/*/*/Extensions/"$id" "$HOME"/Library/Application\ Support/*/*/Extensions/"$id"
	fi
	for p in "$@"; do [ -e "$p" ] && row $S extension fail "$id" "$inc | $p | $src"; done
done

# Host files and folders malware leaves behind.
awk -F'\t' '$1=="path" {print $2 "\t" $4 "\t" $5}' "$TMP/iocs" | while IFS="$(printf '\t')" read -r p inc src; do
	p=$(printf '%s' "$p" | sed -e "s#^~#$HOME#" -e "s#\$TMPDIR#${TMPDIR%/}#")
	for x in $p; do [ -e "$x" ] && row $S path fail "$x" "$inc | $src"; done
done

[ $hits -eq 0 ] && row $S package ok "no listed versions found" "exact matches only; see coverage row"
exit 0
