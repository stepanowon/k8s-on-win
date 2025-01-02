#!/usr/bin/env bash

set -euo pipefail

sed -i 's/archive.ubuntu.com/mirror.kakao.com/g' /etc/apt/sources.list.d/ubuntu.sources
sed -i 's/security.ubuntu.com/mirror.kakao.com/g' /etc/apt/sources.list.d/ubuntu.sources

apt update
apt upgrade -y

apt install virtualbox-guest-additions-iso -y
