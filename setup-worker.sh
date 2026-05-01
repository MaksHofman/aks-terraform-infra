#!/bin/bash
# =============================================================
# SKRYPT INSTALACJI K8s NA WORKER NODZIE
# Prawie identyczny z masterem, ale bez kubeadm init
# Na końcu worker "dołącza" do klastra przez join command
# =============================================================

set -euo pipefail

JOIN_COMMAND=$1  # Komenda wygenerowana przez master (kubeadm join ...)

echo "============================================"
echo " STEP 1: System prep"
echo "============================================"

swapoff -a
sed -i '/swap/d' /etc/fstab

cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
modprobe overlay
modprobe br_netfilter

cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sysctl --system

echo "============================================"
echo " STEP 2: Instalacja containerd"
echo "============================================"

apt-get update -y
apt-get install -y containerd apt-transport-https ca-certificates curl gpg

mkdir -p /etc/containerd
containerd config default | tee /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

systemctl restart containerd
systemctl enable containerd

echo "============================================"
echo " STEP 3: Instalacja kubeadm, kubelet"
echo "============================================"

curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | \
  gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /' | \
  tee /etc/apt/sources.list.d/kubernetes.list

apt-get update -y
apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl

systemctl enable kubelet

echo "============================================"
echo " STEP 4: Dołączanie do klastra"
echo "============================================"

# JOIN_COMMAND wygląda mniej więcej tak:
# kubeadm join 10.0.1.10:6443 --token xyz123 --discovery-token-ca-cert-hash sha256:abc...
eval "${JOIN_COMMAND}"

echo "============================================"
echo " GOTOWE! Worker dołączył do klastra."
echo "============================================"
