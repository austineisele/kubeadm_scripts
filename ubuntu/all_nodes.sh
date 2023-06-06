#! /bin/bash
#
# Set up script for kubeadm. Set up for all servers
#
#

set -euxo pipefail

KUBERNETES_VERSION="1.27.2"

#disable swap
sudo swapoff -a

#disable swap on reboot
(crontab -l 2>/dev/null; echo "@reboot /sbin/swapoff -a") | crontab - || true
sudo apt-get update -y

#install the CRI-O runtime
OS="xUbuntu_22.04"

#get current k8 version
VERSION="$(echo ${KUBERNETES_VERSION} | grep -oE '[0-9]+\.[0-9]+')"

#set up a .conf file to load the overlay and br_netfilter modules at start up
#explanation: the overlay module creates a filesystem that is "overlayed" on top of another filesystem.
#br_netfilter creates a bridge between the kernal network stack and the Netfilter, allowing Netfilter
#rules to be applied to whatever is flowing through the bridge. Important for the CRI-O.
cat <<EOF | sudo tee /etc/modules-load.d/crio.conf
overlay
br_netfilter
EOF

#load the modules
sudo modprobe overlay
sudo modprobe br_netfilter

#make sure iptables are able to be used across reboots. 
# Set up required sysctl params, these persist across reboots.
cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

#reload the paramters just set
sudo sysctl --system

#get the cri-o package list
cat <<EOF | sudo tee /etc/apt/sources.list.d/devel:kubic:libcontainers:stable.list
deb https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/$OS/ /
EOF
cat <<EOF | sudo tee /etc/apt/sources.list.d/devel:kubic:libcontainers:stable:cri-o:$VERSION.list
deb http://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable:/cri-o:/$VERSION/$OS/ /
EOF

#get the gpg keys
curl -L https://download.opensuse.org/repositories/devel:kubic:libcontainers:stable:cri-o:$VERSION/$OS/Release.key | sudo apt-key --keyring /etc/apt/trusted.gpg.d/libcontainers.gpg add -
curl -L https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/$OS/Release.key | sudo apt-key --keyring /etc/apt/trusted.gpg.d/libcontainers.gpg add -


#update apt and instal cri-o
sudo apt-get update
sudo apt-get install cri-o cri-o-runc cri-tools -y

#enable and confirm
sudo systemctl daemon-reload
sudo systemctl enable crio --now

echo "CRI runtime installed susccessfully"

#install kubeadm, kubelet, and kubeclt
sudo apt-get install -y apt-transport-https ca-certificates curl
#get the google clout pulblic signing key
curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-archive-keyring.gpg
#add the apt repositories
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list

#update and install
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
#hold to keep the version
sudo apt-mark hold kubelet kubeadm kubectl

#using jq, get the master node ip and add to the kubelet 
sudo apt-get install -y jq
local_ip="$(ip --json a s | jq -r '.[] | if .ifname == "eth1" then .addr_info[] | if .family == "inet" then .local else empty end else empty end')"
cat > /etc/default/kubelet << EOF
KUBELET_EXTRA_ARGS=--node-ip=$local_ip
EOF


