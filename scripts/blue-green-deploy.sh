#!/bin/bash

# Blue-Green Deployment Script for Kubernetes
# Implements zero-downtime deployment strategy

set -e

VERSION=${1:-"latest"}
NAMESPACE=${2:-"ecommerce-prod"}
SERVICE=${3:-"frontend"}

echo "🔵 Starting Blue-Green Deployment"
echo "Version: $VERSION"
echo "Namespace: $NAMESPACE"
echo "Service: $SERVICE"

# Colors for output
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Configuration
REGISTRY="your-registry.com"
REPO="ecommerce-microservices"
HEALTH_CHECK_TIMEOUT=300
HEALTH_CHECK_INTERVAL=10

# Get current active deployment
get_active_deployment() {
    local current_selector=$(kubectl get service $SERVICE -n $NAMESPACE -o jsonpath='{.spec.selector.version}' 2>/dev/null || echo "")
    if [[ $current_selector == *"blue"* ]]; then
        echo "blue"
    elif [[ $current_selector == *"green"* ]]; then
        echo "green"
    else
        echo "blue" # Default to blue if no version selector
    fi
}

# Health check function
health_check() {
    local deployment=$1
    local timeout=$2
    local interval=$3
    
    echo "🔍 Health checking $deployment deployment..."
    
    local elapsed=0
    while [ $elapsed -lt $timeout ]; do
        # Check pod readiness
        local ready_pods=$(kubectl get deployment ${SERVICE}-${deployment} -n $NAMESPACE -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
        local desired_pods=$(kubectl get deployment ${SERVICE}-${deployment} -n $NAMESPACE -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "1")
        
        if [ "$ready_pods" == "$desired_pods" ] && [ "$ready_pods" != "0" ]; then
            echo "✅ $deployment deployment is healthy ($ready_pods/$desired_pods pods ready)"
            return 0
        fi
        
        echo "⏳ Waiting for $deployment deployment... ($ready_pods/$desired_pods pods ready)"
        sleep $interval
        elapsed=$((elapsed + interval))
    done
    
    echo "❌ Health check failed for $deployment deployment"
    return 1
}

# Application health check
app_health_check() {
    local deployment=$1
    local service_url="http://${SERVICE}-${deployment}.${NAMESPACE}.svc.cluster.local"
    
    echo "🔍 Checking application health for $deployment..."
    
    # Port-forward for testing (in real scenario, use internal service discovery)
    kubectl port-forward service/${SERVICE}-${deployment} 8080:80 -n $NAMESPACE &
    local port_forward_pid=$!
    
    sleep 5
    
    # Test application endpoints
    local health_status=0
    
    if curl -f -s --max-time 10 "http://localhost:8080/health" > /dev/null; then
        echo "✅ Health endpoint responding"
    else
        echo "❌ Health endpoint failed"
        health_status=1
    fi
    
    if curl -f -s --max-time 10 "http://localhost:8080/" > /dev/null; then
        echo "✅ Main application responding"
    else
        echo "❌ Main application failed"
        health_status=1
    fi
    
    # Cleanup port-forward
    kill $port_forward_pid 2>/dev/null || true
    
    return $health_status
}

# Deploy to inactive environment
deploy_inactive() {
    local active=$1
    local inactive=$2
    
    echo -e "${BLUE}🚀 Deploying to $inactive environment${NC}"
    
    # Create deployment manifest
    cat << EOF > /tmp/${SERVICE}-${inactive}-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${SERVICE}-${inactive}
  namespace: $NAMESPACE
  labels:
    app: $SERVICE
    version: $inactive
spec:
  replicas: 3
  selector:
    matchLabels:
      app: $SERVICE
      version: $inactive
  template:
    metadata:
      labels:
        app: $SERVICE
        version: $inactive
    spec:
      containers:
      - name: $SERVICE
        image: ${REGISTRY}/${REPO}/${SERVICE}:${VERSION}
        ports:
        - containerPort: 8080
        env:
        - name: VERSION
          value: $inactive
        - name: BUILD_VERSION
          value: $VERSION
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
            cpu: "500m"
---
apiVersion: v1
kind: Service
metadata:
  name: ${SERVICE}-${inactive}
  namespace: $NAMESPACE
  labels:
    app: $SERVICE
    version: $inactive
spec:
  selector:
    app: $SERVICE
    version: $inactive
  ports:
  - port: 80
    targetPort: 8080
  type: ClusterIP
EOF

    # Apply deployment
    kubectl apply -f /tmp/${SERVICE}-${inactive}-deployment.yaml
    
    # Wait for deployment to be ready
    echo "⏳ Waiting for $inactive deployment to be ready..."
    kubectl rollout status deployment/${SERVICE}-${inactive} -n $NAMESPACE --timeout=${HEALTH_CHECK_TIMEOUT}s
    
    # Health check
    if health_check $inactive $HEALTH_CHECK_TIMEOUT $HEALTH_CHECK_INTERVAL; then
        echo -e "${GREEN}✅ $inactive deployment is healthy${NC}"
    else
        echo -e "${RED}❌ $inactive deployment failed health check${NC}"
        return 1
    fi
    
    # Application health check
    if app_health_check $inactive; then
        echo -e "${GREEN}✅ $inactive application is healthy${NC}"
    else
        echo -e "${RED}❌ $inactive application failed health check${NC}"
        return 1
    fi
}

# Switch traffic to new deployment
switch_traffic() {
    local new_active=$1
    
    echo -e "${YELLOW}🔄 Switching traffic to $new_active environment${NC}"
    
    # Update service selector to point to new deployment
    kubectl patch service $SERVICE -n $NAMESPACE -p '{"spec":{"selector":{"version":"'$new_active'"}}}'
    
    echo -e "${GREEN}✅ Traffic switched to $new_active${NC}"
    
    # Verify traffic switch
    sleep 10
    local current_selector=$(kubectl get service $SERVICE -n $NAMESPACE -o jsonpath='{.spec.selector.version}')
    if [[ $current_selector == $new_active ]]; then
        echo -e "${GREEN}✅ Traffic switch verified${NC}"
    else
        echo -e "${RED}❌ Traffic switch verification failed${NC}"
        return 1
    fi
}

# Cleanup old deployment
cleanup_old() {
    local old_deployment=$1
    
    echo -e "${YELLOW}🧹 Cleaning up $old_deployment environment${NC}"
    
    # Scale down old deployment
    kubectl scale deployment ${SERVICE}-${old_deployment} --replicas=0 -n $NAMESPACE
    
    # Optional: Delete old deployment after some time
    echo "ℹ️ Old deployment scaled to 0. Delete manually when confident: kubectl delete deployment ${SERVICE}-${old_deployment} -n $NAMESPACE"
}

# Rollback function
rollback() {
    local rollback_to=$1
    
    echo -e "${RED}🔙 Rolling back to $rollback_to environment${NC}"
    
    # Switch traffic back
    kubectl patch service $SERVICE -n $NAMESPACE -p '{"spec":{"selector":{"version":"'$rollback_to'"}}}'
    
    # Scale up rollback deployment if needed
    kubectl scale deployment ${SERVICE}-${rollback_to} --replicas=3 -n $NAMESPACE
    
    echo -e "${GREEN}✅ Rollback completed${NC}"
}

# Monitoring and alerting
send_notification() {
    local status=$1
    local message=$2
    
    # Slack notification (replace with your webhook)
    curl -X POST -H 'Content-type: application/json' \
        --data '{"text":"'$status': '$message'"}' \
        $SLACK_WEBHOOK_URL 2>/dev/null || true
    
    # Email notification (configure your email service)
    echo "$message" | mail -s "Deployment $status: $SERVICE" $NOTIFICATION_EMAIL || true
}

# Main deployment function
main() {
    echo -e "${BLUE}🚀 Blue-Green Deployment Starting${NC}"
    echo "Service: $SERVICE"
    echo "Version: $VERSION"
    echo "Namespace: $NAMESPACE"
    echo "Timestamp: $(date)"
    
    # Get current active deployment
    local current_active=$(get_active_deployment)
    local target_inactive
    
    if [[ $current_active == "blue" ]]; then
        target_inactive="green"
    else
        target_inactive="blue"
    fi
    
    echo "Current active: $current_active"
    echo "Target inactive: $target_inactive"
    
    # Send start notification
    send_notification "STARTED" "Blue-Green deployment started for $SERVICE:$VERSION"
    
    # Step 1: Deploy to inactive environment
    echo -e "${BLUE}Step 1: Deploying to $target_inactive environment${NC}"
    if deploy_inactive $current_active $target_inactive; then
        echo -e "${GREEN}✅ Deployment to $target_inactive successful${NC}"
    else
        echo -e "${RED}❌ Deployment to $target_inactive failed${NC}"
        send_notification "FAILED" "Deployment to $target_inactive failed for $SERVICE:$VERSION"
        exit 1
    fi
    
    # Step 2: Run final validation
    echo -e "${BLUE}Step 2: Final validation${NC}"
    if app_health_check $target_inactive; then
        echo -e "${GREEN}✅ Final validation passed${NC}"
    else
        echo -e "${RED}❌ Final validation failed${NC}"
        send_notification "FAILED" "Final validation failed for $SERVICE:$VERSION"
        exit 1
    fi
    
    # Step 3: Switch traffic
    echo -e "${BLUE}Step 3: Switching traffic${NC}"
    if switch_traffic $target_inactive; then
        echo -e "${GREEN}✅ Traffic switch successful${NC}"
    else
        echo -e "${RED}❌ Traffic switch failed, rolling back${NC}"
        rollback $current_active
        send_notification "FAILED" "Traffic switch failed, rolled back for $SERVICE:$VERSION"
        exit 1
    fi
    
    # Step 4: Post-deployment validation
    echo -e "${BLUE}Step 4: Post-deployment validation${NC}"
    sleep 30 # Wait for traffic to stabilize
    
    if app_health_check $target_inactive; then
        echo -e "${GREEN}✅ Post-deployment validation passed${NC}"
    else
        echo -e "${RED}❌ Post-deployment validation failed, rolling back${NC}"
        rollback $current_active
        send_notification "FAILED" "Post-deployment validation failed, rolled back for $SERVICE:$VERSION"
        exit 1
    fi
    
    # Step 5: Cleanup old deployment
    echo -e "${BLUE}Step 5: Cleanup${NC}"
    cleanup_old $current_active
    
    echo -e "${GREEN}🎉 Blue-Green deployment completed successfully!${NC}"
    echo "New active environment: $target_inactive"
    echo "Version deployed: $VERSION"
    
    # Send success notification
    send_notification "SUCCESS" "Blue-Green deployment completed successfully for $SERVICE:$VERSION. New active: $target_inactive"
    
    # Cleanup temp files
    rm -f /tmp/${SERVICE}-${target_inactive}-deployment.yaml
}

# Error handling
trap 'echo -e "${RED}❌ Deployment failed unexpectedly${NC}"; exit 1' ERR

# Validate prerequisites
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}❌ kubectl is required but not installed${NC}"
    exit 1
fi

if ! kubectl get namespace $NAMESPACE &> /dev/null; then
    echo -e "${RED}❌ Namespace $NAMESPACE does not exist${NC}"
    exit 1
fi

# Run deployment
main "$@"
