#!/bin/bash
# Self-tests for the parts that must not regress: IOC matching across every
# lockfile format, and secret redaction. Run: bash tests/selftest.sh
cd "$(dirname "$0")/.." || exit 1
SCRIPTS=skills/mac-security-audit/scripts
. "$SCRIPTS/lib.sh"
fails=0
pass() { printf 'ok   %s\n' "$1"; }
fail() {
	printf 'FAIL %s\n' "$1"
	fails=$((fails + 1))
}

# IOC matching: exactly these hits, nothing from the look-alikes.
want='@cacheable/utils@2.5.1
@cap-js/sqlite@2.2.2
@tanstack/history@1.161.12
flat-cache@6.1.24
function-flag@2.3.7
keyv@6.0.0
mistralai@2.4.6
node-ipc@9.2.3
tensorlake@0.5.144
xinference@2.6.0
xinference@2.6.1'
got=$(bash "$SCRIPTS/ioc.sh" tests/fixtures | awk -F'\t' '$2 ~ /^package\./ && $3=="fail" {print $4}' | sort)
[ "$got" = "$want" ] && pass "ioc matches all lockfile formats" || {
	fail "ioc matches"
	diff <(printf '%s\n' "$want") <(printf '%s\n' "$got")
}
bash "$SCRIPTS/ioc.sh" tests/fixtures/clean | grep -q $'\tpackage\tok\t' && pass "ioc clean project has no hits" || fail "ioc clean project"

# Redaction.
check() {
	local name=$1 in=$2 out=$3 got
	got=$(printf '%s' "$in" | redact)
	[ "$got" = "$out" ] && pass "redact $name" || fail "redact $name: got [$got]"
}
check github 'token ghp_abcdefghijklmnopqrstuvwx1234' 'token ghp_<redacted>'
check npm '//registry.npmjs.org/:_authToken=npm_abcdefghijklmnopqrstuvwxyz12' '//registry.npmjs.org/:_authToken=<redacted>'
check openai 'OPENAI sk-proj-abcdefghijklmnopqrst' 'OPENAI sk-<redacted>'
check aws 'AKIAABCDEFGHIJKLMNOP' 'AKIA<redacted>'
check bearer 'Authorization: Bearer abc.def.ghi123' 'Authorization: Bearer <redacted>'
check url 'https://user:hunter2@example.com/x' 'https://user:<redacted>@example.com/x'
check apikey '--api-key=abcd1234' '--api-key=<redacted>'
check plain 'nothing secret here' 'nothing secret here'

# Every collector must parse and must not contain a write or install command.
for f in "$SCRIPTS"/*.sh; do
	bash -n "$f" || fail "syntax $f"
	if grep -nE '(^|[;&|[:space:]])(sudo|rm -rf /|brew (install|upgrade|update)|npm (install|i|ci|update)([[:space:]]|$)|pip3? install|softwareupdate -i|defaults write|launchctl (load|unload|bootstrap|bootout)|tccutil|kill )' "$f" | grep -vE '^[0-9]+:[[:space:]]*#' | grep -vE 'need[s]?:|row |echo |printf ' >/dev/null; then
		fail "write command in $f"
	fi
done
pass "collectors parse and stay read-only"

[ $fails -eq 0 ] && echo "all tests passed" || {
	echo "$fails failed"
	exit 1
}
