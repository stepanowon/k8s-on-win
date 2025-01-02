#!/usr/bin/env bash

set -euo pipefail

USERNAME="user1"
PASSWORD="asdf"
SSHDIR="/home/$USERNAME/.ssh"

useradd -m -s /bin/bash -p $PASSWORD $USERNAME
usermod -a -G sudo $USERNAME

echo "$USERNAME:$PASSWORD" | chpasswd $USERNAME
echo "### user1 사용자 등록 완료"

# vagrant 사용자 패스워드 변경
echo "vagrant:asdf" | chpasswd vagrant
echo "### vagrant 사용자 암호 변경 완료"