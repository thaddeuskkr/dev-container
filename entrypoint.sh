#!/bin/bash
if [ -z "$PASSWORD" ]; then
  PASSWORD=$(head /dev/urandom | tr -dc 'A-Za-z0-9' | head -c 16)
  export PASSWORD
  echo "Generated password for accounts 'root' and 'ubuntu': $PASSWORD"
fi
echo "root:$PASSWORD" | chpasswd
echo "ubuntu:$PASSWORD" | chpasswd
mkdir -p /home/ubuntu/.ssh
mkdir -p /home/ubuntu/.gnupg
if [ -n "$KEYS" ]; then
  echo -e "$KEYS" > /home/ubuntu/.ssh/authorized_keys
fi
cp -R /volumes/.gnupg/* /home/ubuntu/.gnupg
cp /volumes/.gitconfig /home/ubuntu
chown -R ubuntu:ubuntu /home/ubuntu/.gnupg
chown -R ubuntu:ubuntu /home/ubuntu/.gitconfig
chown -R ubuntu:ubuntu /workspaces
chown -R ubuntu:ubuntu /data
if [ -z "$DOCKER_GROUP" ]; then
  groupadd docker_host
else
  groupadd -g "$DOCKER_GROUP" docker_host
fi
usermod -aG docker_host ubuntu
/usr/sbin/sshd -D & sudo -u ubuntu bash -c 'code tunnel --accept-server-license-terms --server-data-dir /data/server --extensions-dir /data/extensions --cli-data-dir /data/cli'
