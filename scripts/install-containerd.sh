#!/usr/bin/env bash

set -Eeuo pipefail

export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a
export NEEDRESTART_SUSPEND=1

readonly CONTAINERD_VERSION="2.3.3"
readonly RUNC_VERSION="1.5.0"
readonly CNI_PLUGINS_VERSION="1.9.1"
readonly PAUSE_IMAGE="registry.k8s.io/pause:3.10"

readonly CONTAINERD_CONFIG="/etc/containerd/config.toml"
readonly DOWNLOAD_DIR="/tmp/container-runtime-install"

trap 'echo "[ERROR] ${BASH_SOURCE[0]}:${LINENO}: command failed" >&2' ERR

########################################
# Utility functions
########################################

log() {
    echo
    echo "==> $*"
}

fail() {
    echo "[ERROR] $*" >&2
    exit 1
}

download() {
    local url="$1"
    local output="$2"

    curl \
        --fail \
        --location \
        --silent \
        --show-error \
        --retry 5 \
        --retry-delay 2 \
        --output "${output}" \
        "${url}"
}

########################################
# Preconditions
########################################

if [[ "${EUID}" -ne 0 ]]; then
    fail "이 스크립트는 root 권한으로 실행해야 합니다."
fi

case "$(uname -m)" in
    x86_64)
        readonly CONTAINERD_ARCH="amd64"
        readonly RUNC_ARCH="amd64"
        readonly CNI_ARCH="amd64"
        ;;
    aarch64|arm64)
        readonly CONTAINERD_ARCH="arm64"
        readonly RUNC_ARCH="arm64"
        readonly CNI_ARCH="arm64"
        ;;
    *)
        fail "지원하지 않는 CPU 아키텍처입니다: $(uname -m)"
        ;;
esac

source /etc/os-release

if [[ "${ID}" != "ubuntu" ]]; then
    fail "이 스크립트는 Ubuntu용입니다. 현재 OS: ${ID}"
fi

if [[ "${VERSION_ID}" != "24.04" ]]; then
    echo "[WARN] Ubuntu 24.04가 아닙니다. 현재 버전: ${VERSION_ID}"
fi

########################################
# File names and URLs
########################################

readonly CONTAINERD_FILE="containerd-${CONTAINERD_VERSION}-linux-${CONTAINERD_ARCH}.tar.gz"
readonly RUNC_FILE="runc.${RUNC_ARCH}"
readonly CNI_FILE="cni-plugins-linux-${CNI_ARCH}-v${CNI_PLUGINS_VERSION}.tgz"

readonly CONTAINERD_BASE_URL="https://github.com/containerd/containerd/releases/download/v${CONTAINERD_VERSION}"
readonly RUNC_BASE_URL="https://github.com/opencontainers/runc/releases/download/v${RUNC_VERSION}"
readonly CNI_BASE_URL="https://github.com/containernetworking/plugins/releases/download/v${CNI_PLUGINS_VERSION}"

########################################
# Install required packages
########################################

log "필수 패키지 설치"

apt-get update

apt-get install -y \
    ca-certificates \
    curl \
    tar

########################################
# Disable swap
########################################

log "swap 비활성화"

swapoff -a

# 주석 처리되지 않은 swap 항목만 비활성화
sed -ri \
    '/^[[:space:]]*#/! {
        /[[:space:]]swap[[:space:]]/ s/^/# /
    }' \
    /etc/fstab

if swapon --show --noheadings | grep -q .; then
    echo "[ERROR] 다음 swap 장치가 아직 활성화되어 있습니다:" >&2
    swapon --show >&2
    exit 1
fi

########################################
# Load kernel modules
########################################

log "Kubernetes용 커널 모듈 설정"

cat > /etc/modules-load.d/k8s.conf <<'EOF'
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

########################################
# Configure sysctl
########################################

log "Kubernetes용 sysctl 설정"

cat > /etc/sysctl.d/99-kubernetes-cri.conf <<'EOF'
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sysctl --system >/dev/null

########################################
# Prepare download directory
########################################

log "다운로드 디렉터리 준비"

rm -rf "${DOWNLOAD_DIR}"
install -d -m 0755 "${DOWNLOAD_DIR}"

cd "${DOWNLOAD_DIR}"

########################################
# Install containerd
########################################

log "containerd ${CONTAINERD_VERSION} 다운로드"

download \
    "${CONTAINERD_BASE_URL}/${CONTAINERD_FILE}" \
    "${CONTAINERD_FILE}"

download \
    "${CONTAINERD_BASE_URL}/${CONTAINERD_FILE}.sha256sum" \
    "${CONTAINERD_FILE}.sha256sum"

log "containerd 체크섬 검증"

sha256sum --check "${CONTAINERD_FILE}.sha256sum"

log "containerd ${CONTAINERD_VERSION} 설치"

tar \
    --extract \
    --gzip \
    --file "${CONTAINERD_FILE}" \
    --directory /usr/local

########################################
# Install runc
########################################

log "runc ${RUNC_VERSION} 다운로드"

download \
    "${RUNC_BASE_URL}/${RUNC_FILE}" \
    "${RUNC_FILE}"

download \
    "${RUNC_BASE_URL}/runc.sha256sum" \
    "runc.sha256sum"

log "runc 체크섬 검증"

grep " ${RUNC_FILE}\$" runc.sha256sum \
    | sha256sum --check -

