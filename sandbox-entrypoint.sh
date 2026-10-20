#!/bin/bash
set -euo pipefail

if [ "$#" -eq 0 ]; then
  set -- sshd
fi

# Keep one-off CLI experiments unprivileged and usable without SSH credentials.
if [ "$1" != sshd ] && [ "$1" != /usr/sbin/sshd ]; then
  exec sudo -E -H -u ubuntu -- env PATH="$PATH" BASH_ENV="$BASH_ENV" "$@"
fi
shift

password_auth=${SSH_PASSWORD_AUTH:-false}
root_login=${SSH_ROOT_LOGIN:-false}
case "${password_auth,,}" in
  true) password_auth=yes ;;
  false) password_auth=no ;;
  *) echo 'SSH_PASSWORD_AUTH must be true or false.' >&2; exit 1 ;;
esac
case "${root_login,,}" in
  true) root_login=yes ;;
  false) root_login=no ;;
  *) echo 'SSH_ROOT_LOGIN must be true or false.' >&2; exit 1 ;;
esac

install -d -m 0700 -o ubuntu -g ubuntu /home/ubuntu/.ssh
if [ -n "${KEYS:-}" ]; then
  printf '%s\n' "$KEYS" > /home/ubuntu/.ssh/authorized_keys
  chmod 0600 /home/ubuntu/.ssh/authorized_keys
  chown ubuntu:ubuntu /home/ubuntu/.ssh/authorized_keys
fi
if [ "$password_auth" = no ] && [ ! -s /home/ubuntu/.ssh/authorized_keys ]; then
  echo 'Set KEYS to an SSH public key, or enable SSH_PASSWORD_AUTH=true for password login.' >&2
  exit 1
fi

# Set a nonempty password to unlock the Ubuntu account for public-key login.
# Generated passwords are shown only if password authentication was requested.
password=${PASSWORD:-}
if [ -z "$password" ]; then
  password=$(openssl rand -base64 24)
  if [ "$password_auth" = yes ]; then
    printf '** Generated password for ubuntu and root: %s\n' "$password"
  fi
fi
printf 'ubuntu:%s\nroot:%s\n' "$password" "$password" | chpasswd
unset password PASSWORD

mkdir -p /run/sshd
ssh-keygen -A
# A dedicated config avoids conflicts with distro defaults and include order.
cat > /etc/ssh/sshd_config_sandbox <<CONFIG
Port 22
UsePAM yes
PubkeyAuthentication yes
PasswordAuthentication $password_auth
KbdInteractiveAuthentication no
PermitEmptyPasswords no
PermitRootLogin $root_login
AuthorizedKeysFile .ssh/authorized_keys
PrintMotd no
Subsystem sftp internal-sftp
Match User ubuntu
    SetEnv PATH=/home/ubuntu/.local/bin:/home/ubuntu/.nvm/current/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin BASH_ENV=/home/ubuntu/.bash_env
CONFIG
/usr/sbin/sshd -t -f /etc/ssh/sshd_config_sandbox
exec /usr/sbin/sshd -D -e -f /etc/ssh/sshd_config_sandbox "$@"
