#!/usr/bin/env bash

set -euo pipefail

cat << EOF > /etc/hosts
127.0.0.1			localhost

192.168.56.201  	master
192.168.56.202  	worker1
192.168.56.203  	worker2
192.168.56.204  	worker3
EOF

cat /etc/hosts
