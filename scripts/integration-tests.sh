#!/bin/bash

# Integration Tests for E-commerce Microservices
# This script runs comprehensive integration tests across all services

set -e

echo "🧪 Starting Integration Tests for E-commerce Microservices"

# Configuration
FRONTEND_URL="http://localhost:8080"
CART_SERVICE_URL="http://localhost:7070"
PRODUCT_CATALOG_URL="http://localhost:3550"
CURRENCY_SERVICE_URL="http://localhost:7000"
CHECKOUT_SERVICE_URL="http://localhost:5050"
PAYMENT_SERVICE_URL="http://localhost:50051"
SHIPPING_SERVICE_URL="http://localhost:50051"
EMAIL_SERVICE_URL="http://localhost:8080"

# Test results directory
RESULTS_DIR="test-results"
mkdir -p $RESULTS_DIR

# Health Check Function
health_check() {
    local service_name=$1
    local service_url=$2
    local max_attempts=30
    local attempt=1
    
    echo "🔍 Health checking $service_name..."
    
    while [ $attempt -le $max_attempts ]; do
        if curl -f -s "$service_url/health" > /dev/null 2>&1; then
            echo "✅ $service_name is healthy"
            return 0
        fi
        
        echo "⏳ Waiting for $service_name (attempt $attempt/$max_attempts)..."
        sleep 5
        ((attempt++))
    done
    
    echo "❌ $service_name health check failed"
    return 1
}

# Test Frontend Service
test_frontend() {
    echo "🌐 Testing Frontend Service..."
    
    # Test home page
    if curl -f -s "$FRONTEND_URL" > /dev/null; then
        echo "✅ Frontend home page accessible"
    else
        echo "❌ Frontend home page test failed"
        return 1
    fi
    
    # Test product listing
    if curl -f -s "$FRONTEND_URL/products" > /dev/null; then
        echo "✅ Product listing accessible"
    else
        echo "❌ Product listing test failed"
        return 1
    fi
    
    # Test cart functionality
    if curl -f -s "$FRONTEND_URL/cart" > /dev/null; then
        echo "✅ Cart page accessible"
    else
        echo "❌ Cart page test failed"
        return 1
    fi
}

# Test Product Catalog Service
test_product_catalog() {
    echo "📦 Testing Product Catalog Service..."
    
    # Test product list endpoint
    response=$(curl -s "$PRODUCT_CATALOG_URL/products" | head -c 100)
    if [[ $response == *"product"* ]] || [[ $response == *"id"* ]]; then
        echo "✅ Product catalog API working"
    else
        echo "❌ Product catalog API test failed"
        return 1
    fi
}

# Test Cart Service
test_cart_service() {
    echo "🛒 Testing Cart Service..."
    
    local test_user_id="test-user-123"
    
    # Test get cart
    if curl -f -s "$CART_SERVICE_URL/cart?user_id=$test_user_id" > /dev/null; then
        echo "✅ Cart service GET working"
    else
        echo "❌ Cart service GET test failed"
        return 1
    fi
    
    # Test add item to cart
    if curl -f -s -X POST "$CART_SERVICE_URL/cart" \
        -H "Content-Type: application/json" \
        -d '{"user_id":"'$test_user_id'","product_id":"test-product","quantity":1}' > /dev/null; then
        echo "✅ Cart service POST working"
    else
        echo "❌ Cart service POST test failed"
        return 1
    fi
}

# Test Currency Service
test_currency_service() {
    echo "💱 Testing Currency Service..."
    
    # Test supported currencies
    response=$(curl -s "$CURRENCY_SERVICE_URL/currencies")
    if [[ $response == *"USD"* ]] || [[ $response == *"EUR"* ]]; then
        echo "✅ Currency service working"
    else
        echo "❌ Currency service test failed"
        return 1
    fi
}

# Test End-to-End User Journey
test_e2e_journey() {
    echo "🎯 Testing End-to-End User Journey..."
    
    local test_user_id="e2e-test-user-$(date +%s)"
    
    # 1. Browse products
    echo "1️⃣ Browsing products..."
    if ! curl -f -s "$FRONTEND_URL/products" > /dev/null; then
        echo "❌ E2E: Product browsing failed"
        return 1
    fi
    
    # 2. Add item to cart
    echo "2️⃣ Adding item to cart..."
    if ! curl -f -s -X POST "$CART_SERVICE_URL/cart" \
        -H "Content-Type: application/json" \
        -d '{"user_id":"'$test_user_id'","product_id":"e2e-product","quantity":2}' > /dev/null; then
        echo "❌ E2E: Add to cart failed"
        return 1
    fi
    
    # 3. View cart
    echo "3️⃣ Viewing cart..."
    if ! curl -f -s "$CART_SERVICE_URL/cart?user_id=$test_user_id" > /dev/null; then
        echo "❌ E2E: View cart failed"
        return 1
    fi
    
    # 4. Get shipping quote
    echo "4️⃣ Getting shipping quote..."
    if ! curl -f -s "$SHIPPING_SERVICE_URL/quote" \
        -H "Content-Type: application/json" \
        -d '{"address":{"country":"US","state":"CA","city":"San Francisco","zip":"94102"}}' > /dev/null; then
        echo "❌ E2E: Shipping quote failed"
        return 1
    fi
    
    echo "✅ End-to-End journey completed successfully"
}

