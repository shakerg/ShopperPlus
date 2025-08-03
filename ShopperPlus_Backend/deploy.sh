#!/bin/bash

# Shopper+ Backend Deployment Script for OpenShift/Kubernetes

set -e

echo "🚀 Deploying Shopper+ Backend to OpenShift/Kubernetes..."

# Configuration
NAMESPACE=${NAMESPACE:-shopper-plus}
VERSION="v1.0.4"  # Enhanced admin dashboard with charts, graphs, and improved Amazon scraping
REGISTRY=${REGISTRY:-your-registry.com}
TAG=${TAG:-latest}

echo "📋 Configuration:"
echo "  Namespace: $NAMESPACE"
echo "  Registry: $REGISTRY"
echo "  Tag: $TAG"

# Create namespace if it doesn't exist
echo "📦 Creating namespace..."
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# Set current namespace
kubectl config set-context --current --namespace=$NAMESPACE

echo "🔧 Applying configuration and secrets..."
# Apply ConfigMap and Secrets
kubectl apply -f k8s/configmap.yaml -n $NAMESPACE
kubectl apply -f k8s/secrets.yaml -n $NAMESPACE

echo "🗄️  Deploying PostgreSQL..."
kubectl apply -f k8s/postgresql.yaml -n $NAMESPACE

echo "⚡ Deploying Memcached..."
kubectl apply -f k8s/memcached.yaml -n $NAMESPACE

echo "🔒 Deploying Tor Proxy..."
# Update Tor proxy image tag
sed "s|your-registry/tor-proxy:latest|$REGISTRY/tor-proxy:$TAG|g" k8s/tor-proxy.yaml | kubectl apply -f - -n $NAMESPACE

echo "🎯 Deploying Backend Services..."
# Update backend image tag
sed "s|your-registry/shopper-plus-backend:latest|$REGISTRY/shopper-plus-backend:$TAG|g" k8s/backend.yaml | kubectl apply -f - -n $NAMESPACE

# Apply route for OpenShift
if kubectl api-resources | grep -q "routes"; then
    echo "🌐 Creating OpenShift Route..."
    kubectl apply -f k8s/route.yaml -n $NAMESPACE
else
    echo "📝 Note: Not running on OpenShift, skipping Route creation"
    echo "   You may need to create an Ingress for external access"
fi

echo "⏳ Waiting for deployments to be ready..."

# Wait for PostgreSQL to be ready
echo "  Waiting for PostgreSQL..."
kubectl wait --for=condition=available --timeout=300s deployment/postgresql -n $NAMESPACE

# Wait for Memcached to be ready
echo "  Waiting for Memcached..."
kubectl wait --for=condition=available --timeout=300s deployment/memcached -n $NAMESPACE

# Wait for Tor Proxy to be ready
echo "  Waiting for Tor Proxy..."
kubectl wait --for=condition=available --timeout=300s deployment/tor-proxy -n $NAMESPACE

# Wait for Backend to be ready
echo "  Waiting for Backend..."
kubectl wait --for=condition=available --timeout=300s deployment/shopper-plus-backend -n $NAMESPACE

# Wait for Scraper to be ready
echo "  Waiting for Scraper..."
kubectl wait --for=condition=available --timeout=300s deployment/shopper-plus-scraper -n $NAMESPACE

echo "✅ Deployment completed successfully!"
echo ""
echo "📊 Deployment Status:"
kubectl get pods -n $NAMESPACE
echo ""
kubectl get services -n $NAMESPACE
echo ""

# Get route URL if available
if kubectl api-resources | grep -q "routes"; then
    ROUTE_URL=$(kubectl get route shopper-plus-backend -n $NAMESPACE -o jsonpath='{.spec.host}' 2>/dev/null || echo "")
    if [ ! -z "$ROUTE_URL" ]; then
        echo "🌐 Application URL: https://$ROUTE_URL"
        echo "🔍 Health Check: https://$ROUTE_URL/health"
    fi
fi

echo ""
echo "📋 Useful Commands:"
echo "  View logs: kubectl logs -f deployment/shopper-plus-backend -n $NAMESPACE"
echo "  View scraper logs: kubectl logs -f deployment/shopper-plus-scraper -n $NAMESPACE"
echo "  Scale backend: kubectl scale deployment shopper-plus-backend --replicas=5 -n $NAMESPACE"
echo "  Port forward: kubectl port-forward service/shopper-plus-backend-service 8080:80 -n $NAMESPACE"
echo ""
echo "🎉 Happy scraping!"
