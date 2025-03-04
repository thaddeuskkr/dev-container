#!/bin/bash
echo "root:$PASSWORD" | chpasswd
echo "ubuntu:$PASSWORD" | chpasswd
mkdir -p /home/ubuntu/.ssh
mkdir -p /home/ubuntu/.gnupg
echo "$KEYS\n" >> /home/ubuntu/.ssh/authorized_keys
cp -R /volumes/.gnupg/* /home/ubuntu/.gnupg
cp /volumes/.gitconfig /home/ubuntu
chown -R ubuntu:ubuntu /home/ubuntu/.gnupg
chown -R ubuntu:ubuntu /home/ubuntu/.gitconfig
/sbin/service sshd start
sudo -u ubuntu bash -c 'code tunnel --accept-server-license-terms --server-data-dir /data/server --extensions-dir /data/extensions --cli-data-dir /data/cli'
