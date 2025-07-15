# 🚀 Live Deployment Guide - Step by Step

**Repository**: `Bhaktabahadurthapa/ecommerce-microservices`  
**Live Production Deployment on AWS EKS with Jenkins CI/CD + GitOps**

## 📋 Prerequisites Check

Before starting, ensure you have:
- [ ] AWS Account with programmatic access
- [ ] Domain name (optional but recommended)
- [ ] Docker Hub account
- [ ] GitHub repository access
- [ ] Local development environment (Docker, Git)

## 🎯 Phase 1: AWS Infrastructure Setup (30 minutes)

### Step 1.1: Configure AWS CLI
```bash
# Install AWS CLI (if not installed)
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Configure AWS credentials
aws configure
# Enter your AWS Access Key ID
# Enter your AWS Secret Access Key
# Default region: us-west-2
# Default output format: json

# Verify configuration
aws sts get-caller-identity
```

### Step 1.2: Clone Repository and Setup
```bash
# Clone your repository
git clone https://github.com/Bhaktabahadurthapa/ecommerce-microservices.git
cd ecommerce-microservices

# Make scripts executable
chmod +x scripts/*.sh

# Verify all files are present
ls -la scripts/
# Should show: setup-eks-cluster.sh, gitops-deploy.sh
```

### Step 1.3: Deploy EKS Cluster
```bash
# Start EKS cluster creation (takes 15-20 minutes)
./scripts/setup-eks-cluster.sh

# Monitor progress
# The script will output progress updates
# Wait for "✅ EKS cluster setup complete!" message
```

**What gets created:**
- EKS cluster: `ecommerce-cluster`
- Worker nodes: 3x t3.medium instances
- Namespaces: `ecommerce-dev`, `ecommerce-staging`, `ecommerce-prod`
- ArgoCD for GitOps
- Prometheus & Grafana for monitoring
- AWS Load Balancer Controller

### Step 1.4: Verify EKS Cluster
```bash
# Check cluster status
kubectl get nodes
kubectl get namespaces
kubectl get pods -n argocd

# Save cluster information
cat cluster-info.txt
# Note down the ArgoCD admin password
```

## 🏭 Phase 2: Jenkins Server Setup (20 minutes)

### Step 2.1: Launch Jenkins Server (EC2)
```bash
# Launch EC2 instance for Jenkins
# Instance type: t3.medium or larger
# Security Groups: SSH (22), HTTP (8080), HTTPS (443)
# Key pair: Use existing or create new

# Connect to EC2 instance
ssh -i your-key.pem ubuntu@your-ec2-public-ip
```

### Step 2.2: Install Jenkins and Dependencies
```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Java
sudo apt install openjdk-11-jdk -y

# Install Jenkins
wget -q -O - https://pkg.jenkins.io/debian/jenkins.io.key | sudo apt-key add -
sudo sh -c 'echo deb http://pkg.jenkins.io/debian-stable binary/ > /etc/apt/sources.list.d/jenkins.list'
sudo apt update
sudo apt install jenkins -y

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker jenkins
sudo usermod -aG docker ubuntu

# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Install other tools
sudo apt install nodejs npm python3-pip -y
curl https://get.helm.sh/helm-v3.13.0-linux-amd64.tar.gz -o helm.tar.gz
tar -zxvf helm.tar.gz
sudo mv linux-amd64/helm /usr/local/bin/helm

# Start Jenkins
sudo systemctl start jenkins
sudo systemctl enable jenkins

# Get Jenkins initial password
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

### Step 2.3: Configure Jenkins Web UI
```bash
# Access Jenkins at: http://your-ec2-public-ip:8080
# Use the password from previous step
```

**Jenkins Setup Wizard:**
1. **Unlock Jenkins**: Paste the initial admin password
2. **Install Plugins**: Select "Install suggested plugins"
3. **Create Admin User**: Set username/password
4. **Instance Configuration**: Use default URL or set custom domain

### Step 2.4: Install Required Jenkins Plugins
Go to `Manage Jenkins` → `Manage Plugins` → `Available`:

**Essential Plugins (install these):**
- [ ] Pipeline
- [ ] Git Plugin
- [ ] GitHub Plugin
- [ ] Docker Pipeline
- [ ] Kubernetes Plugin
- [ ] Blue Ocean
- [ ] SonarQube Scanner
- [ ] Slack Notification Plugin
- [ ] Credentials Plugin
- [ ] Workspace Cleanup Plugin

Click "Install without restart" and wait for completion.

## 🔐 Phase 3: Configure Credentials and Tools (15 minutes)

### Step 3.1: Configure Jenkins Credentials
Go to `Manage Jenkins` → `Manage Credentials` → `System` → `Global credentials`:

**1. GitHub Credentials:**
- Kind: Username with password
- ID: `github-credentials`
- Username: `Bhaktabahadurthapa`
- Password: [Your GitHub Personal Access Token]

**2. Docker Hub Credentials:**
- Kind: Username with password
- ID: `docker-registry`
- Username: `bhaktabahadurthapa`
- Password: [Your Docker Hub password/token]

**3. Kubernetes Config:**
- Kind: Secret file
- ID: `kubeconfig`
- File: Upload your `~/.kube/config` file from EKS setup

**4. AWS Credentials:**
- Kind: AWS Credentials
- ID: `aws-credentials`
- Access Key ID: [Your AWS Access Key]
- Secret Access Key: [Your AWS Secret Key]

### Step 3.2: Copy Kubernetes Config to Jenkins
```bash
# On your local machine where you ran EKS setup
scp -i your-key.pem ~/.kube/config ubuntu@your-ec2-public-ip:/tmp/kubeconfig

