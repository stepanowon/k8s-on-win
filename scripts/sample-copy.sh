#!/usr/bin/env bash

set -euo pipefail

cp -r /vagrant /home/user1/
chown -R user1:user1 /home/user1/vagrant
echo "### 샘플 예제 복사"