log "runc ${RUNC_VERSION} 설치"

install \
    -m 0755 \
    "${RUNC_FILE}" \
    /usr/local/sbin/runc

########################################
# Install CNI plugins
########################################

log "CNI plugins ${CNI_PLUGINS_VERSION} 다운로드"

download \
    "${CNI_BASE_URL}/${CNI_FILE}" \
    "${CNI_FILE}"

download \
    "${CNI_BASE_URL}/${CNI_FILE}.sha256" \
    "${CNI_FILE}.sha256"

log "CNI plugins 체크섬 검증"

sha256sum --check "${CNI_FILE}.sha256"

log "CNI plugins ${CNI_PLUGINS_VERSION} 설치"

install -d -m 0755 /opt/cni/bin

tar \
    --extract \
    --gzip \
    --file "${CNI_FILE}" \
    --directory /opt/cni/bin

########################################
# Install systemd service
########################################

log "containerd systemd 서비스 설치"

cat > /etc/systemd/system/containerd.service <<'EOF'
[Unit]
Description=containerd container runtime
Documentation=https://containerd.io
After=network.target dbus.service
Wants=network-online.target

[Service]
ExecStartPre=-/sbin/modprobe overlay
ExecStart=/usr/local/bin/containerd

Type=notify
Delegate=yes
KillMode=process
Restart=always
RestartSec=5

LimitNPROC=infinity
LimitCORE=infinity
LimitNOFILE=infinity
TasksMax=infinity
OOMScoreAdjust=-999

[Install]
WantedBy=multi-user.target
EOF

########################################
# Generate containerd configuration
########################################

log "containerd 기본 설정 생성"

install -d -m 0755 /etc/containerd

/usr/local/bin/containerd config default \
    > "${CONTAINERD_CONFIG}"

########################################
# Configure containerd 2.x config v4
########################################

log "containerd config v4 설정 변경"

# containerd 2.3.x는 config version 4를 사용해야 함
if ! grep -Eq '^[[:space:]]*version[[:space:]]*=[[:space:]]*4' \
    "${CONTAINERD_CONFIG}"; then
    fail "containerd config version이 4가 아닙니다."
fi

# systemd cgroup 사용
sed -ri \
    's/^([[:space:]]*SystemdCgroup[[:space:]]*=[[:space:]]*)false$/\1true/' \
    "${CONTAINERD_CONFIG}"

# containerd 2.x config v3의 pause 이미지 설정
sed -ri \
    "s|^([[:space:]]*sandbox[[:space:]]*=[[:space:]]*).*$|\1\"${PAUSE_IMAGE}\"|" \
    "${CONTAINERD_CONFIG}"

########################################
# Validate modified configuration
########################################

log "containerd 설정 검증"

if ! grep -Eq \
    '^[[:space:]]*SystemdCgroup[[:space:]]*=[[:space:]]*true' \
    "${CONTAINERD_CONFIG}"; then

    grep -n "SystemdCgroup" "${CONTAINERD_CONFIG}" || true
    fail "SystemdCgroup=true 설정에 실패했습니다."
fi

if ! grep -Fq \
    "sandbox = \"${PAUSE_IMAGE}\"" \
    "${CONTAINERD_CONFIG}"; then

    grep -n "sandbox" "${CONTAINERD_CONFIG}" || true
    fail "pause 이미지 설정에 실패했습니다."
fi

# containerd가 설정 파일을 실제로 읽을 수 있는지 검사
/usr/local/bin/containerd \
    --config "${CONTAINERD_CONFIG}" \
    config dump >/dev/null

########################################
# Enable and start containerd
########################################

log "containerd 서비스 시작"

systemctl daemon-reload
systemctl enable containerd
systemctl restart containerd

########################################
# Service validation
########################################

if ! systemctl is-active --quiet containerd; then
    systemctl status containerd --no-pager || true
    journalctl -u containerd --no-pager -n 100 || true
    fail "containerd 서비스가 정상적으로 실행되지 않았습니다."
fi

########################################
# CRI validation
########################################

log "CRI 플러그인 확인"

if ! ctr plugins list \
    | awk '$1 == "io.containerd.cri.v1" && $2 == "runtime" {print $4}' \
    | grep -qx "ok"; then

    ctr plugins list | grep cri || true
    fail "containerd CRI runtime 플러그인이 정상 상태가 아닙니다."
fi

########################################
# Display installation result
########################################

echo
echo "=================================================="
echo " container runtime installation completed"
echo "=================================================="

echo
echo "[containerd]"
containerd --version

echo
echo "[runc]"
runc --version | head -n 1 || true

echo
echo "[CNI plugins]"
find /opt/cni/bin \
    -maxdepth 1 \
    -type f \
    -printf '%f\n' \
    | sort \
    | paste -sd ' ' -

echo
echo
echo "[containerd service]"
systemctl is-enabled containerd
systemctl is-active containerd

echo
echo "[containerd config]"
grep -E \
    '^[[:space:]]*(version|SystemdCgroup|sandbox)[[:space:]]*=' \
    "${CONTAINERD_CONFIG}" \
    || true

echo
echo "[CRI socket]"
echo "unix:///run/containerd/containerd.sock"

echo
echo "=================================================="

########################################
# Cleanup
########################################

rm -rf "${DOWNLOAD_DIR}"
