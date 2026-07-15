#!/usr/bin/env bash

set -Eeuo pipefail

export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a
export NEEDRESTART_SUSPEND=1

readonly KUBERNETES_MINOR_VERSION="v1.36"
readonly KUBERNETES_KEYRING="/etc/apt/keyrings/kubernetes-apt-keyring.gpg"
readonly KUBERNETES_REPOSITORY_FILE="/etc/apt/sources.list.d/kubernetes.list"

trap 'echo "[ERROR] line ${LINENO}: command failed" >&2' ERR

log() {
    echo
    echo "==> $*"
}

if [[ "${EUID}" -ne 0 ]]; then
    echo "이 스크립트는 root 권한으로 실행해야 합니다." >&2
    exit 1
fi

########################################
# Install prerequisites
########################################

log "필수 패키지 설치"

apt-get update

apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gpg

########################################
# Add Kubernetes v1.36 repository
########################################

log "Kubernetes ${KUBERNETES_MINOR_VERSION} 저장소 등록"

install -d -m 0755 /etc/apt/keyrings

rm -f "${KUBERNETES_KEYRING}"

curl -fsSL \
    "https://pkgs.k8s.io/core:/stable:/${KUBERNETES_MINOR_VERSION}/deb/Release.key" \
    | gpg --dearmor \
        --yes \
        --output "${KUBERNETES_KEYRING}"

chmod 0644 "${KUBERNETES_KEYRING}"

cat > "${KUBERNETES_REPOSITORY_FILE}" <<EOF
deb [signed-by=${KUBERNETES_KEYRING}] https://pkgs.k8s.io/core:/stable:/${KUBERNETES_MINOR_VERSION}/deb/ /
EOF

########################################
# Install Kubernetes packages
########################################

log "kubelet, kubeadm, kubectl 설치"

apt-get update

apt-get install -y \
    kubelet \
    kubeadm \
    kubectl

########################################
# Prevent automatic upgrades
########################################

log "Kubernetes 패키지 자동 업그레이드 방지"

apt-mark hold \
    kubelet \
    kubeadm \
    kubectl

########################################
# Enable kubelet
########################################

log "kubelet 서비스 활성화"

systemctl enable kubelet

# kubeadm init/join 전에는 설정 파일이 없어서 kubelet이
# 재시작을 반복할 수 있으므로 강제로 시작할 필요는 없음.
systemctl start kubelet || true

########################################
# Verify installation
########################################

log "설치 결과 확인"

echo
echo "===== kubeadm ====="
kubeadm version -o short

echo
echo "===== kubelet ====="
kubelet --version

echo
echo "===== kubectl ====="
kubectl version --client

echo
echo "===== package hold ====="
apt-mark showhold \
    | grep -E '^(kubelet|kubeadm|kubectl)$' \
    || true

echo
echo "### kubeadm installation completed"
