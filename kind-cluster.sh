#!/bin/bash


#installation of Go Programming Language
sudo apt-get update && sudo apt-get upgrade -y

echo "Instalation of Go Programming Language"

wget https://go.dev/dl/go1.24.3.linux-amd64.tar.gz
sudo tar -C /usr/local -xzf go1.24.3.linux-amd64.tar.gz
cat <<EOF >> ~/.bashrc
export PATH=\$PATH:/usr/local/go/bin
EOF
source ~/.bashrc
echo "Go version: $(go version)"
echo "Instalation has been completed successfully"

#Installation of Docker
echo "Instalation of Docker"
for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do sudo apt-get remove $pkg; done
sudo apt-get update
# Add Docker's official GPG key:
sudo apt-get update
sudo apt-get install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y
sudo usermod -aG docker $USER
newgrp docker
# Verify that Docker Engine is installed correctly by running the hello-world image:
echo "Docker version: $(docker --version)"
echo "Instalation has been completed successfully"

# Install Kind
echo "Instalation of Kind"
[ $(uname -m) = x86_64 ] && curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.29.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind
kind version
echo "Instalation has been completed successfully"

# Create a Kind cluster
echo "Creating a Kind cluster"
kind create cluster --image kindest/node:v1.33.1@sha256:050072256b9a903bd914c0b2866828150cb229cea0efe5892e2b644d5dd3b34f --name kind-cluster
echo "Cluster created successfully"

# Kubectl Installation
echo "Instalation of Kubectl"
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/kubectl
kubectl version --client
echo "Instalation has been completed successfully"

