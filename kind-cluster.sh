#!/bin/bash

# Define colors for terminal output
GREEN='\033[0;32m' # Success
YELLOW='\033[0;33m' # Info/Warning
RED='\033[0;31m'   # Error
BLUE='\033[0;34m'  # Section Headers
CYAN='\033[0;36m'  # Step Details
NC='\033[0m'       # No Color - Resets text to default

# Set to exit immediately if any command fails
set -e

echo -e "${BLUE}###############################################${NC}"
echo -e "${BLUE}#     Automated Go, Docker, Kind, Kubectl     #${NC}"
echo -e "${BLUE}#             Installation Script             #${NC}"
echo -e "${BLUE}###############################################${NC}"
echo ""

# Function to check if a command exists
command_exists () {
    command -v "$1" >/dev/null 2>&1
}

# ---------------------------------------------------
# Go Programming Language Installation
# ---------------------------------------------------
install_go() {
    echo -e "${CYAN}--- Starting Go Programming Language Installation ---${NC}"

    GO_VERSION="1.22.4" # Latest stable Go version as of June 2024
    GO_TARBALL_BASE="go${GO_VERSION}.linux"

    ARCH=$(uname -m)
    case "$ARCH" in
        "x86_64")
            GO_TARBALL="${GO_TARBALL_BASE}-amd64.tar.gz"
            echo -e "${YELLOW}Detected AMD64/x86_64 architecture. Downloading AMD64 Go binary.${NC}"
            ;;
        "aarch64")
            GO_TARBALL="${GO_TARBALL_BASE}-arm64.tar.gz"
            echo -e "${YELLOW}Detected ARM64 architecture. Downloading ARM64 Go binary.${NC}"
            ;;
        *)
            echo -e "${RED}Unsupported architecture: $ARCH. Go installation might fail.${NC}"
            exit 1
            ;;
    esac

    echo -e "${YELLOW}Updating and upgrading system packages...${NC}"
    sudo apt-get update -y && sudo apt-get upgrade -y || { echo -e "${RED}Failed to update/upgrade packages. Exiting.${NC}"; exit 1; }
    echo -e "${GREEN}System packages updated and upgraded.${NC}"

    echo -e "${YELLOW}Downloading Go ${GO_VERSION}...${NC}"
    wget "https://go.dev/dl/$GO_TARBALL" || { echo -e "${RED}Failed to download Go. Exiting.${NC}"; exit 1; }

    echo -e "${YELLOW}Extracting Go to /usr/local...${NC}"
    sudo tar -C /usr/local -xzf "$GO_TARBALL" || { echo -e "${RED}Failed to extract Go. Exiting.${NC}"; exit 1; }

    echo -e "${YELLOW}Setting up Go environment variables...${NC}"
    # Check if Go path is already in .bashrc to prevent duplicates
    if ! grep -q "export PATH=\$PATH:/usr/local/go/bin" "$HOME/.bashrc"; then
        echo "export PATH=\$PATH:/usr/local/go/bin" >> "$HOME/.bashrc"
        echo -e "${GREEN}Added Go to PATH in ~/.bashrc.${NC}"
    else
        echo -e "${YELLOW}Go path already exists in ~/.bashrc. Skipping adding.${NC}"
    fi

    # Source bashrc for the current session to make 'go' command available immediately
    source "$HOME/.bashrc"
    # Also explicitly add to the script's PATH for commands immediately following
    export PATH="$PATH:/usr/local/go/bin"

    echo -e "${YELLOW}Verifying Go installation...${NC}"
    if command_exists go; then
        echo -e "${GREEN}Go version: $(go version)${NC}"
        echo -e "${GREEN}Go installation completed successfully!${NC}"
    else
        echo -e "${RED}Go command not found after installation. Please check manually. Exiting.${NC}"
        exit 1
    fi

    echo -e "${YELLOW}Cleaning up downloaded Go tarball...${NC}"
    rm -f "$GO_TARBALL"
    echo -e "${GREEN}Go tarball removed.${NC}"
    echo ""
}

