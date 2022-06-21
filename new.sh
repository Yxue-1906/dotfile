#!/usr/bin/env bash

if [[ $(uname -m) == "x86_64" ]];then
    wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
elif [[ $(uname -m) == "aarch64" ]];then
    wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64.deb
else
    echo unknown architecture
    exit -1
fi

read -p "please enter prefix: " prefix

dpkg -i cloudflared-linux-*.deb
cloudflared tunnel login
# wait for login complete

id=$(cloudflared tunnel create ssh-$prefix | grep -P '.*id .*-.*-.*-.*$' | sed -E 's/.*id ([a-z0-9]{8}-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{12}).*/\1/')

echo "tunnel: $id
credentials-file: $HOME/.cloudflared/$id.json

ingress:
    - hostname: $prefix.xypan.online
      service: ssh://localhost:22
    - service: http_status:404
" >> ~/.cloudflared/config.yml

cloudflared --config ~/.cloudflared/config.yml service install
service cloudflared start

echo remember add CNAME record $prefix.xypan.online for $id.cfargotunnel.com
echo 
echo 

read -p "please enter key: " key
echo $key
read 

echo $key > /etc/ssh/ca.pub
echo 'PubkeyAuthentication yes
TrustedUserCAKeys /etc/ssh/ca.pub' >> /etc/ssh/sshd_config

service sshd restart
