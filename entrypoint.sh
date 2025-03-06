#!/bin/bash
if [ -z "$PASSWORD" ]; then
  PASSWORD=$(head /dev/urandom | tr -dc 'A-Za-z0-9' | head -c 16)
  export PASSWORD
  echo "** Generated password for accounts 'root' and 'ubuntu': $PASSWORD"
else
  echo "** Using password from environment variables for accounts 'root' and 'ubuntu'."
fi
if [ -z "$SSH_PASSWORD_AUTH" ] || [ "$(echo "$SSH_PASSWORD_AUTH" | tr '[:upper:]' '[:lower:]')" = "false" ]; then
  sed -E -i 's|^#?(PasswordAuthentication)\s.*|\1 no|' /etc/ssh/sshd_config
  if ! grep '^PasswordAuthentication\s' /etc/ssh/sshd_config; then echo 'PasswordAuthentication no' | tee -a /etc/ssh/sshd_config > /dev/null; fi
  echo "** Disabled SSH password authentication."
else
  echo "** Leaving SSH password authentication enabled. Beware, this could be a security risk."
fi
if [ -z "$SSH_ROOT_LOGIN" ] || [ "$(echo "$SSH_ROOT_LOGIN" | tr '[:upper:]' '[:lower:]')" = "false" ]; then
  sed -E -i 's|^#?(PermitRootLogin)\s.*|\1 no|' /etc/ssh/sshd_config
  if ! grep '^PermitRootLogin\s' /etc/ssh/sshd_config; then echo 'PermitRootLogin no' | tee -a /etc/ssh/sshd_config > /dev/null; fi
  echo "** Disabled SSH root login."
else
  echo "** Leaving SSH root login enabled. Beware, this could be a security risk."
fi
echo "root:$PASSWORD" | chpasswd
echo "ubuntu:$PASSWORD" | chpasswd
mkdir -p /home/ubuntu/.ssh
mkdir -p /home/ubuntu/.gnupg
if [ -n "$KEYS" ]; then
  echo -e "$KEYS" > /home/ubuntu/.ssh/authorized_keys
  echo "** Added SSH keys from environment variables to ~/.ssh/authorized_keys."
fi
cp -R /volumes/.gnupg/* /home/ubuntu/.gnupg
cp /volumes/.gitconfig /home/ubuntu
chown -R ubuntu:ubuntu /home/ubuntu/.gnupg
chown -R ubuntu:ubuntu /home/ubuntu/.gitconfig
chown -R ubuntu:ubuntu /workspaces
chown -R ubuntu:ubuntu /data
if [ -z "$DOCKER_GROUP" ]; then
  groupadd docker_host
  echo "** No Docker group passed by environment variables. To use the host's Docker daemon, you'll need to use sudo."
else
  groupadd -g "$DOCKER_GROUP" docker_host
  echo "** Added the 'ubuntu' user to group $DOCKER_GROUP."
fi
usermod -aG docker_host ubuntu
if [ $(cat /proc/cpuinfo | grep avx2) = '' ]; then
  echo "** AVX2 instruction set support not found. You may have to reinstall some tools / applications for full functionality."
fi
echo "** Starting SSH server and Visual Studio Code tunnel."
/usr/sbin/sshd -D & sudo -u ubuntu bash -c 'code tunnel --accept-server-license-terms --server-data-dir /data/server --extensions-dir /data/extensions --cli-data-dir /data/cli'