# ---------------------------------------------------
# Docker Installation
# ---------------------------------------------------
install_docker() {
    echo -e "${CYAN}--- Starting Docker Installation ---${NC}"

    echo -e "${YELLOW}Removing conflicting Docker packages (if any)...${NC}"
    for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do
        sudo apt-get remove -y "$pkg" 2>/dev/null || true # Suppress errors if package not found
    done
    echo -e "${GREEN}Conflicting packages removed.${NC}"

    echo -e "${YELLOW}Updating apt package index...${NC}"
    sudo apt-get update -y || { echo -e "${RED}Failed to update apt index. Exiting.${NC}"; exit 1; }

    echo -e "${YELLOW}Installing Docker dependencies: ca-certificates and curl...${NC}"
    sudo apt-get install -y ca-certificates curl || { echo -e "${RED}Failed to install curl and ca-certificates. Exiting.${NC}"; exit 1; }

    echo -e "${YELLOW}Adding Docker's official GPG key...${NC}"
    sudo install -m 0755 -d /etc/apt/keyrings || { echo -e "${RED}Failed to create keyrings directory. Exiting.${NC}"; exit 1; }
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc || { echo -e "${RED}Failed to download Docker GPG key. Exiting.${NC}"; exit 1; }
    sudo chmod a+r /etc/apt/keyrings/docker.asc || { echo -e "${RED}Failed to set GPG key permissions. Exiting.${NC}"; exit 1; }
    echo -e "${GREEN}Docker GPG key added.${NC}"

    echo -e "${YELLOW}Adding the Docker repository to Apt sources...${NC}"
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
      $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null || { echo -e "${RED}Failed to add Docker repository. Exiting.${NC}"; exit 1; }
    echo -e "${GREEN}Docker repository added.${NC}"

    echo -e "${YELLOW}Updating apt package index with Docker repository...${NC}"
    sudo apt-get update -y || { echo -e "${RED}Failed to update apt index after adding Docker repo. Exiting.${NC}"; exit 1; }

    echo -e "${YELLOW}Installing Docker Engine, CLI, Containerd, Buildx, and Compose...${NC}"
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin || { echo -e "${RED}Failed to install Docker components. Exiting.${NC}"; exit 1; }
    echo -e "${GREEN}Docker components installed.${NC}"

    echo -e "${YELLOW}Adding current user to the 'docker' group...${NC}"
    if ! getent group docker | grep -q "$USER"; then
        sudo usermod -aG docker "$USER" || { echo -e "${RED}Failed to add user to docker group. Exiting.${NC}"; exit 1; }
        echo -e "${GREEN}User added to 'docker' group.${NC}"
        echo -e "${YELLOW}Applying 'docker' group change immediately using 'newgrp docker'...${NC}"
        # This command attempts to immediately apply the new group membership to the current shell.
        # It's important for the 'docker --version' command to work without sudo right away.
        # However, it might not work in all shell environments or if the script is run in a non-interactive way.
        # For a completely robust solution, a logout/login is recommended after the script.
        newgrp docker 2>/dev/null || echo -e "${YELLOW}Could not apply newgrp immediately. You may need to logout/login or run 'newgrp docker' manually for Docker commands to work without sudo.${NC}"
    else
        echo -e "${YELLOW}User '$USER' is already a member of the 'docker' group. Skipping.${NC}"
    fi

    echo -e "${YELLOW}Enabling Docker to start on boot...${NC}"
    sudo systemctl enable docker || { echo -e "${RED}Failed to enable Docker service. Exiting.${NC}"; exit 1; }
    echo -e "${GREEN}Docker enabled to start on boot.${NC}"

    echo -e "${YELLOW}Verifying Docker installation...${NC}"
    if command_exists docker; then
        echo -e "${GREEN}Docker version: $(docker --version)${NC}"
        echo -e "${GREEN}Docker Engine installed correctly.${NC}"
        echo -e "${YELLOW}Attempting to run 'hello-world' image (requires group membership to be active)...${NC}"
        # Run hello-world. If it fails due to permissions, it's usually because newgrp didn't fully take effect.
        docker run hello-world || echo -e "${YELLOW}Failed to run 'hello-world' without sudo. Docker group membership may not be fully active yet in this session. Please log out and log back in, or run 'newgrp docker' manually.${NC}"
        echo -e "${GREEN}Docker installation completed successfully!${NC}"
    else
        echo -e "${RED}Docker command not found after installation. Please check manually. Exiting.${NC}"
        exit 1
    fi
    echo ""
}

# ---------------------------------------------------
# Kind Installation
# ---------------------------------------------------
install_kind() {
    echo -e "${CYAN}--- Starting Kind (Kubernetes in Docker) Installation ---${NC}"

    KIND_VERSION="v0.23.0" # Latest stable Kind version as of June 2024
    KIND_DOWNLOAD_URL_BASE="https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-linux"

    ARCH=$(uname -m)
    case "$ARCH" in
        "x86_64")
            KIND_URL="${KIND_DOWNLOAD_URL_BASE}-amd64"
            echo -e "${YELLOW}Detected AMD64/x86_64 architecture. Downloading AMD64 Kind binary.${NC}"
            ;;
        "aarch64")
            KIND_URL="${KIND_DOWNLOAD_URL_BASE}-arm64"
            echo -e "${YELLOW}Detected ARM64 architecture. Downloading ARM64 Kind binary.${NC}"
            ;;
        *)
            echo -e "${RED}Unsupported architecture: $ARCH. Kind installation might fail. Exiting.${NC}"
            exit 1
            ;;
    esac

    echo -e "${YELLOW}Downloading Kind ${KIND_VERSION}...${NC}"
    curl -Lo ./kind "$KIND_URL" || { echo -e "${RED}Failed to download Kind. Exiting.${NC}"; exit 1; }

    echo -e "${YELLOW}Making Kind executable and moving to /usr/local/bin...${NC}"
    chmod +x ./kind || { echo -e "${RED}Failed to make Kind executable. Exiting.${NC}"; exit 1; }
    sudo mv ./kind /usr/local/bin/kind || { echo -e "${RED}Failed to move Kind to /usr/local/bin. Exiting.${NC}"; exit 1; }

    echo -e "${YELLOW}Verifying Kind installation...${NC}"
    if command_exists kind; then
        echo -e "${GREEN}Kind version: $(kind version)${NC}"
        echo -e "${GREEN}Kind installation completed successfully!${NC}"
    else
        echo -e "${RED}Kind command not found after installation. Please check manually. Exiting.${NC}"
        exit 1
    fi
    echo ""
}

