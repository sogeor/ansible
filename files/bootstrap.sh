#!/usr/bin/env bash
# Bring an installed Debian or Ubuntu server to the same state as user-data.yaml, ready for Ansible:
# user "ansible" (SSH certificates + break-glass key), SSH on 822 only, nftables, root locked.
# Provider-neutral: works on Selectel dedicated/VDS and any other KVM VPS with systemd.
#
# Run from the workstation as root (or as a sudo user with "sudo bash -s"):
#   ssh root@<IP> "bash -s -- <hostname> '<user CA public key>' '<break-glass public key>'" < bootstrap.sh
#
# Optional environment (put before "bash -s"):
#   DOMAIN=sogeor.com            FQDN suffix
#   ROOT_PASSWORD_HASH='$6$...'  root password for the provider console only (SSH root stays off);
#                                without it root is locked completely
#   BOOTSTRAP_REBOOT=no          do not reboot automatically when the upgrade requires it
#
# The current session survives; new logins work only as ansible@<IP>:822.
set -euo pipefail

HOST="${1:?usage: bootstrap.sh <hostname> <user CA public key> <break-glass public key>}"
USER_CA="${2:?user CA public key}"
BREAK_GLASS="${3:?break-glass public key}"
DOMAIN="${DOMAIN:-sogeor.com}"
SSH_PORT=822
WG_PORT=51820
SSHD_DROPIN=/etc/ssh/sshd_config.d/00-sogeor.conf
SOCKET_DROPIN=/etc/systemd/system/ssh.socket.d/10-port.conf

log()  { printf '\n==> %s\n' "$*"; }
warn() { printf 'WARNING: %s\n' "$*" >&2; }
die()  { printf '\nERROR: %s\n' "$*" >&2; exit 1; }
revert_ssh() { rm -f "$SSHD_DROPIN" "$SOCKET_DROPIN"; }

# --- Checks -------------------------------------------------------------------
[ "$(id -u)" -eq 0 ] || die "run as root"
[ -r /etc/os-release ] || die "/etc/os-release not found"
. /etc/os-release
case "${ID:-}" in debian|ubuntu) ;; *) die "unsupported OS: ${ID:-unknown} (Debian or Ubuntu only)" ;; esac
[ -d /run/systemd/system ] || die "systemd is required"
[[ "$HOST" =~ ^[a-z][a-z0-9-]{0,62}$ ]] || die "invalid hostname: $HOST"
[[ "$DOMAIN" =~ ^[a-z0-9.-]+$ ]] || die "invalid domain: $DOMAIN"
check_key() { ssh-keygen -lf /dev/stdin <<<"$2" >/dev/null 2>&1 || die "$1 is not a valid SSH public key"; }
check_key "user CA key" "$USER_CA"
check_key "break-glass key" "$BREAK_GLASS"
[ "$USER_CA" != "$BREAK_GLASS" ] || die "user CA and break-glass keys must differ"

# --- Hostname, time zone, cloud-init --------------------------------------------
log "Hostname and time zone"
if ! hostnamectl set-hostname "$HOST" 2>/dev/null; then
  printf '%s\n' "$HOST" > /etc/hostname
  hostname "$HOST"
fi
# Provider images put the hostname on the localhost lines ("127.0.0.1 localhost zelda"),
# so hostname -f returns "localhost". Keep it only on our 127.0.1.1 line.
sed -i -e '$a\' /etc/hosts
sed -i -E \
  -e '/^127\.0\.1\.1[[:space:]]/d' \
  -e ':a' \
  -e "/^[0-9a-fA-F.:]+[[:space:]]/ s/[[:space:]]+${HOST}(\.${DOMAIN//./\\.})?([[:space:]]|\$)/\2/" \
  -e 'ta' \
  -e '/^[0-9a-fA-F.:]+[[:space:]]*$/d' \
  /etc/hosts
printf '127.0.1.1 %s.%s %s\n' "$HOST" "$DOMAIN" "$HOST" >> /etc/hosts

# cloud-init merges cloud.cfg.d in name order; "99_zz" sorts after provider files (Selectel: 99_*).
# Overrides provider defaults in case per-instance modules run again (new instance-id).
if [ -d /etc/cloud/cloud.cfg.d ]; then
  rm -f /etc/cloud/cloud.cfg.d/99-sogeor.cfg
  cat > /etc/cloud/cloud.cfg.d/99_zz_sogeor.cfg <<'CFG'
#cloud-config
disable_root: true
manage_etc_hosts: false
preserve_hostname: true
ssh_deletekeys: false
ssh_pwauth: false
CFG
fi

