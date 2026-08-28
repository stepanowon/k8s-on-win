# /etc/sysctl.conf 또는 /etc/sysctl.d/99-disable-ipv6.conf 에 추가
sudo tee /etc/sysctl.d/99-disable-ipv6.conf <<EOF
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
EOF

sudo sysctl -p /etc/sysctl.d/99-disable-ipv6.conf