# ---------------------------------------------------
# Kubectl Installation
# ---------------------------------------------------
install_kubectl() {
    echo -e "${CYAN}--- Starting Kubectl Installation ---${NC}"

    echo -e "${YELLOW}Downloading latest stable Kubectl...${NC}"
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" || { echo -e "${RED}Failed to download Kubectl. Exiting.${NC}"; exit 1; }

    echo -e "${YELLOW}Making Kubectl executable and moving to /usr/local/bin...${NC}"
    chmod +x kubectl || { echo -e "${RED}Failed to make Kubectl executable. Exiting.${NC}"; exit 1; }
    sudo mv kubectl /usr/local/bin/kubectl || { echo -e "${RED}Failed to move Kubectl to /usr/local/bin. Exiting.${NC}"; exit 1; }

    echo -e "${YELLOW}Verifying Kubectl installation...${NC}"
    if command_exists kubectl; then
        # Parse the gitVersion from the YAML output for a cleaner display
        KUBECTL_CLIENT_VERSION=$(kubectl version --client --output=yaml | grep 'gitVersion' | awk -F': ' '{print $2}' | tr -d '"')
        echo -e "${GREEN}Kubectl client version: ${KUBECTL_CLIENT_VERSION}${NC}"
        echo -e "${GREEN}Kubectl installation completed successfully!${NC}"
    else
        echo -e "${RED}Kubectl command not found after installation. Please check manually. Exiting.${NC}"
        exit 1
    fi
    echo ""
}

# ---------------------------------------------------
# Create Kind Cluster
# ---------------------------------------------------
create_kind_cluster() {
    echo -e "${CYAN}--- Creating a Kind Kubernetes Cluster ---${NC}"

    CLUSTER_NAME="kind-cluster"
    # Stable K8s v1.29.2 image for Kind v0.23.0
    KIND_NODE_IMAGE="kindest/node:v1.29.2@sha256:56df935d10a265691f165a2d61d102e3b20248a39626e27b40748c086422ce4d"

    echo -e "${YELLOW}Checking if cluster '$CLUSTER_NAME' already exists...${NC}"
    if kind get clusters 2>/dev/null | grep -q "$CLUSTER_NAME"; then
        echo -e "${YELLOW}Kind cluster '$CLUSTER_NAME' already exists. Skipping cluster creation.${NC}"
    else
        echo -e "${YELLOW}Creating Kind cluster '$CLUSTER_NAME' with image ${KIND_NODE_IMAGE}...${NC}"
        kind create cluster --image "$KIND_NODE_IMAGE" --name "$CLUSTER_NAME" || { echo -e "${RED}Failed to create Kind cluster. Exiting.${NC}"; exit 1; }
        echo -e "${GREEN}Kind cluster '$CLUSTER_NAME' created successfully!${NC}"
    fi

    echo -e "${YELLOW}Setting kubectl context to '$CLUSTER_NAME'...${NC}"
    # Ensure the context is set correctly
    kubectl cluster-info --context "kind-$CLUSTER_NAME" >/dev/null 2>&1 || { echo -e "${RED}Failed to get cluster info or set context. Exiting.${NC}"; exit 1; }
    echo -e "${GREEN}Kubectl context set to 'kind-$CLUSTER_NAME'.${NC}"

    echo -e "${YELLOW}Verifying cluster nodes...${NC}"
    kubectl get nodes || { echo -e "${RED}Failed to get cluster nodes. Cluster might not be ready. Exiting.${NC}"; exit 1; }
    echo -e "${GREEN}Cluster verification complete.${NC}"
    echo ""
}

# ---------------------------------------------------
# Main Execution Flow
# ---------------------------------------------------
main() {
    install_go
    install_docker
    install_kind
    install_kubectl
    create_kind_cluster

    echo -e "${BLUE}###############################################${NC}"
    echo -e "${BLUE}#     All installations and cluster setup     #${NC}"
    echo -e "${BLUE}#        completed successfully! Enjoy!       #${NC}"
    echo -e "${BLUE}###############################################${NC}"
}

# Run the main function
main