if ! timedatectl set-timezone Etc/UTC 2>/dev/null; then
  ln -sf /usr/share/zoneinfo/Etc/UTC /etc/localtime
  printf 'Etc/UTC\n' > /etc/timezone
fi

# --- Packages -----------------------------------------------------------------
log "Packages"
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=l            # Ubuntu: list services to restart, do not restart them now
APT_OPTS=(-y -o Acquire::Retries=3 -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold)
apt-get "${APT_OPTS[@]}" update
apt-get "${APT_OPTS[@]}" full-upgrade
apt-get "${APT_OPTS[@]}" install \
  ca-certificates curl iproute2 nftables openssh-server python3 python3-apt sudo wireguard-tools

# Other firewall managers would fight with our nftables table
if command -v ufw >/dev/null; then ufw disable >/dev/null 2>&1 || true; fi
for p in ufw firewalld; do
  if dpkg -s "$p" >/dev/null 2>&1; then apt-get "${APT_OPTS[@]}" purge "$p"; fi
done
if dpkg -s netfilter-persistent >/dev/null 2>&1; then
  warn "netfilter-persistent is installed: its saved iptables rules also apply at boot; review /etc/iptables/"
fi

# --- User ansible ---------------------------------------------------------------
log "User ansible"
id ansible >/dev/null 2>&1 || useradd -m -s /bin/bash -c "Ansible automation" ansible
usermod -aG sudo ansible
# "*" = no password; unlike "!" (locked) it does not block key logins when sshd runs with UsePAM no
usermod -p '*' ansible
install -d -m 0700 -o ansible -g ansible /home/ansible/.ssh
printf '%s\n' "$BREAK_GLASS" > /home/ansible/.ssh/authorized_keys
chown ansible:ansible /home/ansible/.ssh/authorized_keys
chmod 0600 /home/ansible/.ssh/authorized_keys

tmp="$(mktemp)"
printf 'ansible ALL=(ALL) NOPASSWD:ALL\n' > "$tmp"
visudo -cf "$tmp" >/dev/null || { rm -f "$tmp"; die "sudoers rule rejected"; }
install -m 0440 -o root -g root "$tmp" /etc/sudoers.d/90-ansible
rm -f "$tmp"

# --- SSH ------------------------------------------------------------------------
log "SSH configuration"
install -m 0644 /dev/null /etc/ssh/sogeor_user_ca.pub
printf '%s\n' "$USER_CA" > /etc/ssh/sogeor_user_ca.pub
install -d -m 0755 /etc/ssh/auth_principals
printf 'ansible\n' > /etc/ssh/auth_principals/ansible
chmod 0644 /etc/ssh/auth_principals/ansible