# On Jenkins EC2 instance
sudo mkdir -p /var/lib/jenkins/.kube
sudo cp /tmp/kubeconfig /var/lib/jenkins/.kube/config
sudo chown jenkins:jenkins /var/lib/jenkins/.kube/config
sudo chmod 600 /var/lib/jenkins/.kube/config
```

### Step 3.3: Restart Jenkins
```bash
sudo systemctl restart jenkins
```

## 🔄 Phase 4: GitOps Setup (10 minutes)

### Step 4.1: Deploy ArgoCD Applications
```bash
# On your local machine (where you have kubectl configured)
./scripts/gitops-deploy.sh

# This will:
# - Configure ArgoCD CLI
# - Create ArgoCD applications for dev/staging/prod
# - Set up monitoring
# - Provide access URLs
```

### Step 4.2: Access ArgoCD
```bash
# Port forward to ArgoCD (keep this terminal open)
kubectl port-forward svc/argocd-server -n argocd 8080:443

# In another terminal, get the admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Access ArgoCD at: https://localhost:8080
# Username: admin
# Password: [from above command]
```

## 🚀 Phase 5: Create and Run CI/CD Pipeline (15 minutes)

### Step 5.1: Create Jenkins Pipeline
1. Go to Jenkins Dashboard: `http://your-ec2-public-ip:8080`
2. Click **"New Item"**
3. Enter name: `ecommerce-microservices-pipeline`
4. Select **"Pipeline"**
5. Click **"OK"**

### Step 5.2: Configure Pipeline
**General Tab:**
- Description: `CI/CD Pipeline for Ecommerce Microservices`
- Check **"GitHub project"**
- Project URL: `https://github.com/Bhaktabahadurthapa/ecommerce-microservices/`

**Build Triggers:**
- Check **"GitHub hook trigger for GITScm polling"**

**Pipeline:**
- Definition: **"Pipeline script from SCM"**
- SCM: **Git**
- Repository URL: `https://github.com/Bhaktabahadurthapa/ecommerce-microservices.git`
- Credentials: Select **`github-credentials`**
- Branch Specifier: `*/main`
- Script Path: `Jenkinsfile`

Click **"Save"**

### Step 5.3: Configure GitHub Webhook
1. Go to GitHub repository: https://github.com/Bhaktabahadurthapa/ecommerce-microservices
2. Click **Settings** → **Webhooks** → **Add webhook**
3. **Payload URL**: `http://your-ec2-public-ip:8080/github-webhook/`
4. **Content type**: `application/json`
5. **Which events**: Select "Just the push event"
6. **Active**: ✅ Checked
7. Click **"Add webhook"**

### Step 5.4: Update Jenkinsfile Configuration
Update the Docker registry in your Jenkinsfile:
```bash
# On your local machine
sed -i 's/DOCKER_REGISTRY = .*/DOCKER_REGISTRY = "bhaktabahadurthapa"/' Jenkinsfile
git add Jenkinsfile
git commit -m "Update Docker registry for live deployment"
git push origin main
```

## 🎬 Phase 6: Live Deployment Execution (30 minutes)

### Step 6.1: Test Local Build First
```bash
# Test Docker build locally
docker-compose build frontend
docker-compose up -d redis
docker-compose up frontend

# Test if frontend starts
curl http://localhost:8080/health
```

### Step 6.2: Trigger First Pipeline Run
1. Go to Jenkins → `ecommerce-microservices-pipeline`
2. Click **"Build Now"**
3. Click on the build number to see progress
4. Monitor the **Console Output**

**Pipeline Stages (watch these complete):**
1. 🔍 Checkout & Setup
2. 🔒 Security Scan - Secrets
3. 🧪 Code Quality & Testing
4. 🐳 Build Docker Images
5. 🔒 Container Security Scanning
6. 🧪 Integration Testing
7. 📦 Push Images (to Docker Hub)
8. 🚀 Deploy to Staging
9. 🔒 Security Compliance Check
10. 📊 Performance Testing
11. 🎯 Deploy to Production (manual approval required)

