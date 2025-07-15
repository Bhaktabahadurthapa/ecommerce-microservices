#!/bin/bash

# GitOps Deployment Script for Ecommerce Microservices
# Repository: Bhaktabahadurthapa/ecommerce-microservices

set -e

# Configuration
REPO_NAME="Bhaktabahadurthapa/ecommerce-microservices"
REPO_URL="https://github.com/Bhaktabahadurthapa/ecommerce-microservices"
DOCKER_REGISTRY="bhaktabahadurthapa"
ARGOCD_NAMESPACE="argocd"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

print_info "GitOps Deployment for Ecommerce Microservices"
print_info "Repository: $REPO_NAME"

# Check if kubectl is configured
if ! kubectl cluster-info &> /dev/null; then
    print_error "kubectl is not configured or cluster is not accessible"
    exit 1
fi

# Check if ArgoCD is installed
if ! kubectl get namespace $ARGOCD_NAMESPACE &> /dev/null; then
    print_error "ArgoCD namespace not found. Please install ArgoCD first."
    exit 1
fi

# Install ArgoCD CLI if not present
if ! command -v argocd &> /dev/null; then
    print_info "Installing ArgoCD CLI..."
    curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
    sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
    rm argocd-linux-amd64
    print_success "ArgoCD CLI installed"
fi

# Wait for ArgoCD server to be ready
print_info "Waiting for ArgoCD server to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n $ARGOCD_NAMESPACE --timeout=300s

# Get ArgoCD admin password
print_info "Getting ArgoCD admin password..."
ARGOCD_PASSWORD=$(kubectl -n $ARGOCD_NAMESPACE get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d 2>/dev/null || echo "")

if [ -z "$ARGOCD_PASSWORD" ]; then
    print_warning "Could not retrieve ArgoCD password. Using default: admin123"
    ARGOCD_PASSWORD="admin123"
fi

# Port forward to ArgoCD server (in background)
print_info "Setting up port-forward to ArgoCD server..."
kubectl port-forward svc/argocd-server -n $ARGOCD_NAMESPACE 8080:443 &
PORT_FORWARD_PID=$!
sleep 5

# Function to cleanup port-forward on exit
cleanup() {
    if [ ! -z "$PORT_FORWARD_PID" ]; then
        kill $PORT_FORWARD_PID 2>/dev/null || true
    fi
}
trap cleanup EXIT

# Login to ArgoCD
print_info "Logging into ArgoCD..."
argocd login localhost:8080 --username admin --password "$ARGOCD_PASSWORD" --insecure

# Add repository to ArgoCD
print_info "Adding repository to ArgoCD..."
argocd repo add $REPO_URL --name ecommerce-microservices --type git

# Apply ArgoCD project and applications
print_info "Applying ArgoCD project and applications..."
kubectl apply -f argocd/project.yaml
kubectl apply -f argocd/applications.yaml

# Wait for applications to be created
sleep 10

# Sync applications
print_info "Syncing ArgoCD applications..."

# Development environment
if argocd app get ecommerce-microservices-dev &> /dev/null; then
    print_info "Syncing development environment..."
    argocd app sync ecommerce-microservices-dev --prune
    print_success "Development environment synced"
else
    print_warning "Development application not found"
fi

# Staging environment  
if argocd app get ecommerce-microservices-staging &> /dev/null; then
    print_info "Syncing staging environment..."
    argocd app sync ecommerce-microservices-staging --prune
    print_success "Staging environment synced"
else
    print_warning "Staging application not found"
fi

# Production environment
if argocd app get ecommerce-microservices-prod &> /dev/null; then
    print_info "Production environment requires manual sync for safety"
    print_warning "To sync production, run: argocd app sync ecommerce-microservices-prod"
else
    print_warning "Production application not found"
fi

# Display application status
print_info "Application Status:"
echo "==================="

for app in ecommerce-microservices-dev ecommerce-microservices-staging ecommerce-microservices-prod; do
    if argocd app get $app &> /dev/null; then
        echo ""
        echo "Application: $app"
        echo "Health: $(argocd app get $app -o json | jq -r '.status.health.status // "Unknown"')"
        echo "Sync: $(argocd app get $app -o json | jq -r '.status.sync.status // "Unknown"')"
        echo "Revision: $(argocd app get $app -o json | jq -r '.status.sync.revision // "Unknown"')"
    fi