# Comment out Port lines elsewhere so sshd and the Ubuntu socket generator see only ours
sed -i -E 's/^[[:space:]]*Port[[:space:]]/#&/' /etc/ssh/sshd_config
for f in /etc/ssh/sshd_config.d/*.conf; do
  if [ -e "$f" ] && [ "$f" != "$SSHD_DROPIN" ]; then
    sed -i -E 's/^[[:space:]]*Port[[:space:]]/#&/' "$f"
  fi
done

install -d -m 0755 /etc/ssh/sshd_config.d
cat > "$SSHD_DROPIN" <<CONF
Port ${SSH_PORT}
AllowUsers ansible
AuthenticationMethods publickey
AuthorizedPrincipalsFile /etc/ssh/auth_principals/%u
TrustedUserCAKeys /etc/ssh/sogeor_user_ca.pub
PubkeyAuthentication yes
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin no
PermitEmptyPasswords no
MaxAuthTries 3
LoginGraceTime 20
ClientAliveInterval 300
ClientAliveCountMax 2
AllowAgentForwarding no
AllowTcpForwarding local
X11Forwarding no
PermitTunnel no
CONF
chmod 0644 "$SSHD_DROPIN"

# Used only where sshd runs through socket activation (Ubuntu 24.04+); harmless elsewhere
install -d -m 0755 "$(dirname "$SOCKET_DROPIN")"
cat > "$SOCKET_DROPIN" <<CONF
[Socket]
ListenStream=
ListenStream=${SSH_PORT}
CONF

# Validate before anything is restarted; on failure remove our files and stop
install -d -m 0755 /run/sshd
sshd -t || { revert_ssh; die "sshd rejected the configuration; nothing was restarted"; }
eff="$(sshd -T -C user=ansible,host=localhost,addr=127.0.0.1)"
for want in "port ${SSH_PORT}" "permitrootlogin no" "passwordauthentication no" \
            "authenticationmethods publickey" "allowusers ansible" \
            "trustedusercakeys /etc/ssh/sogeor_user_ca.pub"; do
  grep -qx "$want" <<<"$eff" || { revert_ssh; die "effective sshd setting is not '$want' (another file wins?)"; }
done
[ "$(grep -c '^port ' <<<"$eff")" -eq 1 ] || { revert_ssh; die "sshd would listen on more than one port"; }

# --- Firewall ---------------------------------------------------------------------
log "Firewall"
cat > /etc/nftables.conf <<CONF
#!/usr/sbin/nft -f
# Managed by Sogeor bootstrap; replaced by the Ansible firewall role (same table).
# Debian's default "inet filter" table (accept-all) is removed.
table inet filter
delete table inet filter
table inet host
delete table inet host
table inet host {
    chain input {
        type filter hook input priority filter; policy drop;
        iif lo accept
        ct state established,related accept
        ct state invalid drop
        meta l4proto { icmp, ipv6-icmp } accept
        tcp dport ${SSH_PORT} accept
        udp dport ${WG_PORT} accept
    }
}
CONF
nft -c -f /etc/nftables.conf

# --- Apply --------------------------------------------------------------------------
log "Apply SSH and firewall"
systemctl daemon-reload
# Restart the socket only where it is in use (Ubuntu). Starting it on Debian would stop
# ssh.service (Conflicts=) and take over the ports.
if systemctl is-active --quiet ssh.socket; then systemctl restart ssh.socket; fi
systemctl restart ssh
sleep 2
[ -n "$(ss -tlnH "sport = :${SSH_PORT}")" ] \
  || die "nothing listens on ${SSH_PORT}; keep this session open and check: journalctl -u ssh -u ssh.socket"
[ -z "$(ss -tlnH 'sport = :22')" ] || warn "something still listens on port 22 (the firewall blocks it)"
nft -f /etc/nftables.conf
systemctl enable nftables >/dev/null 2>&1

# --- Root and default users -------------------------------------------------------
log "Root and default users"
rm -f /root/.ssh/authorized_keys
if [ -n "${ROOT_PASSWORD_HASH:-}" ]; then
  case "$ROOT_PASSWORD_HASH" in \$6\$*|\$y\$*) ;; *) die "ROOT_PASSWORD_HASH must be a crypt hash (\$6\$ or \$y\$)" ;; esac
  usermod -p "$ROOT_PASSWORD_HASH" root
  echo "root: console password set (SSH login for root stays disabled)"
else
  passwd -l root >/dev/null
  echo "root: locked"
fi
for u in ubuntu debian admin; do
  id "$u" >/dev/null 2>&1 || continue
  [ "$(id -u "$u")" -ge 1000 ] || continue
  if [ "$u" = "${SUDO_USER:-}" ]; then
    warn "user $u runs this script; remove it later: sudo userdel -r $u"
    continue
  fi
  pkill -KILL -u "$u" 2>/dev/null || true
  userdel -r "$u" 2>/dev/null || userdel "$u" || warn "could not remove user $u"
done

# --- Result ---------------------------------------------------------------------------
log "Result"
sshd -T -C user=ansible,host=localhost,addr=127.0.0.1 \
  | grep -E '^(port|permitrootlogin|passwordauthentication|allowusers|authenticationmethods|trustedusercakeys) ' || true
ss -tlnp "sport = :${SSH_PORT}" || true
nft list table inet host | grep -E 'policy|dport' || true
echo "hostname: $(hostname -f 2>/dev/null || hostname)"

reboot_note=""
if [ -f /var/run/reboot-required ] && [ "${BOOTSTRAP_REBOOT:-yes}" = yes ]; then
  systemd-run --on-active=180 --unit=sogeor-bootstrap-reboot systemctl reboot >/dev/null
  reboot_note="A reboot is required by the upgrade and is scheduled in 3 minutes
(cancel: sudo systemctl stop sogeor-bootstrap-reboot.timer)."
fi

cat <<EOF

Done. Only ansible@${HOST}:${SSH_PORT} with a certificate (or the break-glass key) can log in.
${reboot_note}
Check from the workstation in a new terminal:
  ssh -p ${SSH_PORT} -i ~/.ssh/sogeor_ansible -o CertificateFile=~/.ssh/sogeor_ansible-cert.pub -o IdentitiesOnly=yes ansible@<IP> 'sudo -n true && echo OK'
EOF
