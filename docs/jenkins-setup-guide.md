# Jenkins CI/CD Setup Guide for Ecommerce Microservices

## 🚀 Complete Setup Guide for Jenkins + GitOps + AWS EKS

### Repository Information
- **Repository**: `Bhaktabahadurthapa/ecommerce-microservices`
- **GitHub URL**: `https://github.com/Bhaktabahadurthapa/ecommerce-microservices`
- **Pipeline File**: `Jenkinsfile`

## 📋 Prerequisites

### 1. AWS Setup
```bash
# Install AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Configure AWS credentials
aws configure
# AWS Access Key ID: [Your Access Key]
# AWS Secret Access Key: [Your Secret Key]
# Default region name: us-west-2
# Default output format: json
```

### 2. Create EKS Cluster
```bash
# Install eksctl
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin

# Create EKS cluster
eksctl create cluster \
  --name ecommerce-cluster \
  --region us-west-2 \
  --nodegroup-name ecommerce-nodes \
  --node-type t3.medium \
  --nodes 3 \
  --nodes-min 2 \
  --nodes-max 5 \
  --managed

# Update kubeconfig
aws eks update-kubeconfig --region us-west-2 --name ecommerce-cluster
```

### 3. Install ArgoCD for GitOps
```bash
# Create ArgoCD namespace
kubectl create namespace argocd

# Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Get ArgoCD admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Port forward to access ArgoCD UI
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

## 🔧 Jenkins Server Setup

### 1. Install Jenkins on EC2/VM
```bash
# Update system
sudo apt update

# Install Java
sudo apt install openjdk-11-jdk -y

# Add Jenkins repository
wget -q -O - https://pkg.jenkins.io/debian/jenkins.io.key | sudo apt-key add -
sudo sh -c 'echo deb http://pkg.jenkins.io/debian-stable binary/ > /etc/apt/sources.list.d/jenkins.list'

# Install Jenkins
sudo apt update
sudo apt install jenkins -y

# Start Jenkins
sudo systemctl start jenkins
sudo systemctl enable jenkins

# Get initial admin password
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

### 2. Install Required Tools on Jenkins Server
```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker jenkins

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/download/v2.24.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Install Helm
curl https://get.helm.sh/helm-v3.13.0-linux-amd64.tar.gz -o helm.tar.gz
tar -zxvf helm.tar.gz
sudo mv linux-amd64/helm /usr/local/bin/helm

# Install Go
wget https://go.dev/dl/go1.21.0.linux-amd64.tar.gz
sudo tar -C /usr/local -xzf go1.21.0.linux-amd64.tar.gz
echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc

# Install Node.js
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# Install Python packages
sudo apt install python3-pip -y
pip3 install pytest coverage

# Install .NET SDK
wget https://packages.microsoft.com/config/ubuntu/20.04/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
sudo dpkg -i packages-microsoft-prod.deb
sudo apt update
sudo apt install dotnet-sdk-8.0 -y

# Restart Jenkins to apply group changes
sudo systemctl restart jenkins
```

### 3. Install Jenkins Plugins
Access Jenkins UI at `http://your-jenkins-server:8080` and install these plugins:

**Essential Plugins:**
- Pipeline
- Git Plugin
- GitHub Plugin
- Docker Pipeline
- Kubernetes Plugin
- SonarQube Scanner
- Slack Notification
- Blue Ocean
- Pipeline: Stage View
- Credentials Plugin
- Workspace Cleanup

**GitOps & Deployment:**
- Kubernetes CLI Plugin
- Helm Plugin
- ArgoCD Plugin

**Security & Quality:**
- SonarQube Quality Gates
- OWASP Dependency Check
- Security Scanner

## 🔐 Configure Jenkins Credentials

Go to `Manage Jenkins` > `Manage Credentials` > `System` > `Global credentials`

### 1. GitHub Credentials
- **Kind**: Username with password
- **ID**: `github-credentials`
- **Username**: Your GitHub username
- **Password**: GitHub Personal Access Token

### 2. Docker Registry Credentials
- **Kind**: Username with password
- **ID**: `docker-registry`
- **Username**: Your Docker Hub username
- **Password**: Docker Hub password/token

### 3. AWS Credentials
- **Kind**: AWS Credentials
- **ID**: `aws-credentials`
- **Access Key ID**: Your AWS Access Key
- **Secret Access Key**: Your AWS Secret Key

### 4. Kubernetes Config
- **Kind**: Secret file
- **ID**: `kubeconfig`
- **File**: Upload your `~/.kube/config` file

### 5. SonarQube Token
- **Kind**: Secret text
- **ID**: `sonar-token`
- **Secret**: Your SonarQube token

### 6. Slack Token
- **Kind**: Secret text
- **ID**: `slack-token`
- **Secret**: Your Slack Bot token

## 🏗️ SonarQube Setup

### 1. Install SonarQube with Docker
```bash
# Create SonarQube container
docker run -d --name sonarqube \
  -p 9000:9000 \
  -e SONAR_ES_BOOTSTRAP_CHECKS_DISABLE=true \
  sonarqube:latest

# Access SonarQube at http://your-server:9000
# Default credentials: admin/admin
```

### 2. Configure SonarQube Project
1. Login to SonarQube
2. Create new project: `ecommerce-microservices`
3. Generate token for Jenkins integration
4. Configure quality gates and rules

## 🚀 Pipeline Configuration

### 1. Create Jenkins Pipeline Job
1. Go to Jenkins Dashboard
2. Click "New Item"
3. Enter name: `ecommerce-microservices-pipeline`
4. Select "Pipeline" and click OK

