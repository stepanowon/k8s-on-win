#!/usr/bin/env bash

set -euo pipefail

# apt 단계가 커널 업그레이드/needrestart 다이얼로그로 멈추지 않게
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a
export NEEDRESTART_SUSPEND=1

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

apt-get update
apt-get install -y containerd
mkdir -p /etc/containerd

# 로그를 깔끔하게: 전체 config는 stdout으로 쏟지 않고 파일에만 기록
containerd config default > "${CONTAINERD_CONFIG_FILE}"

# cgroup 드라이버를 systemd로 (containerd 1.x/2.x 공통: SystemdCgroup = false 라인 존재)
sed -i 's/^\(\s*SystemdCgroup\)\s*=\s*false$/\1 = true/' "${CONTAINERD_CONFIG_FILE}"

# pause 이미지 고정
#  - containerd v2 이하(config v2): sandbox_image = "..."
#  - containerd 2.x(config v3)    : [plugins...pinned_images] 아래 sandbox = '...'
# 두 키 모두 시도 (없으면 그냥 no-op)
sed -i 's|^\(\s*sandbox_image\)\s*=\s*.*$|\1 = "registry.k8s.io/pause:3.10.1"|' "${CONTAINERD_CONFIG_FILE}"
sed -i 's|^\(\s*sandbox\)\s*=\s*.*$|\1 = "registry.k8s.io/pause:3.10.1"|'        "${CONTAINERD_CONFIG_FILE}"

# 검증용 출력. grep이 매칭 못 해도(exit 1) set -e 로 스크립트가 죽지 않게 '|| true'
echo "===== containerd config check ====="
grep -E 'SystemdCgroup|sandbox' "${CONTAINERD_CONFIG_FILE}" || true
echo "==================================="

systemctl restart containerd
systemctl enable containerd