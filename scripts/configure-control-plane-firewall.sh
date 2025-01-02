#!/usr/bin/env bash

set -euo pipefail

ufw allow 6443/tcp
ufw allow 2379:2380/tcp
ufw allow 10248/tcp
ufw allow 10250/tcp
ufw allow 10251/tcp
ufw allow 10252/tcp
ufw allow 10255/tcp

ufw allow 179/tcp
ufw allow 4789/udp
ufw allow 51820:51821/tcp