### 2. Configure Pipeline
**General Settings:**
- Description: `CI/CD Pipeline for Ecommerce Microservices with GitOps`
- Check "GitHub project"
- Project URL: `https://github.com/Bhaktabahadurthapa/ecommerce-microservices/`

**Build Triggers:**
- Check "GitHub hook trigger for GITScm polling"
- Check "Poll SCM" with schedule: `H/5 * * * *`

**Pipeline Definition:**
- Definition: Pipeline script from SCM
- SCM: Git
- Repository URL: `https://github.com/Bhaktabahadurthapa/ecommerce-microservices.git`
- Credentials: Select `github-credentials`
- Branch: `*/main`
- Script Path: `Jenkinsfile`

### 3. Configure GitHub Webhook
1. Go to your GitHub repository settings
2. Click "Webhooks" > "Add webhook"
3. Payload URL: `http://your-jenkins-server:8080/github-webhook/`
4. Content type: `application/json`
5. Events: Push events, Pull requests
6. Active: ✅

## 🔄 GitOps Setup with ArgoCD

### 1. Create GitOps Repository Structure
```bash
# Create separate GitOps repository or use the same repo
mkdir -p gitops/{environments,applications}
mkdir -p gitops/environments/{dev,staging,prod}
mkdir -p gitops/applications/ecommerce
```

### 2. Configure ArgoCD Application
```yaml
# gitops/applications/ecommerce/application.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: ecommerce-microservices
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/Bhaktabahadurthapa/ecommerce-microservices
    targetRevision: main
    path: kubernetes-manifests
  destination:
    server: https://kubernetes.default.svc
    namespace: ecommerce-prod
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
```

## 🏃‍♂️ Running the Pipeline

### 1. Manual Trigger
1. Go to Jenkins Dashboard
2. Click on `ecommerce-microservices-pipeline`
3. Click "Build Now"

### 2. Automatic Trigger
- Push code to GitHub
- Create Pull Request
- Pipeline will trigger automatically

### 3. Monitor Pipeline
- Blue Ocean UI: `http://your-jenkins-server:8080/blue`
- Classic UI: Pipeline view shows all stages
- Logs available for each stage

## 📊 Pipeline Stages Overview

1. **🔍 Checkout & Setup** - Code checkout and environment setup
2. **🔒 Security Scan** - Secret detection with GitLeaks and TruffleHog
3. **🧪 Code Quality** - SonarQube analysis and multi-language testing
4. **🐳 Build Images** - Docker image building for all microservices
5. **🔒 Container Security** - Trivy vulnerability scanning
6. **🧪 Integration Tests** - Service integration and E2E testing
7. **📦 Push Images** - Push to Docker registry
8. **🚀 Deploy Staging** - Staging environment deployment
9. **🔒 Security Compliance** - CIS benchmarks and OPA policies
10. **📊 Performance Testing** - Load testing with K6
11. **🎯 Production Deploy** - Blue-green deployment to production

## 🔧 Environment Variables

Update these in your Jenkins pipeline or environment:

```groovy
environment {
    // Docker Registry
    DOCKER_REGISTRY = 'your-dockerhub-username' // Update this
    DOCKER_REPO = 'ecommerce-microservices'
    
    // AWS Configuration
    AWS_REGION = 'us-west-2'
    EKS_CLUSTER_NAME = 'ecommerce-cluster'
    
    // Kubernetes
    KUBERNETES_NAMESPACE = 'ecommerce-prod'
    
    // Notifications
    SLACK_CHANNEL = '#devops-alerts' // Update this
}
```

## 🚨 Troubleshooting

### Common Issues:

1. **Docker permission denied**
   ```bash
   sudo usermod -aG docker jenkins
   sudo systemctl restart jenkins
   ```

2. **Kubectl not working**
   ```bash
   # Copy kubeconfig to Jenkins
   sudo cp ~/.kube/config /var/lib/jenkins/.kube/
   sudo chown jenkins:jenkins /var/lib/jenkins/.kube/config
   ```

3. **SonarQube connection failed**
   - Check SonarQube server URL
   - Verify token credentials
   - Ensure network connectivity

4. **GitHub webhook not triggering**
   - Check webhook URL format
   - Verify Jenkins is accessible from internet
   - Check webhook delivery logs in GitHub

## 📈 Monitoring & Alerts

### 1. Pipeline Monitoring
- Jenkins Blue Ocean for visual pipeline status
- Email notifications for failures
- Slack integration for team alerts

### 2. Application Monitoring
```bash
# Install Prometheus and Grafana
kubectl apply -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/main/bundle.yaml

# Add monitoring to your applications
kubectl apply -f monitoring/prometheus-config.yaml
```

### 3. ArgoCD Monitoring
- ArgoCD UI shows deployment status
- Sync status and health checks
- Application metrics and logs

## 🎯 Next Steps

1. **Security Hardening**
   - Implement pod security policies
   - Network policies for microservices
   - RBAC configuration

2. **Advanced GitOps**
   - Multi-environment promotion
   - Canary deployments
   - Rollback strategies

3. **Observability**
   - Distributed tracing with Jaeger
   - Centralized logging with ELK stack
   - Custom metrics and dashboards

4. **Disaster Recovery**
   - Backup strategies
   - Multi-region deployment
   - Automated failover

## 📞 Support

For issues and questions:
- Check Jenkins logs: `/var/log/jenkins/jenkins.log`
- Review pipeline console output
- Check ArgoCD application status
- Verify Kubernetes cluster health

---

**Repository**: `Bhaktabahadurthapa/ecommerce-microservices`
**Pipeline Status**: Ready for deployment 🚀
