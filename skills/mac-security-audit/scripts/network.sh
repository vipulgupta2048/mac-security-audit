#!/bin/bash
# Network exposure: listening sockets, sharing services, DNS and proxies,
# trusted certificates someone added, /etc/hosts. Read-only, no sudo.
. "$(dirname "$0")/lib.sh"
S=network

# netstat sees every listener (including root's) but not the owner; lsof names
# the process for sockets this user owns.
owners=$(lsof +c 0 -nP -iTCP -sTCP:LISTEN 2>/dev/null | awk 'NR>1 {split($9,a,":"); print a[length(a)] " " $1}' | sort -u)
netstat -anv -p tcp 2>/dev/null | awk '$6=="LISTEN" {print $4}' | sort -u | while IFS= read -r addr; do
	port=${addr##*.}
	host=${addr%.*}
	proc=$(printf '%s\n' "$owners" | awk -v p="$port" '$1==p {print $2}' | sort -u | tr '\n' ',' | sed 's/,$//')
	case "$host" in
	127.0.0.1 | ::1 | localhost | fe80::1%lo0) st=ok scope=loopback ;;
	*) st=warn scope=all-interfaces ;;
	esac
	svc=""
	case "$port" in
	22) svc="Remote Login (SSH)" ;;
	88) svc="Kerberos (sharing)" ;;
	445) svc="File Sharing (SMB)" ;;
	548) svc="File Sharing (AFP)" ;;
	3031) svc="Remote Apple Events" ;;
	3283) svc="Remote Management" ;;
	5900) svc="Screen Sharing" ;;
	7000 | 5000) svc="AirPlay Receiver" ;;
	esac
	[ -n "$proc" ] || proc="owned by another user"
	[ -n "$svc" ] && scope="$scope | $svc"
	row $S listen $st "$host:$port" "$scope | process $proc"
done

# DNS servers and proxies in effect.
dns=$(scutil --dns 2>/dev/null | awk '/nameserver\[[0-9]+\]/ {print $3}' | sort -u | tr '\n' ' ')
row $S dns info "$dns" ""
px=$(scutil --proxy 2>/dev/null)
for k in HTTPEnable HTTPSEnable SOCKSEnable ProxyAutoConfigEnable; do
	printf '%s\n' "$px" | grep -q "$k : 1" && row $S proxy warn "$k" "$(printf '%s\n' "$px" | grep -E 'Proxy :|Port :|URLString' | tr -s ' ' | tr '\n' ' ')"
done

# Certificates given custom trust: a root here can read TLS traffic.
for scope in user admin; do
	flag=""
	[ $scope = admin ] && flag=-d
	security dump-trust-settings $flag 2>/dev/null | sed -n 's/^Cert [0-9]*: //p' | while IFS= read -r cn; do
		row $S trusted.cert warn "$cn" "custom trust ($scope domain)"
	done
done

# Non-default /etc/hosts entries.
n=$(grep -vE '^[[:space:]]*(#|$)|^(127\.0\.0\.1|255\.255\.255\.255|::1|fe80::1%lo0)[[:space:]]+(localhost|broadcasthost)' /etc/hosts 2>/dev/null | wc -l | tr -d ' ')
[ "$n" -gt 0 ] && row $S hosts info "$n custom entries" "/etc/hosts" || row $S hosts ok default ""
exit 0