### Step 6.3: Monitor Pipeline Progress
```bash
# Watch Jenkins Blue Ocean (better UI)
# Access: http://your-ec2-public-ip:8080/blue

# Monitor ArgoCD deployments
# Access: https://localhost:8080 (if port-forward is active)

# Check Kubernetes deployments
kubectl get pods -n ecommerce-staging
kubectl get services -n ecommerce-staging
```

### Step 6.4: Approve Production Deployment
When pipeline reaches "Deploy to Production" stage:
1. Jenkins will pause and ask for approval
2. Click **"Deploy"** to proceed
3. Monitor ArgoCD for sync status
4. Verify pods are running in production namespace

## 🔍 Phase 7: Verification and Access (15 minutes)

### Step 7.1: Verify Deployments
```bash
# Check all namespaces
kubectl get pods -A | grep ecommerce

# Check services and get external IPs
kubectl get services -n ecommerce-prod
kubectl get services -n ecommerce-staging

# Check ArgoCD application status
kubectl port-forward svc/argocd-server -n argocd 8080:443 &
# Access ArgoCD and verify all apps are "Healthy" and "Synced"
```

### Step 7.2: Access Your Live Application
```bash
# Get Load Balancer URL for production
kubectl get service frontend -n ecommerce-prod

# If using LoadBalancer type, get external IP
FRONTEND_URL=$(kubectl get service frontend -n ecommerce-prod -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "Production URL: http://$FRONTEND_URL"

# Test the application
curl http://$FRONTEND_URL/health
```

### Step 7.3: Setup Monitoring Access
```bash
# Access Grafana monitoring
kubectl port-forward svc/prometheus-grafana -n monitoring 3000:80

# Access: http://localhost:3000
# Username: admin
# Password: prom-operator
```

## 🎯 Phase 8: Production Readiness Checklist

### Step 8.1: Domain Configuration (Optional)
```bash
# If you have a domain, configure DNS
# Point your domain to the LoadBalancer IP/hostname
# Example: ecommerce.yourdomain.com → LoadBalancer IP
```

### Step 8.2: SSL/TLS Setup (Recommended)
```bash
# Install cert-manager for automatic SSL
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# Configure ingress with TLS (create ingress.yaml)
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ecommerce-ingress
  namespace: ecommerce-prod
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
spec:
  rules:
  - host: ecommerce.yourdomain.com  # Replace with your domain
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: frontend
            port:
              number: 8080
EOF
```

### Step 8.3: Backup and Disaster Recovery
```bash
# Setup automated backups for Redis data
kubectl apply -f - <<EOF
apiVersion: batch/v1
kind: CronJob
metadata:
  name: redis-backup
  namespace: ecommerce-prod
spec:
  schedule: "0 2 * * *"  # Daily at 2 AM
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: redis-backup
            image: redis:alpine
            command:
            - /bin/sh
            - -c
            - redis-cli -h redis BGSAVE
          restartPolicy: OnFailure
EOF
```

## 🎉 Live Deployment Complete!

### Your Production Environment is Now Running:

**🌐 Application Access:**
- **Production**: `http://[LoadBalancer-IP]` or your domain
- **Staging**: Available in `ecommerce-staging` namespace
- **Development**: Available in `ecommerce-dev` namespace

**📊 Monitoring & Management:**
- **Jenkins**: `http://your-ec2-public-ip:8080`
- **ArgoCD**: `https://localhost:8080` (via port-forward)
- **Grafana**: `http://localhost:3000` (via port-forward)

**🔄 CI/CD Workflow:**
- **Feature Development**: Push to `feature/*` → Auto-deploy to dev
- **Staging**: Push to `develop` → Auto-deploy to staging
- **Production**: Push to `main` → Pipeline runs → Manual approval → Deploy to production

### 🚨 Troubleshooting Live Issues

**If pipeline fails:**
```bash
# Check Jenkins logs
sudo tail -f /var/log/jenkins/jenkins.log

# Check Docker daemon
sudo systemctl status docker

# Check disk space
df -h
```

**If pods are not starting:**
```bash
# Check pod status
kubectl describe pod [pod-name] -n ecommerce-prod

# Check resource usage
kubectl top nodes
kubectl top pods -n ecommerce-prod
```

**If ArgoCD sync fails:**
```bash
# Check ArgoCD application status
kubectl get applications -n argocd
kubectl describe application ecommerce-microservices-prod -n argocd
```

### 📞 Production Support

**Health Check Commands:**
```bash
# Application health
curl http://[your-frontend-url]/health

# Kubernetes health
kubectl get componentstatuses

# Node health
kubectl get nodes

# Service health
kubectl get services -A
```

**Log Access:**
```bash
# Application logs
kubectl logs -f deployment/frontend -n ecommerce-prod

# Jenkins logs
sudo journalctl -u jenkins -f

# ArgoCD logs
kubectl logs -f deployment/argocd-server -n argocd
```

---

**🎯 Your live production deployment is complete and ready to serve customers!**

**Repository**: https://github.com/Bhaktabahadurthapa/ecommerce-microservices  
**Status**: 🚀 **LIVE IN PRODUCTION**
