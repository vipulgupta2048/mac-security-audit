#!/bin/bash
# Where credentials sit on disk, and how they're protected. Reports presence,
# permissions and key types only: it never prints a secret or a file's content.
. "$(dirname "$0")/lib.sh"
S=credentials

# SSH private keys: type, strength, passphrase, permissions.
if [ -d "$HOME/.ssh" ]; then
	m=$(mode_of "$HOME/.ssh")
	[ "$m" = 700 ] && row $S ssh.dir ok "$m" "" || row $S ssh.dir warn "$m" "~/.ssh should be 700"
	for k in "$HOME"/.ssh/*; do
		[ -f "$k" ] || continue
		head -1 "$k" 2>/dev/null | grep -q 'PRIVATE KEY' || continue
		m=$(mode_of "$k")
		fp=$(ssh-keygen -l -f "$k" 2>/dev/null | awk '{print $1 "-bit " $NF}')
		# Deriving the public key with an empty passphrase only works when the
		# key has none. Output goes nowhere.
		if ssh-keygen -y -P '' -f "$k" >/dev/null 2>&1; then enc=no-passphrase; else enc=passphrase; fi
		st=ok
		[ $enc = no-passphrase ] && st=warn
		case "$fp" in *RSA*) b=${fp%%-bit*}; [ "${b:-0}" -lt 3072 ] && st=warn ;; *DSA* | *ECDSA*) st=warn ;; esac
		[ "$m" != 600 ] && [ "$m" != 400 ] && st=fail
		row $S ssh.key $st "$(basename "$k")" "${fp:-unknown type} | $enc | mode $m"
	done
	[ -f "$HOME/.ssh/authorized_keys" ] && row $S ssh.authorized_keys warn "$(grep -c . "$HOME/.ssh/authorized_keys") keys" "others can log in to this Mac if Remote Login is on"
	if [ -f "$HOME/.ssh/config" ]; then
		grep -niE '^[[:space:]]*StrictHostKeyChecking[[:space:]]+no' "$HOME/.ssh/config" | cut -d: -f1 | while read -r l; do row $S ssh.config warn "StrictHostKeyChecking no" "line $l"; done
		grep -niE '^[[:space:]]*ForwardAgent[[:space:]]+yes' "$HOME/.ssh/config" | cut -d: -f1 | while read -r l; do row $S ssh.config warn "ForwardAgent yes" "line $l"; done
	fi
fi

# Plaintext credential stores. `marker` is a pattern that means a secret is
# actually stored in the file, not just configuration.
check() {
	local id=$1 f=$2 marker=$3 m st
	[ -f "$f" ] || return 0
	m=$(mode_of "$f")
	if [ -n "$marker" ] && ! grep -qE "$marker" "$f" 2>/dev/null; then
		row $S "$id" info "present, no stored secret" "$f mode $m"
		return 0
	fi
	st=warn
	case "$m" in 600 | 400) ;; *) st=fail ;; esac
	row $S "$id" $st "plaintext secret on disk" "$f mode $m"
}
check npmrc "$HOME/.npmrc" '_authToken|_auth[[:space:]]*=|_password'
check yarnrc "$HOME/.yarnrc.yml" 'npmAuthToken'
check netrc "$HOME/.netrc" 'password'
check git-credentials "$HOME/.git-credentials" '://'
check pypirc "$HOME/.pypirc" 'password'
check aws "$HOME/.aws/credentials" 'aws_secret_access_key'
check docker "$HOME/.docker/config.json" '"auth"[[:space:]]*:[[:space:]]*"[^"]'
check gh "$HOME/.config/gh/hosts.yml" 'oauth_token'
check kube "$HOME/.kube/config" 'token:|client-key-data'
check gcloud "$HOME/.config/gcloud/application_default_credentials.json" 'refresh_token|private_key'
check azure "$HOME/.azure/msal_token_cache.json" 'secret'
check cargo "$HOME/.cargo/credentials.toml" 'token'
check gem "$HOME/.gem/credentials" 'api_key'
check claude "$HOME/.claude/.credentials.json" 'accessToken'

# Git: how credentials and signing are set up.
if have git; then
	h=$(git config --global credential.helper 2>/dev/null)
	case "$h" in
	store*) row $S git.credential.helper fail store "passwords saved in plaintext ~/.git-credentials" ;;
	"") row $S git.credential.helper info none "" ;;
	*) row $S git.credential.helper ok "$h" "" ;;
	esac
	s=$(git config --global commit.gpgsign 2>/dev/null)
	row $S git.signing info "${s:-false}" "$(git config --global gpg.format 2>/dev/null)"
fi
exit 0
