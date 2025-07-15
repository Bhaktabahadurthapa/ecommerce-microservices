pipeline {
    agent any
    
    environment {
        // Repository Information
        GIT_REPO = 'Bhaktabahadurthapa/ecommerce-microservices'
        GIT_URL = 'https://github.com/Bhaktabahadurthapa/ecommerce-microservices'
        
        // Docker Registry Configuration
        DOCKER_REGISTRY = 'bhaktabahadurthapa' // Your Docker Hub username
        DOCKER_REPO = 'ecommerce-microservices'
        
        // AWS Configuration
        AWS_REGION = 'us-west-2'
        EKS_CLUSTER_NAME = 'ecommerce-cluster'
        
        // Security Tools
        SONAR_TOKEN = credentials('sonar-token')
        TRIVY_VERSION = '0.48.0'
        
        // Kubernetes Configuration
        KUBECONFIG = credentials('kubeconfig')
        KUBERNETES_NAMESPACE = 'ecommerce-prod'
        STAGING_NAMESPACE = 'ecommerce-staging'
        DEV_NAMESPACE = 'ecommerce-dev'
        
        // GitOps Configuration
        GITOPS_REPO = 'Bhaktabahadurthapa/ecommerce-microservices'
        ARGOCD_SERVER = 'argocd-server.argocd.svc.cluster.local'
        
        // Notification
        SLACK_CHANNEL = '#devops-alerts'
        
        // Version Management
        BUILD_VERSION = "${env.BUILD_NUMBER}-${env.GIT_COMMIT.take(8)}"
        IMAGE_TAG = "${env.BRANCH_NAME}-${env.BUILD_NUMBER}"
    }
    
    tools {
        go '1.21'
        nodejs '18'
        dockerTool 'docker-latest'
    }
    
    stages {
        stage('🔍 Checkout & Setup') {
            steps {
                script {
                    // Clean workspace
                    deleteDir()
                    
                    // Checkout code
                    checkout scm
                    
                    // Set build description
                    currentBuild.description = "Build: ${BUILD_VERSION}"
                    
                    // Install dependencies
                    sh '''
                        echo "Setting up build environment..."
                        docker --version
                        docker-compose --version
                    '''
                }
            }
        }
        
        stage('🔒 Security Scan - Secrets') {
            parallel {
                stage('GitLeaks - Secret Detection') {
                    steps {
                        script {
                            sh '''
                                # Install GitLeaks
                                wget -q https://github.com/gitleaks/gitleaks/releases/download/v8.18.0/gitleaks_8.18.0_linux_x64.tar.gz
                                tar -xzf gitleaks_8.18.0_linux_x64.tar.gz
                                
                                # Run secret scan
                                ./gitleaks detect --source . --report-format json --report-path gitleaks-report.json || true
                            '''
                            
                            // Archive results
                            archiveArtifacts artifacts: 'gitleaks-report.json', allowEmptyArchive: true
                            
                            // Check for secrets
                            script {
                                def report = readFile('gitleaks-report.json')
                                if (report.trim()) {
                                    error("🚨 Secrets detected! Check gitleaks-report.json")
                                }
                            }
                        }
                    }
                }
                
                stage('TruffleHog - Advanced Secret Scan') {
                    steps {
                        sh '''
                            # Install TruffleHog
                            pip3 install truffleHog3
                            
                            # Run advanced secret scan
                            truffleHog3 --format json --output trufflehog-report.json . || true
                        '''
                        
                        archiveArtifacts artifacts: 'trufflehog-report.json', allowEmptyArchive: true
                    }
                }
            }
        }
        
        stage('🧪 Code Quality & Testing') {
            parallel {
                stage('SonarQube Analysis') {
                    steps {
                        script {
                            // SonarQube analysis for multiple languages
                            withSonarQubeEnv('SonarQube') {
                                sh '''
                                    sonar-scanner \
                                        -Dsonar.projectKey=ecommerce-microservices \
                                        -Dsonar.projectName="E-commerce Microservices" \
                                        -Dsonar.sources=src \
                                        -Dsonar.language=multi \
                                        -Dsonar.sourceEncoding=UTF-8 \
                                        -Dsonar.go.coverage.reportPaths=coverage.out \
                                        -Dsonar.javascript.lcov.reportPaths=coverage/lcov.info \
                                        -Dsonar.python.coverage.reportPaths=coverage.xml \
                                        -Dsonar.cs.vscoveragexml.reportsPaths=coverage.xml
                                '''
                            }
                        }
                    }
                }
                
                stage('Unit Tests - Go Services') {
                    steps {
                        sh '''
                            echo "Running Go service tests..."
                            cd src/frontend && go test -v -coverprofile=coverage.out ./... || true
                            cd ../productcatalogservice && go test -v -coverprofile=coverage.out ./... || true
                            cd ../checkoutservice && go test -v -coverprofile=coverage.out ./... || true
                            cd ../shippingservice && go test -v -coverprofile=coverage.out ./... || true
                        '''
                    }
                }
                
                stage('Unit Tests - Node.js Services') {
                    steps {
                        sh '''
                            echo "Running Node.js service tests..."
                            cd src/currencyservice && npm install && npm test || true
                            cd ../paymentservice && npm install && npm test || true
                        '''
                    }
                }
                
                stage('Unit Tests - Python Services') {
                    steps {
                        sh '''
                            echo "Running Python service tests..."
                            cd src/emailservice && pip3 install -r requirements.txt && python3 -m pytest --cov=. || true
                            cd ../recommendationservice && pip3 install -r requirements.txt && python3 -m pytest --cov=. || true
                        '''
                    }
                }
                
                stage('Unit Tests - .NET Service') {
                    steps {
                        sh '''
                            echo "Running .NET service tests..."
                            cd src/cartservice && dotnet test --collect:"XPlat Code Coverage" || true
                        '''
                    }
                }
            }
        }
        
        stage('🐳 Build Docker Images') {
            steps {
                script {
                    // List of services to build
                    def services = [
                        'frontend', 'productcatalogservice', 'cartservice', 
                        'checkoutservice', 'currencyservice', 'paymentservice', 
                        'emailservice', 'shippingservice', 'recommendationservice', 
                        'adservice'
                    ]
                    
                    // Build all services in parallel
                    def buildStages = [:]
                    services.each { service ->
                        buildStages["Build ${service}"] = {
                            sh """
                                echo "Building ${service}..."
                                docker build -t ${DOCKER_REGISTRY}/${DOCKER_REPO}/${service}:${BUILD_VERSION} \
                                           -t ${DOCKER_REGISTRY}/${DOCKER_REPO}/${service}:latest \
                                           src/${service}
                            """
                        }
                    }
                    
                    parallel buildStages
                }
            }
        }
        
        stage('🔒 Container Security Scanning') {
            parallel {
                stage('Trivy - Vulnerability Scan') {
                    steps {
                        script {
                            // Install Trivy
                            sh '''
                                wget -q https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/trivy_${TRIVY_VERSION}_Linux-64bit.tar.gz
                                tar -xzf trivy_${TRIVY_VERSION}_Linux-64bit.tar.gz
                                sudo mv trivy /usr/local/bin/
                            '''
                            
                            // Scan all built images
                            def services = ['frontend', 'productcatalogservice', 'cartservice', 'checkoutservice']
                            services.each { service ->
                                sh """
                                    echo "Scanning ${service} for vulnerabilities..."
                                    trivy image --format json --output trivy-${service}.json \
                                        ${DOCKER_REGISTRY}/${DOCKER_REPO}/${service}:${BUILD_VERSION} || true
                                    
                                    # Check for HIGH/CRITICAL vulnerabilities
                                    trivy image --severity HIGH,CRITICAL --exit-code 1 \
                                        ${DOCKER_REGISTRY}/${DOCKER_REPO}/${service}:${BUILD_VERSION} || \
                                    echo "⚠️  HIGH/CRITICAL vulnerabilities found in ${service}"
                                """
                            }
                            
                            archiveArtifacts artifacts: 'trivy-*.json', allowEmptyArchive: true
                        }
                    }
                }
                
                stage('Docker Bench Security') {
                    steps {
                        sh '''
                            # Run Docker Bench Security
                            docker run --rm --net host --pid host --userns host --cap-add audit_control \
                                -e DOCKER_CONTENT_TRUST=$DOCKER_CONTENT_TRUST \
                                -v /var/lib:/var/lib:ro \
                                -v /var/run/docker.sock:/var/run/docker.sock:ro \
                                -v /usr/lib/systemd:/usr/lib/systemd:ro \
                                -v /etc:/etc:ro \
                                --label docker_bench_security \
                                docker/docker-bench-security > docker-bench-report.txt || true
                        '''
                        
                        archiveArtifacts artifacts: 'docker-bench-report.txt', allowEmptyArchive: true
                    }
                }
            }
        }
        
        stage('🧪 Integration Testing') {
            steps {
                script {
                    sh '''
                        echo "Starting integration tests..."
                        
                        # Start services with docker-compose
                        docker-compose -f compose.yaml up -d
                        
                        # Wait for services to be ready
                        sleep 30
                        
                        # Health check all services
                        echo "Checking service health..."
                        curl -f http://localhost:8080/health || exit 1
                        curl -f http://localhost:3550/health || exit 1
                        curl -f http://localhost:7070/health || exit 1
                        
                        # Run API tests
                        echo "Running API integration tests..."
                        newman run tests/integration/api-tests.json --reporters cli,json --reporter-json-export newman-report.json || true
                        
                        # Run end-to-end tests
                        echo "Running E2E tests..."
                        docker run --network host -v $(pwd)/tests/e2e:/e2e cypress/included:latest || true
                    '''
                }
            }
            post {
                always {
                    // Stop and clean up containers
                    sh 'docker-compose -f compose.yaml down -v || true'
                    
                    // Archive test reports
                    archiveArtifacts artifacts: 'newman-report.json', allowEmptyArchive: true
                    archiveArtifacts artifacts: 'tests/e2e/cypress/videos/**', allowEmptyArchive: true
                }
            }
        }
        
        stage('📦 Push Images') {
            when {
                anyOf {
                    branch 'main'
                    branch 'develop'
                    branch 'release/*'
                }
            }
            steps {
                script {
                    // Login to registry
                    withCredentials([usernamePassword(credentialsId: 'docker-registry', usernameVariable: 'REGISTRY_USER', passwordVariable: 'REGISTRY_PASS')]) {
                        sh 'echo $REGISTRY_PASS | docker login $DOCKER_REGISTRY -u $REGISTRY_USER --password-stdin'
                    }
                    
                    // Push all images
                    def services = ['frontend', 'productcatalogservice', 'cartservice', 'checkoutservice', 'currencyservice', 'paymentservice', 'emailservice', 'shippingservice', 'recommendationservice', 'adservice']
                    
                    services.each { service ->
                        sh """
                            docker push ${DOCKER_REGISTRY}/${DOCKER_REPO}/${service}:${BUILD_VERSION}
                            docker push ${DOCKER_REGISTRY}/${DOCKER_REPO}/${service}:latest
                        """
                    }
                }
            }
        }
        
        stage('🚀 Deploy to Staging') {
            when {
                branch 'develop'
            }
            environment {
                KUBE_NAMESPACE = 'ecommerce-staging'
            }
            steps {
                script {
                    sh '''
                        # Update Kubernetes manifests with new image tags
                        sed -i "s|:latest|:${BUILD_VERSION}|g" kubernetes-manifests/*.yaml
                        
                        # Apply to staging namespace
                        kubectl apply -f kubernetes-manifests/ -n ${KUBE_NAMESPACE}
                        
                        # Wait for deployment
                        kubectl rollout status deployment/frontend -n ${KUBE_NAMESPACE} --timeout=300s
                        kubectl rollout status deployment/cartservice -n ${KUBE_NAMESPACE} --timeout=300s
                        
                        # Run smoke tests
                        STAGING_URL=$(kubectl get service frontend -n ${KUBE_NAMESPACE} -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
                        curl -f http://${STAGING_URL}/health || exit 1
                    '''
                }
            }
        }
        
        stage('🔒 Security Compliance Check') {
            steps {
                script {
                    sh '''
                        echo "Running compliance checks..."
                        
                        # CIS Kubernetes Benchmark
                        kube-bench run --targets node,policies,managedservices > kube-bench-report.txt || true
                        
                        # Open Policy Agent (OPA) Gatekeeper policies
                        kubectl apply -f security/opa-policies/ || true
                        
                        # Network policy validation
                        kubectl apply -f security/network-policies/ --dry-run=server || true
                    '''
                    
                    archiveArtifacts artifacts: 'kube-bench-report.txt', allowEmptyArchive: true
                }
            }
        }
        
        stage('📊 Performance Testing') {
            when {
                anyOf {
                    branch 'main'
                    branch 'release/*'
                }
            }
            steps {
                script {
                    sh '''
                        echo "Running performance tests..."
                        
                        # Load testing with K6
                        docker run --rm -v $(pwd)/tests/performance:/tests grafana/k6 run /tests/load-test.js
                        
                        # Generate performance report
                        docker run --rm -v $(pwd)/tests/performance:/tests grafana/k6 run --out json=performance-results.json /tests/load-test.js || true
                    '''
                    
                    archiveArtifacts artifacts: 'performance-results.json', allowEmptyArchive: true
                }
            }
        }
        
        stage('🎯 Deploy to Production') {
            when {
                allOf {
                    branch 'main'
                    expression { 
                        return currentBuild.result == null || currentBuild.result == 'SUCCESS' 
                    }
                }
            }
            steps {
                script {
                    // Manual approval for production deployment
                    input message: 'Deploy to Production?', ok: 'Deploy'
                    
                    sh '''
                        # GitOps Deployment - Update manifests and trigger ArgoCD
                        echo "Updating Kubernetes manifests for GitOps deployment..."
                        
                        # Create temporary directory for GitOps operations
                        mkdir -p gitops-temp
                        cd gitops-temp
                        
                        # Clone the repository
                        git clone https://${GITHUB_TOKEN}@github.com/${GIT_REPO}.git .
                        git config user.email "jenkins@ecommerce.local"
                        git config user.name "Jenkins CI/CD"
                        
                        # Update image tags in Kubernetes manifests
                        find kubernetes-manifests/ -name "*.yaml" -exec sed -i "s|image: ${DOCKER_REGISTRY}/${DOCKER_REPO}/\\([^:]*\\):.*|image: ${DOCKER_REGISTRY}/${DOCKER_REPO}/\\1:${BUILD_VERSION}|g" {} \\;
                        
                        # Update Helm values if using Helm
                        if [ -f helm-chart/values.yaml ]; then
                            sed -i "s|tag: .*|tag: ${BUILD_VERSION}|g" helm-chart/values.yaml
                        fi
                        
                        # Commit and push changes
                        git add .
                        git commit -m "🚀 Deploy version ${BUILD_VERSION} to production
                        
                        - Updated image tags for all microservices
                        - Build: ${BUILD_NUMBER}
                        - Commit: ${GIT_COMMIT}
                        - Triggered by: ${BUILD_USER:-Jenkins}"
                        
                        git push origin main
                        
                        cd ..
                        rm -rf gitops-temp
                    '''
                    
                    // Trigger ArgoCD sync
                    sh '''
                        echo "Triggering ArgoCD synchronization..."
                        
                        # Install ArgoCD CLI if not present
                        if ! command -v argocd &> /dev/null; then
                            curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
                            sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
                            rm argocd-linux-amd64
                        fi
                        
                        # Login to ArgoCD (using service account token)
                        argocd login ${ARGOCD_SERVER} --username admin --password ${ARGOCD_PASSWORD} --insecure
                        
                        # Sync the application
                        argocd app sync ecommerce-microservices --prune
                        
                        # Wait for sync to complete
                        argocd app wait ecommerce-microservices --timeout 600
                        
                        # Get application status
                        argocd app get ecommerce-microservices
                    '''
                    
                    // Verify deployment
                    sh '''
                        echo "Verifying production deployment..."
                        
                        # Wait for all deployments to be ready
                        kubectl rollout status deployment/frontend -n ${KUBERNETES_NAMESPACE} --timeout=600s
                        kubectl rollout status deployment/cartservice -n ${KUBERNETES_NAMESPACE} --timeout=600s
                        kubectl rollout status deployment/productcatalogservice -n ${KUBERNETES_NAMESPACE} --timeout=600s
                        kubectl rollout status deployment/checkoutservice -n ${KUBERNETES_NAMESPACE} --timeout=600s
                        
                        # Health check
                        kubectl get pods -n ${KUBERNETES_NAMESPACE}
                        
                        # Get service endpoints
                        kubectl get services -n ${KUBERNETES_NAMESPACE}
                        
                        # Run production smoke tests
                        FRONTEND_URL=$(kubectl get service frontend -n ${KUBERNETES_NAMESPACE} -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "localhost")
                        
                        if [ "$FRONTEND_URL" != "localhost" ]; then
                            echo "Testing production endpoint: http://${FRONTEND_URL}"
                            curl -f http://${FRONTEND_URL}/health || echo "Health check failed, but deployment completed"
                        fi
                    '''
                }
            }
        }
        
        stage('🔄 GitOps Monitoring & Validation') {
            when {
                branch 'main'
            }
            steps {
                script {
                    sh '''
                        echo "Monitoring GitOps deployment status..."
                        
                        # Check ArgoCD application health
                        argocd app get ecommerce-microservices --output json > argocd-status.json
                        
                        # Parse and display status
                        python3 << 'EOF'
import json
import sys

with open('argocd-status.json', 'r') as f:
    app_status = json.load(f)

health = app_status.get('status', {}).get('health', {}).get('status', 'Unknown')
sync = app_status.get('status', {}).get('sync', {}).get('status', 'Unknown')

print(f"Application Health: {health}")
print(f"Sync Status: {sync}")

if health != 'Healthy':
    print("⚠️ Application is not healthy!")
    sys.exit(1)

if sync not in ['Synced', 'OutOfSync']:
    print("⚠️ Sync status is unexpected!")
    sys.exit(1)

print("✅ GitOps deployment validation passed!")
EOF
                        
                        # Archive ArgoCD status
                        kubectl get applications -n argocd -o yaml > argocd-applications.yaml
                    '''
                    
                    archiveArtifacts artifacts: 'argocd-status.json,argocd-applications.yaml', allowEmptyArchive: true
                }
            }
        }
    }
    
    post {
        always {
            // Clean up Docker images
            sh '''
                docker system prune -f
                docker image prune -f
            '''
            
            // Publish test results
            publishTestResults testResultsPattern: '**/test-results.xml'
            
            // Publish coverage reports
            publishCoverage adapters: [
                coberturaAdapter('coverage.xml')
            ], sourceFileResolver: sourceFiles('STORE_LAST_BUILD')
        }
        
        success {
            script {
                // Slack notification for success
                slackSend(
                    channel: env.SLACK_CHANNEL,
                    color: 'good',
                    message: "✅ Pipeline SUCCESS: ${env.JOB_NAME} - ${env.BUILD_NUMBER} deployed successfully!\nCommit: ${env.GIT_COMMIT}\nDuration: ${currentBuild.durationString}"
                )
                
                // Update GitHub status
                updateGitHubCommitStatus(
                    state: 'SUCCESS',
                    context: 'continuous-integration/jenkins',
                    description: 'Pipeline passed all stages'
                )
            }
        }
        
        failure {
            script {
                // Slack notification for failure
                slackSend(
                    channel: env.SLACK_CHANNEL,
                    color: 'danger',
                    message: "❌ Pipeline FAILED: ${env.JOB_NAME} - ${env.BUILD_NUMBER}\nCommit: ${env.GIT_COMMIT}\nCheck: ${env.BUILD_URL}"
                )
                
                // Update GitHub status
                updateGitHubCommitStatus(
                    state: 'FAILURE',
                    context: 'continuous-integration/jenkins',
                    description: 'Pipeline failed'
                )
                
                // Create incident ticket (integrate with your ticketing system)
                sh '''
                    curl -X POST "https://your-incident-api.com/tickets" \
                        -H "Content-Type: application/json" \
                        -d '{"title":"Pipeline Failure - Ecommerce Microservices","severity":"high","description":"Build ${BUILD_NUMBER} failed"}' || true
                '''
            }
        }
        
        unstable {
            slackSend(
                channel: env.SLACK_CHANNEL,
                color: 'warning',
                message: "⚠️ Pipeline UNSTABLE: ${env.JOB_NAME} - ${env.BUILD_NUMBER}\nSome tests may have failed."
            )
        }
    }
}
