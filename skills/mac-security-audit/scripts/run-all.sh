#!/bin/bash
# Runs every collector into one scan folder and prints its path.
# Usage: run-all.sh [--no-network] [--iocs FILE] [project roots...]
#   --no-network  skip softwareupdate, endoflife.date, registry and CVE lookups
#   --iocs FILE   extra IOC list (references/iocs.tsv format), e.g. one built
#                 from today's advisories
# Read-only. Network calls, when allowed: Apple's update servers, endoflife.date
# (product names only), the npm/PyPI registries, and OSV or npm audit for
# project lockfiles.
DIR=$(cd "$(dirname "$0")" && pwd)
. "$DIR/lib.sh"
NET=1
EXTRA=()
while [ $# -gt 0 ]; do
	case "$1" in
	--no-network)
		NET=0
		shift
		;;
	--iocs)
		EXTRA=(--iocs "$2")
		shift 2
		;;
	*) break ;;
	esac
done
OFF=""
[ $NET = 0 ] && OFF=--no-network

SCAN_DIR=${SCAN_DIR:-${TMPDIR:-/tmp}/mac-security-audit-$(date +%Y%m%d-%H%M%S)}
mkdir -p "$SCAN_DIR"
chmod 700 "$SCAN_DIR"

step() {
	local name=$1
	shift
	local t0=$(date +%s)
	"$@" >"$SCAN_DIR/$name.tsv" 2>"$SCAN_DIR/$name.err"
	printf '%-12s %4ss  %s rows\n' "$name" $(($(date +%s) - t0)) "$(wc -l <"$SCAN_DIR/$name.tsv" | tr -d ' ')"
}

# softwareupdate is slow; start it first in the background.
bash "$DIR/posture.sh" $OFF >"$SCAN_DIR/posture.tsv" 2>"$SCAN_DIR/posture.err" &
POSTURE=$!

step toolchain bash "$DIR/toolchain.sh"
step persistence bash "$DIR/persistence.sh"
step network bash "$DIR/network.sh"
step credentials bash "$DIR/credentials.sh"
step extensions bash "$DIR/extensions.sh"
step devchain bash "$DIR/devchain.sh" "$@"
step ioc bash "$DIR/ioc.sh" --iocs "$DIR/../references/iocs.tsv" ${EXTRA[@]+"${EXTRA[@]}"} "$@"

if [ $NET = 1 ]; then
	step packages bash "$DIR/packages.sh"
	# Support status for what toolchain.sh found.
	pairs="macos:$(sw_vers -productVersion)"
	pairs="$pairs $(awk -F'\t' '$2=="node.installed" || $2=="node" {print "nodejs:" $4}' "$SCAN_DIR/toolchain.tsv" | sort -u | tr '\n' ' ')"
	for t in python3:python openssl:openssl go:go ruby:ruby docker:docker-engine kubectl:kubernetes terraform:terraform php:php; do
		v=$(awk -F'\t' -v id="${t%%:*}" '$2==id && $5 !~ /^\/usr\/bin\// {print $4; exit}' "$SCAN_DIR/toolchain.tsv" | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1)
		[ -n "$v" ] && pairs="$pairs ${t#*:}:$v"
	done
	# shellcheck disable=SC2086
	step eol bash "$DIR/eol.sh" $pairs
	step projects bash "$DIR/projects.sh" "$@"
else
	step packages bash "$DIR/packages.sh" --no-network
fi

wait $POSTURE
printf '%-12s %4s   %s rows\n' posture "" "$(wc -l <"$SCAN_DIR/posture.tsv" | tr -d ' ')"
find "$SCAN_DIR" -name '*.err' -size 0 -delete
echo "SCAN_DIR=$SCAN_DIR"