# Test Service Communication
test_service_communication() {
    echo "🔗 Testing Service Communication..."
    
    # Test gRPC communication between services
    echo "Testing gRPC communication..."
    
    # Frontend to Product Catalog
    if curl -f -s "$FRONTEND_URL/api/products" > /dev/null; then
        echo "✅ Frontend -> Product Catalog communication working"
    else
        echo "❌ Frontend -> Product Catalog communication failed"
    fi
    
    # Frontend to Cart Service
    if curl -f -s "$FRONTEND_URL/api/cart" > /dev/null; then
        echo "✅ Frontend -> Cart Service communication working"
    else
        echo "❌ Frontend -> Cart Service communication failed"
    fi
}

# Test Database Connectivity
test_database_connectivity() {
    echo "🗄️ Testing Database Connectivity..."
    
    # Test Redis connectivity (used by cart service)
    if docker exec $(docker-compose ps -q redis) redis-cli ping | grep -q "PONG"; then
        echo "✅ Redis connectivity working"
    else
        echo "❌ Redis connectivity failed"
        return 1
    fi
}

# Test Security Headers
test_security_headers() {
    echo "🔒 Testing Security Headers..."
    
    # Test security headers on frontend
    headers=$(curl -I -s "$FRONTEND_URL" || echo "")
    
    if echo "$headers" | grep -q "X-Frame-Options"; then
        echo "✅ X-Frame-Options header present"
    else
        echo "⚠️ X-Frame-Options header missing"
    fi
    
    if echo "$headers" | grep -q "X-Content-Type-Options"; then
        echo "✅ X-Content-Type-Options header present"
    else
        echo "⚠️ X-Content-Type-Options header missing"
    fi
}

# Test Load Balancing and Resilience
test_resilience() {
    echo "🛡️ Testing Service Resilience..."
    
    # Test with multiple concurrent requests
    echo "Testing concurrent load..."
    for i in {1..10}; do
        curl -s "$FRONTEND_URL" > /dev/null &
    done
    wait
    
    # Check if services are still responsive
    if curl -f -s "$FRONTEND_URL" > /dev/null; then
        echo "✅ Service resilience test passed"
    else
        echo "❌ Service resilience test failed"
        return 1
    fi
}

# Performance Baseline Test
test_performance_baseline() {
    echo "⚡ Testing Performance Baseline..."
    
    # Simple response time test
    start_time=$(date +%s%N)
    curl -s "$FRONTEND_URL" > /dev/null
    end_time=$(date +%s%N)
    
    response_time=$(( (end_time - start_time) / 1000000 )) # Convert to milliseconds
    
    if [ $response_time -lt 2000 ]; then
        echo "✅ Performance baseline met (${response_time}ms < 2000ms)"
    else
        echo "⚠️ Performance baseline not met (${response_time}ms >= 2000ms)"
    fi
}

# Generate Test Report
generate_report() {
    echo "📊 Generating Test Report..."
    
    cat > "$RESULTS_DIR/integration-test-report.html" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Integration Test Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .success { color: green; }
        .failure { color: red; }
        .warning { color: orange; }
        .header { background-color: #f0f0f0; padding: 10px; border-radius: 5px; }
    </style>
</head>
<body>
    <div class="header">
        <h1>🧪 E-commerce Microservices Integration Test Report</h1>
        <p>Generated on: $(date)</p>
        <p>Build Version: ${BUILD_VERSION:-"local"}</p>
    </div>
    
    <h2>Test Summary</h2>
    <p>All integration tests completed. Check individual test results below.</p>
    
    <h2>Service Status</h2>
    <ul>
        <li class="success">✅ Frontend Service</li>
        <li class="success">✅ Product Catalog Service</li>
        <li class="success">✅ Cart Service</li>
        <li class="success">✅ Currency Service</li>
        <li class="success">✅ Database Connectivity</li>
    </ul>
    
    <h2>Test Coverage</h2>
    <ul>
        <li>Health Checks</li>
        <li>API Endpoints</li>
        <li>Service Communication</li>
        <li>End-to-End User Journey</li>
        <li>Security Headers</li>
        <li>Performance Baseline</li>
        <li>Resilience Testing</li>
    </ul>
</body>
</html>
EOF
    
    echo "📊 Test report generated: $RESULTS_DIR/integration-test-report.html"
}

# Main Test Execution
main() {
    echo "🚀 Starting Integration Test Suite..."
    echo "Timestamp: $(date)"
    
    # Wait for services to be ready
    echo "⏳ Waiting for services to be ready..."
    sleep 10
    
    # Health checks for all services
    health_check "Frontend" "$FRONTEND_URL"
    health_check "Product Catalog" "$PRODUCT_CATALOG_URL"
    health_check "Cart Service" "$CART_SERVICE_URL"
    health_check "Currency Service" "$CURRENCY_SERVICE_URL"
    
    # Run individual service tests
    test_frontend
    test_product_catalog
    test_cart_service
    test_currency_service
    
    # Run integration tests
    test_service_communication
    test_database_connectivity
    test_e2e_journey
    
    # Run security and performance tests
    test_security_headers
    test_resilience
    test_performance_baseline
    
    # Generate report
    generate_report
    
    echo "✅ Integration test suite completed successfully!"
    echo "📊 Results available in: $RESULTS_DIR/"
}

# Run tests
main "$@"
