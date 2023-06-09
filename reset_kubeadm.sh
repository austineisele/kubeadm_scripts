#! /bin/bash
#
# Script to reset kubeadm in case of
# error
#

set -euxo pipefail

sudo -i
#reset command
kubeadm reset

#reset ip tabes
iptables -F && iptables -t nat -F && iptables -t mangle -F && iptables -X
ip link set cni0 down
ip link delete cni0 type bridge

#stop kubelet and docker
systemctl stop kubelet
systemctl stop docker
iptables --flush
iptables -tnat --flush

#restart kubelet and docker
systemctl start kubelet
systemctl start docker

