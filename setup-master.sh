#!/bin/bash
# =============================================================
# SKRYPT INSTALACJI K8s NA MASTER NODZIE
# Ten skrypt uruchamia się na VM po jej stworzeniu przez Terraform
# Instaluje: containerd (runtime), kubeadm, kubelet, kubectl
# Potem inicjalizuje klaster i generuje token dla workerów
# =============================================================

set -euo pipefail  # zatrzymaj się przy błędzie, nie kontynuuj

MASTER_PRIVATE_IP=$1      # IP mastera (przekazane jako argument)
POD_NETWORK_CIDR="192.168.0.0/16"  # zakres IP dla podów (Calico default)

echo "============================================"
echo " STEP 1: System prep"
echo "============================================"

# Wyłącz swap - K8s tego wymaga, inaczej odmówi startu
swapoff -a
sed -i '/swap/d' /etc/fstab

# Załaduj moduły kernela potrzebne przez K8s
cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
modprobe overlay
modprobe br_netfilter

# Ustaw parametry sieciowe kernela
cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sysctl --system

echo "============================================"
echo " STEP 2: Instalacja containerd (runtime)"
echo "============================================"

# containerd = "silnik" który faktycznie uruchamia kontenery
apt-get update -y
apt-get install -y containerd apt-transport-https ca-certificates curl gpg

# Domyślna konfiguracja containerd
mkdir -p /etc/containerd
containerd config default | tee /etc/containerd/config.toml

# WAŻNE: ustaw SystemdCgroup = true, inaczej K8s będzie się crashował
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

systemctl restart containerd
systemctl enable containerd

echo "============================================"
echo " STEP 3: Instalacja kubeadm, kubelet, kubectl"
echo "============================================"

# Dodaj repo Kubernetes
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | \
  gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /' | \
  tee /etc/apt/sources.list.d/kubernetes.list

apt-get update -y
apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl  # zablokuj auto-update - ważne dla stabilności!

systemctl enable kubelet

echo "============================================"
echo " STEP 4: Inicjalizacja klastra (kubeadm init)"
echo "============================================"

# To jest moment gdzie klaster K8s "powstaje"
# --apiserver-advertise-address = na jakim IP słucha API mastera
# --pod-network-cidr = zakres IP dla podów (musi pasować do Calico)
kubeadm init \
  --apiserver-advertise-address="${MASTER_PRIVATE_IP}" \
  --pod-network-cidr="${POD_NETWORK_CIDR}" \
  --kubernetes-version=1.29.0 \
  --ignore-preflight-errors=NumCPU  # B2s ma 2 CPU, K8s chce 2 - na wszelki wypadek

echo "============================================"
echo " STEP 5: Konfiguracja kubectl dla azureuser"
echo "============================================"

# Skopiuj kubeconfig żeby azureuser mógł używać kubectl
mkdir -p /home/azureuser/.kube
cp -i /etc/kubernetes/admin.conf /home/azureuser/.kube/config
chown azureuser:azureuser /home/azureuser/.kube/config

# Też dla roota (przydatne w skryptach)
export KUBECONFIG=/etc/kubernetes/admin.conf

echo "============================================"
echo " STEP 6: Instalacja Calico (sieć dla podów)"
echo "============================================"

# Calico = wtyczka sieciowa, bez niej pody nie mogą się komunikować
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.0/manifests/calico.yaml

echo "============================================"
echo " STEP 7: Generowanie tokenu dla workerów"
echo "============================================"

# Wygeneruj komendę którą workery wykonają żeby dołączyć do klastra
# Zapisujemy ją do pliku - pipeline pobierze ją i wyśle do workerów
kubeadm token create --print-join-command > /tmp/kubeadm_join_command.sh
chmod 600 /tmp/kubeadm_join_command.sh

echo "============================================"
echo " GOTOWE! Master node skonfigurowany."
echo " Join command zapisany w /tmp/kubeadm_join_command.sh"
echo "============================================"

# Pokaż status klastra
kubectl get nodes
