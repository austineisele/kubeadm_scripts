#! /bin/bash
#
#kubeadm initialization for the control plane
#This is based on a using a private ip address
#

set -euxo pipefail

PUBLIC_IP_ADDRESS="false"

#set environment variables. Master node will be hardcoded
NODENAME=$(hostname -s)
#this pod cidr range is based on calico's suggestion
POD_CIDR="192.168.0.0/16"

#get the images
sudo kubeadm config images pull

if [[ "$PUBLIC_IP_ADDRESS" == "false" ]]; then

    IPADDR=$(ip addr show eth1 | awk '/inet / {print $2}' | cut -d/ -f1)
    #initialize the control plane
    sudo kubeadm init --apiserver-advertise-address=$IPADDR --apiserver-cert-extra-sans=$IPADDR --pod-network-cidr=$POD_CIDR --node-name $NODENAME --ignore-preflight-errors Swap
elif [[ "$PUBLIC_IP_ADDRESS" == "true" ]]; then

    IPADDR=$(curl ifconfig.me && echo "")
     sudo kubeadm init --apiserver-advertise-address=$IPADDR --apiserver-cert-extra-sans=$IPADDR --pod-network-cidr=$POD_CIDR --node-name $NODENAME --ignore-preflight-errors Swap
 else
     echo "Error: IPADDR has an invalid value: $IPADDR"
fi


#configure kubeconfig
mkdir -p "$HOME"/.kube
sudo cp -i /etc/kubernetes/admin.conf "$HOME"/.kube/config
sudo chown "$(id -u)":"$(id -g)" "$HOME"/.kube/config

#install Calico CNI
curl https://raw.githubusercontent.com/projectcalico/calico/v3.25.0/manifests/calico.yaml -O

kubectl apply -f calico.yaml

