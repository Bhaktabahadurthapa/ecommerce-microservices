#!/bin/bash

# EKS Cluster Setup Script for Ecommerce Microservices
# Repository: Bhaktabahadurthapa/ecommerce-microservices

set -e

# Configuration
CLUSTER_NAME="ecommerce-cluster"
REGION="us-west-2"
NODE_TYPE="t3.medium"
MIN_NODES=2
MAX_NODES=5
DESIRED_NODES=3

echo "🚀 Setting up EKS cluster for Ecommerce Microservices"
echo "Repository: Bhaktabahadurthapa/ecommerce-microservices"
echo "Cluster: $CLUSTER_NAME"
echo "Region: $REGION"

# Check prerequisites
echo "📋 Checking prerequisites..."

if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI not found. Installing..."
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    sudo ./aws/install
fi

if ! command -v eksctl &> /dev/null; then
    echo "❌ eksctl not found. Installing..."
    curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
    sudo mv /tmp/eksctl /usr/local/bin
fi

if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl not found. Installing..."
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
fi

# Verify AWS credentials
echo "🔐 Verifying AWS credentials..."
aws sts get-caller-identity

# Create EKS cluster
echo "🏗️ Creating EKS cluster..."
eksctl create cluster \
  --name $CLUSTER_NAME \
  --region $REGION \
  --nodegroup-name ecommerce-nodes \
  --node-type $NODE_TYPE \
  --nodes $DESIRED_NODES \
  --nodes-min $MIN_NODES \
  --nodes-max $MAX_NODES \
  --managed \
  --with-oidc \
  --ssh-access \
  --ssh-public-key ~/.ssh/id_rsa.pub \
  --full-ecr-access \
  --asg-access \
  --external-dns-access \
  --appmesh-access \
  --alb-ingress-access

# Update kubeconfig
echo "⚙️ Updating kubeconfig..."
aws eks update-kubeconfig --region $REGION --name $CLUSTER_NAME

# Create namespaces
echo "📁 Creating namespaces..."
kubectl create namespace ecommerce-dev --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace ecommerce-staging --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace ecommerce-prod --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

# Install AWS Load Balancer Controller
echo "🔧 Installing AWS Load Balancer Controller..."
curl -o iam_policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.4.7/docs/install/iam_policy.json

aws iam create-policy \
    --policy-name AWSLoadBalancerControllerIAMPolicy \
    --policy-document file://iam_policy.json || true

eksctl create iamserviceaccount \
  --cluster=$CLUSTER_NAME \
  --namespace=kube-system \
  --name=aws-load-balancer-controller \
  --role-name AmazonEKSLoadBalancerControllerRole \
  --attach-policy-arn=arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):policy/AWSLoadBalancerControllerIAMPolicy \
  --approve \
  --override-existing-serviceaccounts

# Add EKS chart repo
helm repo add eks https://aws.github.io/eks-charts
helm repo update

# Install AWS Load Balancer Controller
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=$CLUSTER_NAME \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller

# Install ArgoCD
echo "🔄 Installing ArgoCD for GitOps..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ArgoCD to be ready
echo "⏳ Waiting for ArgoCD to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s

# Get ArgoCD admin password
echo "🔑 Getting ArgoCD admin password..."
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
echo "ArgoCD Admin Password: $ARGOCD_PASSWORD"

# Install metrics server
echo "📊 Installing metrics server..."
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Install Prometheus and Grafana for monitoring
echo "📈 Installing monitoring stack..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Install Prometheus
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
  --set prometheus.prometheusSpec.podMonitorSelectorNilUsesHelmValues=false \
  --create-namespace

# Create storage class for persistent volumes
echo "💾 Creating storage class..."
cat <<EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: ebs-sc
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  fsType: ext4
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer
EOF

# Set default storage class
kubectl patch storageclass ebs-sc -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

# Create secrets for CI/CD
echo "🔐 Creating CI/CD secrets..."
kubectl create secret generic github-credentials \
  --from-literal=username=Bhaktabahadurthapa \
  --from-literal=token=YOUR_GITHUB_TOKEN \
  --namespace=argocd \
  --dry-run=client -o yaml | kubectl apply -f -

# Apply ArgoCD applications
echo "🚀 Applying ArgoCD applications..."
kubectl apply -f argocd/

# Display cluster information
echo "✅ EKS cluster setup complete!"
echo ""
echo "Cluster Information:"
echo "==================="
echo "Cluster Name: $CLUSTER_NAME"
echo "Region: $REGION"
echo "Endpoint: $(aws eks describe-cluster --name $CLUSTER_NAME --region $REGION --query cluster.endpoint --output text)"
echo ""
echo "ArgoCD Information:"
echo "=================="
echo "ArgoCD URL: Run 'kubectl port-forward svc/argocd-server -n argocd 8080:443' then access https://localhost:8080"
echo "Username: admin"
echo "Password: $ARGOCD_PASSWORD"
echo ""
echo "Monitoring:"
echo "==========="
echo "Grafana: Run 'kubectl port-forward svc/prometheus-grafana -n monitoring 3000:80' then access http://localhost:3000"
echo "Username: admin"
echo "Password: prom-operator"
echo ""
echo "Next Steps:"
echo "==========="
echo "1. Update GitHub token in argocd/applications.yaml"
echo "2. Configure Jenkins with cluster credentials"
echo "3. Set up Docker registry credentials"
echo "4. Run your CI/CD pipeline"
echo ""
echo "Repository: https://github.com/Bhaktabahadurthapa/ecommerce-microservices"

# Save cluster info to file
cat <<EOF > cluster-info.txt
EKS Cluster Information
======================
Repository: Bhaktabahadurthapa/ecommerce-microservices
Cluster Name: $CLUSTER_NAME
Region: $REGION
Endpoint: $(aws eks describe-cluster --name $CLUSTER_NAME --region $REGION --query cluster.endpoint --output text)

ArgoCD Admin Password: $ARGOCD_PASSWORD

Namespaces created:
- ecommerce-dev
- ecommerce-staging  
- ecommerce-prod
- monitoring
- argocd

Services installed:
- AWS Load Balancer Controller
- ArgoCD
- Prometheus & Grafana
- Metrics Server

Access Commands:
- ArgoCD: kubectl port-forward svc/argocd-server -n argocd 8080:443
- Grafana: kubectl port-forward svc/prometheus-grafana -n monitoring 3000:80
EOF

echo "📝 Cluster information saved to cluster-info.txt"