done

# Create monitoring and alerting for GitOps
print_info "Setting up GitOps monitoring..."

# Create ServiceMonitor for ArgoCD metrics
cat <<EOF | kubectl apply -f -
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: argocd-metrics
  namespace: argocd
  labels:
    app.kubernetes.io/name: argocd-metrics
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: argocd-metrics
  endpoints:
  - port: metrics
---
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: argocd-server-metrics
  namespace: argocd
  labels:
    app.kubernetes.io/name: argocd-server-metrics
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: argocd-server-metrics
  endpoints:
  - port: metrics
---
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: argocd-repo-server-metrics
  namespace: argocd
  labels:
    app.kubernetes.io/name: argocd-repo-server
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: argocd-repo-server
  endpoints:
  - port: metrics
EOF

# Create PrometheusRule for ArgoCD alerts
cat <<EOF | kubectl apply -f -
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: argocd-alerts
  namespace: argocd
  labels:
    app: argocd
spec:
  groups:
  - name: argocd
    rules:
    - alert: ArgoCDAppHealthDegraded
      expr: argocd_app_health_status{health_status!="Healthy"} == 1
      for: 15m
      labels:
        severity: critical
      annotations:
        summary: "ArgoCD Application health is degraded"
        description: "ArgoCD Application {{ \$labels.name }} health is {{ \$labels.health_status }}"
    
    - alert: ArgoCDAppSyncFailed
      expr: argocd_app_sync_total{phase="Failed"} > 0
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "ArgoCD Application sync failed"
        description: "ArgoCD Application {{ \$labels.name }} sync has failed"
    
    - alert: ArgoCDAppOutOfSync
      expr: argocd_app_sync_status{sync_status!="Synced"} == 1
      for: 30m
      labels:
        severity: warning
      annotations:
        summary: "ArgoCD Application is out of sync"
        description: "ArgoCD Application {{ \$labels.name }} is out of sync for more than 30 minutes"
EOF

print_success "GitOps monitoring configured"

# Display access information
echo ""
echo "🎯 GitOps Deployment Complete!"
echo "==============================="
echo ""
echo "Repository: $REPO_NAME"
echo "ArgoCD URL: https://localhost:8080 (port-forward active)"
echo "Username: admin"
echo "Password: $ARGOCD_PASSWORD"
echo ""
echo "Applications:"
echo "- ecommerce-microservices-dev (auto-sync enabled)"
echo "- ecommerce-microservices-staging (auto-sync enabled)"  
echo "- ecommerce-microservices-prod (manual sync required)"
echo ""
echo "To access ArgoCD UI:"
echo "1. Keep this terminal open (port-forward active)"
echo "2. Open browser: https://localhost:8080"
echo "3. Login with admin/$ARGOCD_PASSWORD"
echo ""
echo "To sync production manually:"
echo "argocd app sync ecommerce-microservices-prod --prune"
echo ""
echo "To view application status:"
echo "argocd app list"
echo ""
echo "Monitoring:"
echo "- ArgoCD metrics exposed to Prometheus"
echo "- Alerts configured for health and sync status"
echo ""

# Save deployment info
cat <<EOF > gitops-deployment-info.txt
GitOps Deployment Information
============================
Repository: $REPO_NAME
Deployment Date: $(date)
ArgoCD Password: $ARGOCD_PASSWORD

Applications Created:
- ecommerce-microservices-dev
- ecommerce-microservices-staging
- ecommerce-microservices-prod

Access Commands:
- Port forward: kubectl port-forward svc/argocd-server -n argocd 8080:443
- Login: argocd login localhost:8080 --username admin --password $ARGOCD_PASSWORD --insecure
- List apps: argocd app list
- Sync app: argocd app sync <app-name>

Monitoring:
- ArgoCD metrics integrated with Prometheus
- Alerts configured for application health and sync status
EOF

print_success "Deployment information saved to gitops-deployment-info.txt"

# Keep port-forward active
print_info "Port-forward to ArgoCD is active. Press Ctrl+C to stop."
wait $PORT_FORWARD_PID
