# 🚀 Quick Start Guide - Ecommerce Microservices CI/CD with GitOps

**Repository**: `Bhaktabahadurthapa/ecommerce-microservices`  
**GitHub URL**: https://github.com/Bhaktabahadurthapa/ecommerce-microservices

## 📋 Prerequisites Checklist

- [ ] AWS Account with CLI configured
- [ ] Docker installed and running
- [ ] Git configured with GitHub access
- [ ] Basic understanding of Kubernetes and Jenkins

## 🏗️ Infrastructure Setup (15-20 minutes)

### Step 1: Clone Repository
```bash
git clone https://github.com/Bhaktabahadurthapa/ecommerce-microservices.git
cd ecommerce-microservices
```

### Step 2: Create EKS Cluster
```bash
# Make scripts executable
chmod +x scripts/*.sh

# Setup EKS cluster (takes ~15 minutes)
./scripts/setup-eks-cluster.sh
```

**What this creates:**
- EKS cluster named `ecommerce-cluster`
- 3 worker nodes (t3.medium)
- ArgoCD for GitOps
- Prometheus & Grafana for monitoring
- Namespaces: dev, staging, prod, monitoring

### Step 3: Configure GitOps
```bash
# Deploy ArgoCD applications
./scripts/gitops-deploy.sh
```

**Access ArgoCD:**
- URL: https://localhost:8080 (after port-forward)
- Username: `admin`
- Password: Check terminal output or `cluster-info.txt`

## 🏭 Jenkins Setup (10-15 minutes)

### Step 1: Install Jenkins Server
Choose one option:

**Option A: EC2 Instance**
```bash
# Launch EC2 instance (t3.medium or larger)
# Security Groups: SSH (22), HTTP (8080), HTTPS (443)

# Connect to instance and run:
curl -sSL https://raw.githubusercontent.com/Bhaktabahadurthapa/ecommerce-microservices/main/scripts/install-jenkins.sh | bash
```

**Option B: Local Docker**
```bash
docker run -d \
  --name jenkins \
  -p 8080:8080 \
  -p 50000:50000 \
  -v jenkins_home:/var/jenkins_home \
  -v /var/run/docker.sock:/var/run/docker.sock \
  jenkins/jenkins:lts
```

### Step 2: Initial Jenkins Configuration

1. **Access Jenkins**: http://your-jenkins-server:8080
2. **Get admin password**:
   ```bash
   sudo cat /var/lib/jenkins/secrets/initialAdminPassword
   ```
3. **Install suggested plugins**
4. **Create admin user**

### Step 3: Install Required Plugins

Go to `Manage Jenkins` → `Manage Plugins` → `Available` and install:

**Essential Plugins:**
- [ ] Pipeline
- [ ] Git Plugin  
- [ ] GitHub Plugin
- [ ] Docker Pipeline
- [ ] Kubernetes Plugin
- [ ] Blue Ocean
- [ ] SonarQube Scanner
- [ ] Slack Notification

### Step 4: Configure Credentials

Go to `Manage Jenkins` → `Manage Credentials` → `System` → `Global credentials`:

| Credential Type | ID | Description | Value |
|---|---|---|---|
| Username/Password | `github-credentials` | GitHub access | Your GitHub username + Personal Access Token |
| Username/Password | `docker-registry` | Docker Hub | Your Docker Hub username + password |
| Secret Text | `sonar-token` | SonarQube | Generate from SonarQube server |
| Secret File | `kubeconfig` | Kubernetes | Upload `~/.kube/config` |
| Secret Text | `slack-token` | Slack notifications | Bot token from Slack |

## 🔧 Tool Configuration

### Docker Registry Setup
Update in `Jenkinsfile` line 7:
```groovy
DOCKER_REGISTRY = 'your-dockerhub-username' // Change this
```

### SonarQube Setup (Optional but recommended)
```bash
# Run SonarQube server
docker run -d --name sonarqube -p 9000:9000 sonarqube:latest

# Access: http://your-server:9000
# Default: admin/admin
# Create project: ecommerce-microservices
# Generate token for Jenkins
```

### Slack Integration (Optional)
1. Create Slack app in your workspace
2. Add bot token to Jenkins credentials
3. Update `SLACK_CHANNEL` in Jenkinsfile

## 🚀 Pipeline Execution

### Step 1: Create Jenkins Pipeline

1. **New Item** → **Pipeline** → Name: `ecommerce-microservices-pipeline`
2. **Pipeline Configuration**:
   - **Definition**: Pipeline script from SCM
   - **SCM**: Git
   - **Repository URL**: `https://github.com/Bhaktabahadurthapa/ecommerce-microservices.git`
   - **Credentials**: Select `github-credentials`
   - **Branch**: `*/main`
   - **Script Path**: `Jenkinsfile`

### Step 2: Configure GitHub Webhook

1. Go to GitHub repository settings
2. **Webhooks** → **Add webhook**
3. **Payload URL**: `http://your-jenkins-server:8080/github-webhook/`
4. **Content type**: `application/json`
5. **Events**: Push events, Pull requests

### Step 3: Run Pipeline

