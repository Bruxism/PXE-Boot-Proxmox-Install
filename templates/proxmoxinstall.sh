#!/bin/bash

mkdir -p /root/.ssh

cat << EOL >> /root/.ssh/authorized_keys
${AUTHORIZED_KEYS}
EOL

chmod 600 /root/.ssh/authorized_keys
chown -R root:root /root/.ssh/authorized_keys

echo "${HOST_IP}	${HOSTNAME}.${HOST_DOMAIN} ${HOSTNAME}" >> /etc/hosts

apt update && apt install wget -y

cat > /etc/apt/sources.list.d/pve-install-repo.sources << EOL
Types: deb
URIs: http://download.proxmox.com/debian/pve
Suites: trixie
Components: pve-no-subscription
Signed-By: /usr/share/keyrings/proxmox-archive-keyring.gpg
EOL

wget https://enterprise.proxmox.com/debian/proxmox-archive-keyring-trixie.gpg -O /usr/share/keyrings/proxmox-archive-keyring.gpg

apt modernize-sources --assume-yes

apt update && apt full-upgrade -y

# This part needed inclusion as install would hang without them being set
echo "postfix postfix/main_mailer_type select Local only" | debconf-set-selections
echo "postfix postfix/mailname string ${HOSTNAME}.${HOST_DOMAIN}" | debconf-set-selections
echo "postfix postfix/destinations string ${HOSTNAME}.${HOST_DOMAIN}, localhost.localdomain, localhost" | debconf-set-selections

apt install -y proxmox-default-kernel proxmox-ve postfix open-iscsi chrony

apt remove -y linux-image-amd64 'linux-image-6.12*'

update-grub

apt remove -y os-prober
