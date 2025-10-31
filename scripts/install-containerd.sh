#!/usr/bin/env bash

set -euo pipefail

swapoff -a
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

cat <<EOF | sudo tee /etc/rc.local
#!/bin/bash
swapoff -a
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
exit 0
EOF

chmod +x /etc/rc.local

echo -e "[Install]" >> /lib/systemd/system/rc-local.service
echo -e "WantedBy=multi-user.target" >> /lib/systemd/system/rc-local.service

systemctl enable rc-local.service
systemctl start rc-local.service

cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sysctl --system

CONTAINERD_CONFIG_FILE=/etc/containerd/config.toml

apt install -y containerd
mkdir -p /etc/containerd

containerd config default | tee ${CONTAINERD_CONFIG_FILE} 
sed -i 's/^\(\s*SystemdCgroup\)\s*=\s*false$/\1 = true/' ${CONTAINERD_CONFIG_FILE}
grep 'SystemdCgroup' ${CONTAINERD_CONFIG_FILE}
sed -i 's|^\(\s*sandbox_image\)\s*=\s*\(.*\)$|\1 = "registry.k8s.io/pause:3.10.1"|' ${CONTAINERD_CONFIG_FILE}
grep 'sandbox_image' ${CONTAINERD_CONFIG_FILE}

systemctl restart containerd
