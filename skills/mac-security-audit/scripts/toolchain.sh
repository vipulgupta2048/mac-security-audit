#!/bin/bash
# Installed versions of runtimes, package managers and dev tools. Read-only,
# offline. The agent compares these against latest/LTS afterwards (eol.sh).
. "$(dirname "$0")/lib.sh"
S=toolchain

ver() {
	# ver ID COMMAND [ARGS...]: first line of the version output.
	local id=$1
	shift
	have "$1" || return 0
	local out v
	out=$(run_t 10 "$@" 2>&1)
	case "$out" in
	*[Ee]rror* | *Corepack* | *"Unable to"* | *"could not"* | *"not found"* | *ERR_* | *"Network access disabled"*)
		row $S "$id" denied "" "$(command -v "$1"): $(printf '%s' "$out" | grep -v '^[[:space:]]*$' | head -1 | cut -c1-120)"
		return 0
		;;
	esac
	v=$(printf '%s' "$out" | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?([.+-][0-9A-Za-z]+)*' | head -1)
	row $S "$id" info "${v:-$(printf '%s' "$out" | head -1)}" "$(command -v "$1")"
}

ver node node --version
ver npm npm --version
ver pnpm pnpm --version
ver yarn yarn --version
ver bun bun --version
ver deno deno --version
ver python3 python3 --version
ver pip3 pip3 --version
ver uv uv --version
ver go go version
ver rustc rustc --version
ver cargo cargo --version
ver java java -version
ver ruby ruby --version
ver php php --version
ver git git --version
ver gh gh --version
ver docker docker --version
ver orbstack orb version
ver podman podman --version
ver kubectl kubectl version --client
ver terraform terraform version
ver brew brew --version
ver openssl openssl version
ver ssh ssh -V
ver curl curl --version
ver code code --version
ver cursor cursor --version
ver claude claude --version

# Every Node install, not only the one on PATH: old majors linger in version
# managers and still run whatever project selects them.
for d in "$HOME"/.nvm/versions/node/* "$HOME"/.local/share/fnm/node-versions/* "$HOME"/.volta/tools/image/node/* \
	"$HOME"/.asdf/installs/nodejs/* "$HOME"/.local/share/mise/installs/node/* /opt/homebrew/opt/node@*/ /usr/local/opt/node@*/; do
	[ -d "$d" ] || continue
	b=$(find "$d" -maxdepth 3 -type f -name node -path '*/bin/*' 2>/dev/null | head -1)
	[ -n "$b" ] && row $S node.installed info "$("$b" --version 2>/dev/null)" "$b"
done
for d in "$HOME"/.pyenv/versions/* /opt/homebrew/opt/python@*/ /Library/Frameworks/Python.framework/Versions/[0-9]*; do
	[ -d "$d" ] || continue
	b=$(find "$d" -maxdepth 2 -type f -name 'python3*' -path '*/bin/*' 2>/dev/null | head -1)
	[ -n "$b" ] && row $S python.installed info "$("$b" --version 2>&1)" "$b"
done

# Xcode Command Line Tools and Xcode itself.
p=$(xcode-select -p 2>/dev/null)
if [ -n "$p" ]; then
	v=$(pkgutil --pkg-info=com.apple.pkg.CLTools_Executables 2>/dev/null | sed -n 's/^version: //p')
	row $S xcode.clt info "${v:-present}" "$p"
fi
[ -d /Applications/Xcode.app ] && row $S xcode info "$(defaults read /Applications/Xcode.app/Contents/Info.plist CFBundleShortVersionString 2>/dev/null)" ""

# GUI apps that update themselves (or don't): version from the bundle.
for app in "Google Chrome" Firefox "Brave Browser" "Microsoft Edge" Arc Safari "Visual Studio Code" Cursor Windsurf Zed \
	Docker OrbStack Slack zoom.us "Microsoft Teams" Discord 1Password Bitwarden Signal WhatsApp Claude ChatGPT Postman iTerm Warp Ghostty; do
	for base in /Applications "$HOME/Applications"; do
		pl="$base/$app.app/Contents/Info.plist"
		[ -f "$pl" ] || continue
		v=$(defaults read "$pl" CFBundleShortVersionString 2>/dev/null)
		row $S "app.$(printf '%s' "$app" | tr ' A-Z' '-a-z')" info "$v" "$base/$app.app"
	done
done
exit 0
