#!/bin/bash

if [ -x "$(which curl)" ] ; then
   echo "curl is installed"
else
   dnf install curl -y
fi

dnf config-manager --add-repo=https://download.docker.com/linux/centos/docker-ce.repo
dnf install docker-ce --nobest -y
dnf install grubby -y
grubby --update-kernel=ALL  --args="systemd.unified_cgroup_hierarchy=0"
systemctl start docker
systemctl enabledocker
compose_location="/usr/local/bin/docker-compose"
compose_latest=$(curl --silent "https://api.github.com/repos/docker/compose/releases/latest" | grep -Po '"tag_name": "\K.*?(?=")')
curl -L "https://github.com/docker/compose/releases/download/${compose_latest}/docker-compose-$(uname -s)-$(uname -m)" -o ${compose_location} && chmod +x ${compose_location}