**Manual Trigger:**
1. Go to pipeline → **Build Now**

**Automatic Trigger:**
1. Push code to GitHub
2. Pipeline runs automatically

## 📊 Pipeline Stages Overview

The pipeline includes 11 comprehensive stages:

1. **🔍 Checkout & Setup** - Repository checkout and environment setup
2. **🔒 Security Scan** - Secret detection (GitLeaks, TruffleHog)
3. **🧪 Code Quality** - SonarQube analysis + multi-language testing
4. **🐳 Build Images** - Docker images for all 10+ microservices
5. **🔒 Container Security** - Trivy vulnerability scanning
6. **🧪 Integration Tests** - Service integration and E2E testing
7. **📦 Push Images** - Docker registry deployment
8. **🚀 Deploy Staging** - Staging environment deployment
9. **🔒 Security Compliance** - CIS benchmarks and OPA policies
10. **📊 Performance Testing** - Load testing with K6
11. **🎯 Production Deploy** - GitOps deployment via ArgoCD

## 🔄 GitOps Workflow

### Development Flow:
1. **Feature Branch** → Pushes to `feature/*` → Deploys to `dev` namespace
2. **Develop Branch** → Pushes to `develop` → Deploys to `staging` namespace  
3. **Main Branch** → Pushes to `main` → Manual approval → Deploys to `prod` namespace

### ArgoCD Applications:
- `ecommerce-microservices-dev` (auto-sync)
- `ecommerce-microservices-staging` (auto-sync)
- `ecommerce-microservices-prod` (manual sync)

## 🎯 Verification & Testing

### Step 1: Verify EKS Cluster
```bash
kubectl get nodes
kubectl get namespaces
kubectl get pods -n argocd
```

### Step 2: Test Local Development
```bash
# Build and run locally
docker-compose up --build

# Access application
curl http://localhost:8080/health
```

### Step 3: Verify Pipeline
1. Check Jenkins Blue Ocean: http://your-jenkins:8080/blue
2. Monitor ArgoCD: https://localhost:8080 (port-forward active)
3. Check application health in Kubernetes

### Step 4: Access Monitoring
```bash
# Grafana (monitoring)
kubectl port-forward svc/prometheus-grafana -n monitoring 3000:80
# Access: http://localhost:3000 (admin/prom-operator)

# ArgoCD (GitOps)
kubectl port-forward svc/argocd-server -n argocd 8080:443
# Access: https://localhost:8080
```

## 🚨 Troubleshooting

### Common Issues:

**1. Jenkins can't connect to Docker**
```bash
sudo usermod -aG docker jenkins
sudo systemctl restart jenkins
```

**2. kubectl commands fail**
```bash
# Copy kubeconfig to Jenkins
sudo cp ~/.kube/config /var/lib/jenkins/.kube/
sudo chown jenkins:jenkins /var/lib/jenkins/.kube/config
```

**3. Pipeline fails at build stage**
- Check Docker daemon is running
- Verify all Dockerfiles exist in service directories
- Check disk space on Jenkins server

**4. ArgoCD apps not syncing**
- Verify repository access
- Check ArgoCD server logs: `kubectl logs -n argocd deployment/argocd-server`
- Validate YAML syntax in manifests

**5. EKS cluster creation fails**
- Check AWS credentials and permissions
- Verify region availability
- Ensure sufficient AWS limits

### Getting Help:

**Logs to Check:**
- Jenkins: `/var/log/jenkins/jenkins.log`
- ArgoCD: `kubectl logs -n argocd deployment/argocd-server`
- EKS: `aws logs describe-log-groups --region us-west-2`

**Useful Commands:**
```bash
# Check pipeline logs
kubectl get events --sort-by=.metadata.creationTimestamp

# Debug ArgoCD
argocd app get ecommerce-microservices-prod

# Check resource usage
kubectl top nodes
kubectl top pods -A
```

## 🎉 Success Indicators

✅ **Infrastructure Ready:**
- EKS cluster running with 3 nodes
- ArgoCD accessible and configured
- Monitoring stack deployed

✅ **CI/CD Pipeline Working:**
- Jenkins accessible and configured
- Pipeline runs without errors
- All stages pass (green in Blue Ocean)

✅ **GitOps Operational:**
- ArgoCD applications synced
- Kubernetes deployments healthy
- Services accessible via load balancer

✅ **Application Running:**
- All microservices deployed
- Health checks passing
- Frontend accessible

## 📈 Next Steps

1. **Security Hardening**
   - Configure network policies
   - Set up RBAC
   - Enable pod security standards

2. **Advanced Monitoring**
   - Set up Jaeger for tracing
   - Configure custom dashboards
   - Set up alerting rules

3. **Performance Optimization**
   - Configure horizontal pod autoscaling
   - Optimize resource requests/limits
   - Set up cluster autoscaling

4. **Disaster Recovery**
   - Configure backup strategies
   - Test restoration procedures
   - Document runbooks

---

**Repository**: https://github.com/Bhaktabahadurthapa/ecommerce-microservices  
**Support**: Check docs/ directory for detailed guides  
**Pipeline Status**: 🚀 Ready for Production
