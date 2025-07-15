#!/bin/bash

# Jenkins Installation Script for Live Deployment
# Repository: Bhaktabahadurthapa/ecommerce-microservices
# Run this on your EC2 instance for Jenkins

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info "Installing Jenkins for Ecommerce Microservices CI/CD"
print_info "Repository: Bhaktabahadurthapa/ecommerce-microservices"

# Update system
print_info "Updating system packages..."
sudo apt update && sudo apt upgrade -y

# Install Java
print_info "Installing Java..."
sudo apt install openjdk-11-jdk -y
java -version

# Install Jenkins
print_info "Installing Jenkins..."
wget -q -O - https://pkg.jenkins.io/debian/jenkins.io.key | sudo apt-key add -
sudo sh -c 'echo deb http://pkg.jenkins.io/debian-stable binary/ > /etc/apt/sources.list.d/jenkins.list'
sudo apt update
sudo apt install jenkins -y

# Install Docker
print_info "Installing Docker..."
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker jenkins
sudo usermod -aG docker ubuntu

# Install Docker Compose
print_info "Installing Docker Compose..."
sudo curl -L "https://github.com/docker/compose/releases/download/v2.24.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Install kubectl
print_info "Installing kubectl..."
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Install Helm
print_info "Installing Helm..."
curl https://get.helm.sh/helm-v3.13.0-linux-amd64.tar.gz -o helm.tar.gz
tar -zxvf helm.tar.gz
sudo mv linux-amd64/helm /usr/local/bin/helm
rm -rf helm.tar.gz linux-amd64

# Install Go
print_info "Installing Go..."
wget https://go.dev/dl/go1.21.0.linux-amd64.tar.gz
sudo tar -C /usr/local -xzf go1.21.0.linux-amd64.tar.gz
echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
echo 'export PATH=$PATH:/usr/local/go/bin' | sudo tee -a /var/lib/jenkins/.bashrc

# Install Node.js
print_info "Installing Node.js..."
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# Install Python packages
print_info "Installing Python packages..."
sudo apt install python3-pip -y
pip3 install pytest coverage requests

# Install .NET SDK
print_info "Installing .NET SDK..."
wget https://packages.microsoft.com/config/ubuntu/20.04/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
sudo dpkg -i packages-microsoft-prod.deb
sudo apt update
sudo apt install dotnet-sdk-8.0 -y

# Install additional tools for DevSecOps
print_info "Installing security tools..."
sudo apt install jq curl unzip -y

# Start and enable Jenkins
print_info "Starting Jenkins service..."
sudo systemctl start jenkins
sudo systemctl enable jenkins

# Configure firewall if ufw is active
if sudo ufw status | grep -q "Status: active"; then
    print_info "Configuring firewall..."
    sudo ufw allow 8080
    sudo ufw allow 22
fi

# Wait for Jenkins to start
print_info "Waiting for Jenkins to start..."
sleep 30

# Get Jenkins initial password
print_info "Getting Jenkins initial admin password..."
JENKINS_PASSWORD=$(sudo cat /var/lib/jenkins/secrets/initialAdminPassword 2>/dev/null || echo "Not available yet")

# Create Jenkins directory structure
sudo mkdir -p /var/lib/jenkins/.kube
sudo chown jenkins:jenkins /var/lib/jenkins/.kube

# Install ArgoCD CLI for GitOps
print_info "Installing ArgoCD CLI..."
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
rm argocd-linux-amd64

# Create a script to install Jenkins plugins
print_info "Creating plugin installation helper..."
cat <<'EOF' | sudo tee /var/lib/jenkins/install-plugins.sh
#!/bin/bash
# Jenkins Plugin Installation Script

JENKINS_CLI="java -jar /var/lib/jenkins/jenkins-cli.jar -s http://localhost:8080/"

# Wait for Jenkins to be fully ready
while ! curl -s http://localhost:8080/login > /dev/null; do
    echo "Waiting for Jenkins to be ready..."
    sleep 10
done

# Essential plugins for the pipeline
plugins=(
    "pipeline-stage-view"
    "pipeline-build-step"
    "pipeline-graph-analysis"
    "pipeline-rest-api"
    "git"
    "github"
    "docker-workflow"
    "kubernetes"
    "blueocean"
    "sonar"
    "slack"
    "credentials"
    "ws-cleanup"
    "build-timeout"
    "timestamper"
)

echo "Installing Jenkins plugins..."
for plugin in "${plugins[@]}"; do
    echo "Installing $plugin..."
    $JENKINS_CLI install-plugin $plugin || echo "Failed to install $plugin"
done

echo "Restarting Jenkins to activate plugins..."
$JENKINS_CLI restart
EOF

sudo chmod +x /var/lib/jenkins/install-plugins.sh
sudo chown jenkins:jenkins /var/lib/jenkins/install-plugins.sh

# Get public IP for access information
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "localhost")

# Display completion information
print_success "Jenkins installation completed!"
echo ""
echo "🔐 Jenkins Access Information:"
echo "================================"
echo "URL: http://$PUBLIC_IP:8080"
echo "Initial Admin Password: $JENKINS_PASSWORD"
echo ""
print_info "Next Steps:"
echo "1. Access Jenkins at http://$PUBLIC_IP:8080"
echo "2. Use the password above to unlock Jenkins"
echo "3. Install suggested plugins (or use the install-plugins.sh script)"
echo "4. Create your admin user"
echo "5. Configure credentials for:"
echo "   - GitHub (github-credentials)"
echo "   - Docker Hub (docker-registry)"
echo "   - Kubernetes config (kubeconfig)"
echo "   - AWS credentials (aws-credentials)"
echo ""
echo "📋 Copy kubeconfig from your local machine:"
echo "scp -i your-key.pem ~/.kube/config ubuntu@$PUBLIC_IP:/tmp/kubeconfig"
echo "Then on this server:"
echo "sudo cp /tmp/kubeconfig /var/lib/jenkins/.kube/config"
echo "sudo chown jenkins:jenkins /var/lib/jenkins/.kube/config"
echo ""
echo "🚀 After Jenkins setup, create pipeline pointing to:"
echo "Repository: https://github.com/Bhaktabahadurthapa/ecommerce-microservices"
echo "Script Path: Jenkinsfile"
echo ""

# Save installation info
cat <<EOF > jenkins-install-info.txt
Jenkins Installation Complete - $(date)
======================================

Server IP: $PUBLIC_IP
Jenkins URL: http://$PUBLIC_IP:8080
Initial Password: $JENKINS_PASSWORD

Tools Installed:
- Jenkins LTS
- Docker & Docker Compose
- kubectl
- Helm
- Go 1.21
- Node.js 18
- Python 3 with pip
- .NET SDK 8.0
- ArgoCD CLI

Next Steps:
1. Configure Jenkins UI
2. Install plugins
3. Set up credentials
4. Create CI/CD pipeline
5. Connect to Kubernetes cluster

Repository: Bhaktabahadurthapa/ecommerce-microservices
Pipeline Script: Jenkinsfile
EOF

print_success "Installation info saved to jenkins-install-info.txt"
print_warning "Please save the initial password: $JENKINS_PASSWORD"
print_info "Restart the server if needed: sudo reboot"
