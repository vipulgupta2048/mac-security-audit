# Shared helpers for the collectors. Source it, don't run it.
# Bash 3.2 compatible (the /bin/bash every Mac ships): no associative arrays,
# no mapfile, no ${var,,}.

# Every collector prints rows of five tab-separated fields:
#   section  id  status  value  detail
# status is one of: ok warn fail info denied
row() {
	local s=$1 id=$2 st=$3 v=$4 d=${5:-}
	v=$(printf '%s' "$v" | tr '\t\n' '  ' | redact)
	d=$(printf '%s' "$d" | tr '\t\n' '  ' | redact)
	printf '%s\t%s\t%s\t%s\t%s\n' "$s" "$id" "$st" "$v" "$d"
}

# Masks anything that looks like a credential. Everything a collector prints
# goes through this, so a token in a process name or a config value never
# reaches the report.
redact() {
	sed -E \
		-e 's/(gh[pousr]_|github_pat_)[A-Za-z0-9_]{10,}/\1<redacted>/g' \
		-e 's/npm_[A-Za-z0-9]{20,}/npm_<redacted>/g' \
		-e 's/sk-[A-Za-z0-9_-]{16,}/sk-<redacted>/g' \
		-e 's/(AKIA|ASIA)[A-Z0-9]{16}/\1<redacted>/g' \
		-e 's/xox[abprs]-[A-Za-z0-9-]{10,}/xox-<redacted>/g' \
		-e 's/[Bb]earer [A-Za-z0-9._~+\/=-]{8,}/Bearer <redacted>/g' \
		-e 's/(_authToken|[Tt]oken|[Ss]ecret|[Pp]assword|[Pp]asswd|api[_-]?[Kk]ey)("?[[:space:]]*[=:][[:space:]]*"?)[^"[:space:]&]{4,}/\1\2<redacted>/g' \
		-e 's/(--(api-key|token|password|secret))[[:space:]]+[^[:space:]-][^[:space:]]{3,}/\1 <redacted>/g' \
		-e 's#(://[^:/@[:space:]]+:)[^@/[:space:]]+@#\1<redacted>@#g'
}

# Runs a command with a time limit. macOS has no `timeout`; perl ships with it.
run_t() {
	local secs=$1
	shift
	if command -v perl >/dev/null 2>&1; then
		perl -e 'alarm shift; exec @ARGV or exit 127' "$secs" "$@"
	else
		"$@"
	fi
}

# True when a tool is present and not one of Apple's CLT stubs that open an
# install dialog (/usr/bin/git, /usr/bin/python3 without Command Line Tools).
have() {
	local p
	p=$(command -v "$1" 2>/dev/null) || return 1
	case "$p" in
	/usr/bin/git | /usr/bin/python3 | /usr/bin/pip3 | /usr/bin/make | /usr/bin/clang)
		xcode-select -p >/dev/null 2>&1 || return 1
		;;
	/usr/bin/java | /usr/bin/javac)
		/usr/libexec/java_home >/dev/null 2>&1 || return 1
		;;
	esac
	return 0
}

# Corepack shims (yarn, pnpm) download a package manager on first use. Make
# them fail instead, so asking for a version never fetches anything.
export COREPACK_ENABLE_NETWORK=0 COREPACK_ENABLE_DOWNLOAD_PROMPT=0

# Reads JSON without jq: `jsonq FILE 'JS expression over d'`. The expression
# comes from our own scripts only, never from the scanned files.
jsonq() {
	osascript -l JavaScript "$LIB_DIR/jsonq.js" "$1" "$2" 2>/dev/null
}

# File mode as an octal string, e.g. 600.
mode_of() { stat -f '%Lp' "$1" 2>/dev/null; }

# Modification date as YYYY-MM-DD.
mtime() { stat -f '%Sm' -t '%Y-%m-%d' "$1" 2>/dev/null; }

# Code-signing identity of a binary: TeamIdentifier, "apple", "adhoc" or
# "unsigned".
signer() {
	local out
	out=$(run_t 10 codesign -dv --verbose=2 "$1" 2>&1) || {
		printf 'unsigned'
		return
	}
	case "$out" in
	*"Authority=Software Signing"*) printf 'apple' ;;
	*"Signature=adhoc"*) printf 'adhoc' ;;
	*TeamIdentifier=*) printf '%s' "$out" | sed -n 's/^TeamIdentifier=//p' | head -1 ;;
	*) printf 'unsigned' ;;
	esac
}

# Project roots to scan: arguments, else the usual code folders that exist.
# Never the home folder itself: iCloud and cloud mounts under it make a
# recursive walk crawl.
project_roots() {
	if [ $# -gt 0 ]; then
		printf '%s\n' "$@"
		return
	fi
	local d
	for d in work code dev src projects repos git Developer Projects Code Sites; do
		[ -d "$HOME/$d" ] && printf '%s\n' "$HOME/$d"
	done
}

LIB_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
export LIB_DIR
