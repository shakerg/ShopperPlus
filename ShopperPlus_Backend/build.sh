#!/bin/bash

# Build script for Shopper+ Backend images

set -e

echo "🏗️  Building Shopper+ Backend Images..."

# Configuration
REGISTRY=${REGISTRY:-your-registry.com}
TAG=${TAG:-latest}

echo "📋 Configuration:"
echo "  Registry: $REGISTRY"
echo "  Tag: $TAG"

# Build Tor Proxy image
echo "🔒 Building Tor Proxy image..."
cd ../tor-proxy
docker build -t $REGISTRY/tor-proxy:$TAG .
echo "✅ Tor Proxy image built: $REGISTRY/tor-proxy:$TAG"

# Build Backend image
echo "🎯 Building Backend image..."
cd ../ShopperPlus_Backend
docker build -t $REGISTRY/shopper-plus-backend:$TAG .
echo "✅ Backend image built: $REGISTRY/shopper-plus-backend:$TAG"

echo ""
echo "📤 Pushing images to registry..."

# Push images
docker push $REGISTRY/tor-proxy:$TAG
echo "✅ Tor Proxy image pushed"

docker push $REGISTRY/shopper-plus-backend:$TAG
echo "✅ Backend image pushed"

echo ""
echo "🎉 All images built and pushed successfully!"
echo ""
echo "🚀 Ready to deploy with:"
echo "  REGISTRY=$REGISTRY TAG=$TAG ./deploy.sh"
