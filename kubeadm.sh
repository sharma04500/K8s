#!/bin/bash

#####################################################################################
#      This script is to install kubernetes using kubeadm tool
# with container D as CRI.
#
#      This script contains all the commands and tools which 
# are needed to complete the installation of Kubernetes v1.27
###################################################################################

# Provide the ip of your system here:

ip=`ip a | grep enp0s3 | tail -1 | awk '{print substr($2, -3, length($2)-3)}'`

# Enabling debug mode

set -xe

# Script to be executed as a root user.

#sudo -i

# To update the index page of the apt repo as well as upgrade all the packages.

apt update && apt dist-upgrade -y

# To install container D on the system.

cat > /etc/modules-load.d/containerd.conf <<EOF
overlay
br_netfilter
EOF

modprobe overlay

sleep 3

modprobe br_netfilter

# Setup required sysctl params, these persist across reboots.

cat > /etc/sysctl.d/99-kubernetes-cri.conf <<EOF
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

sysctl --system

# Install container D from docker repository.

apt update

apt install -y ca-certificates curl gnupg

# To install the gpg key for docker repo.

install -m 0755 -d /etc/apt/keyrings

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

chmod a+r /etc/apt/keyrings/docker.gpg

# Setting Up Docker repository

echo \
  "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sleep 3

# Installing ContainerD from Docker Repo

apt update && apt-get install -y containerd.io

# Configuring containerd

mkdir -p /etc/containerd

containerd config default > /etc/containerd/config.toml

sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml

sleep 2

# Restarting Container D

systemctl restart containerd

# Setting Up crictl as CLI for executing containerD commands.

cat > /etc/crictl.yaml <<EOF
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint: unix:///run/containerd/containerd.sock
timeout: 2
EOF

sleep 3

# Installing Kubernetes

apt update

apt-get install -y apt-transport-https ca-certificates curl

# Downloading the GPG key for Kubernetes from Google cloud

curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

# Setting up the repo for K8s

echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

sleep 3

apt update

# Installing kubelet, kubeadm and kubectl for K8s.

apt-get install -y kubelet kubeadm kubectl 

#     For holding the kubelet, kubeadm and kubectl from auto upgrading on 
# execution upgrade commands. In order to manually upgrade these packages,
# we should release the hold prior to execution of upgradation commands.

apt-mark hold kubelet kubeadm kubectl

# Bootstrapping the control plane node

# Below command to predownload the required images, this speeds up the kubeadm initialization.

kubeadm config images pull

sleep 2

kubeadm init --apiserver-advertise-address=$ip --cri-socket=/run/containerd/containerd.sock --pod-network-cidr=10.20.0.0/16

# To let the kubeadm initialize completely

sleep 15


# Setting up the configuration for control plane 

mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Setting up the Calico network for K8s.

wget https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/tigera-operator.yaml

wget https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/custom-resources.yaml

#To check the Status of Kubeadm initialization.

kubectl get no

set +xe

echo "You've successfully installed k8s. Follow the below steps to bootstrap k8s control plane for on premises usage:"
# To replace the CIDR in the downloaded custom-resources.yaml file.

echo "replace the cidr in the custom-resources.yaml file with the cidr provided with kubeadm init and execute the below commands."

# Executing the dowloaded yaml files.

echo "kubectl create -f tigera-operator.yaml"

echo "kubectl create -f custom-resources.yaml"

echo " After successful execution of this script, execute -kubectl get nodes- to fetch the node name."

echo " Now, execute 'kubectl edit node <node_name>' and remove taints column (lines under taints as well) from the file "

