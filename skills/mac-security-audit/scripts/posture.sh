#!/bin/bash
# OS security settings. Read-only, no sudo. Usage: posture.sh [--no-network]
. "$(dirname "$0")/lib.sh"
NET=1
[ "${1:-}" = --no-network ] && NET=0
S=posture

row $S os.version info "$(sw_vers -productVersion) ($(sw_vers -buildVersion))" "$(uname -m)"

if [ $NET = 1 ]; then
	# Asks Apple's servers what is pending. Lists only; never installs.
	out=$(run_t 180 softwareupdate --list 2>&1)
	if [ $? -gt 1 ] || [ -z "$out" ]; then
		row $S os.pending denied "" "softwareupdate --list failed or timed out"
	else
		n=0
		while IFS= read -r line; do
			case "$line" in
			*Title:*)
				n=$((n + 1))
				title=$(printf '%s' "$line" | sed -E 's/.*Title: ([^,]*), Version: ([^,]*).*Recommended: ([A-Z]*).*/\1 \2 recommended=\3/')
				row $S os.pending warn "$title" ""
				;;
			esac
		done <<EOF
$out
EOF
		[ $n = 0 ] && row $S os.pending ok "none" ""
	fi
fi

out=$(csrutil status 2>&1)
case "$out" in
*"status: enabled"*) row $S sip ok enabled "" ;;
*) row $S sip fail "$out" "" ;;
esac

out=$(spctl --status 2>&1)
case "$out" in
*"assessments enabled"*) row $S gatekeeper ok enabled "" ;;
*) row $S gatekeeper fail "$out" "" ;;
esac

out=$(fdesetup status 2>&1)
case "$out" in
*"FileVault is On"*) row $S filevault ok on "" ;;
*"FileVault is Off"*) row $S filevault fail off "" ;;
*) row $S filevault denied "" "$out" ;;
esac

FW=/usr/libexec/ApplicationFirewall/socketfilterfw
out=$($FW --getglobalstate 2>&1)
case "$out" in
*enabled* | *"State = 1"* | *"State = 2"*) row $S firewall ok enabled "" ;;
*disabled* | *"State = 0"*) row $S firewall fail disabled "" ;;
*) row $S firewall denied "" "$out" ;;
esac
out=$($FW --getstealthmode 2>&1)
case "$out" in
*" on"* | *enabled*) row $S firewall.stealth ok on "" ;;
*) row $S firewall.stealth warn off "" ;;
esac

# XProtect: the data version and how old it is. macOS 15+ has /usr/bin/xprotect.
if [ -x /usr/bin/xprotect ]; then
	v=$(run_t 20 /usr/bin/xprotect version 2>/dev/null | tr '\n' ' ')
	row $S xprotect info "$v" ""
fi
for b in /Library/Apple/System/Library/CoreServices/XProtect.bundle /Library/Apple/System/Library/CoreServices/XProtect.app; do
	if [ -d "$b" ]; then
		v=$(defaults read "$b/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null)
		row $S xprotect.bundle info "$v" "updated $(mtime "$b/Contents/Info.plist")"
	fi
done

# Automatic updates. A missing key means the macOS default (on).
SU=/Library/Preferences/com.apple.SoftwareUpdate
for k in AutomaticCheckEnabled AutomaticDownload CriticalUpdateInstall ConfigDataInstall AutomaticallyInstallMacOSUpdates; do
	v=$(defaults read $SU $k 2>/dev/null)
	case "$v" in
	0) row $S "autoupdate.$k" warn off "" ;;
	1) row $S "autoupdate.$k" ok on "" ;;
	*) row $S "autoupdate.$k" info default "" ;;
	esac
done

out=$(sysadminctl -screenLock status 2>&1)
case "$out" in
*immediate*) row $S screenlock ok immediate "" ;;
*off*) row $S screenlock fail off "" ;;
*) row $S screenlock warn "$(printf '%s' "$out" | sed -n 's/.*screenLock delay is //p')" "delay before password" ;;
esac

LW=/Library/Preferences/com.apple.loginwindow
v=$(defaults read $LW autoLoginUser 2>/dev/null)
if [ -n "$v" ]; then row $S autologin fail "on" ""; else row $S autologin ok off ""; fi
v=$(defaults read $LW GuestEnabled 2>/dev/null)
if [ "$v" = 1 ]; then row $S guest warn on ""; else row $S guest ok off ""; fi

if dsmemberutil checkmembership -U "$USER" -G admin 2>/dev/null | grep -q 'is a member'; then
	row $S user.admin info "admin" "daily use of an admin account"
else
	row $S user.admin ok standard ""
fi

v=$(defaults read com.apple.sharingd DiscoverableMode 2>/dev/null)
case "$v" in
Everyone) row $S airdrop warn Everyone "" ;;
*) row $S airdrop ok "${v:-Contacts Only}" "" ;;
esac

# MDM enrollment changes who else can manage the Mac. Keep the server's host
# only; the URL path carries device identifiers.
out=$(profiles status -type enrollment 2>&1 | sed -E 's#(https?://[^/[:space:]]+)[^[:space:]]*#\1#g' | tr '\n' ' ')
row $S mdm info "$out" ""

# Lockdown Mode and Touch ID for sudo are informational.
grep -qs pam_tid /etc/pam.d/sudo_local /etc/pam.d/sudo && row $S sudo.touchid ok on "" || row $S sudo.touchid info off ""

# Gatekeeper-style approvals: system and user extensions from third parties.
out=$(run_t 20 systemextensionsctl list 2>/dev/null)
printf '%s\n' "$out" | awk -F'\t' 'NF>=5 && $0 ~ /activated/ {print $3 "\t" $4}' | while IFS="$(printf '\t')" read -r team bundle; do
	row $S sysext info "$bundle" "team $team"
done
exit 0
