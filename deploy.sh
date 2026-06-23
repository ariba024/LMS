#!/usr/bin/env bash
# deploy.sh — build Flutter web + Docker image for AWS deployment
#
# Usage:
#   ./deploy.sh https://yourdomain.com [ecr-image-uri]
#
# Example:
#   ./deploy.sh https://yourdomain.com 123456789.dkr.ecr.ap-south-1.amazonaws.com/arresto-lms
#
# API_BASE_URL  — compiled into Flutter as the REST API base (dart-define)
# FOCUS_WS_URL  — derived automatically as wss://<same-domain>/ws/detect
#
# Both are baked into the Flutter JS bundle at build time and cannot be
# changed at runtime without rebuilding.

set -euo pipefail

API_BASE_URL="${1:-}"
LMS_IMAGE="${2:-arresto-lms}"

# ── Validate ───────────────────────────────────────────────────────────────────

if [ -z "$API_BASE_URL" ]; then
  echo "ERROR: API_BASE_URL is required."
  echo "Usage: ./deploy.sh https://yourdomain.com [ecr-image-uri]"
  exit 1
fi

if [[ "$API_BASE_URL" == http://localhost* ]]; then
  echo "ERROR: API_BASE_URL looks like a local address: $API_BASE_URL"
  echo "Pass your production domain, e.g. https://yourdomain.com"
  exit 1
fi

# Derive WebSocket URL from the same domain (attention backend is now merged
# into the main LMS backend — same host, same port, /ws/detect path).
FOCUS_WS_URL="${API_BASE_URL/https/wss}/ws/detect"

# ── Flutter web build ──────────────────────────────────────────────────────────

echo "==> Building Flutter web ..."
echo "    API_BASE_URL = $API_BASE_URL"
echo "    FOCUS_WS_URL = $FOCUS_WS_URL"

cd frontend-lms
flutter build web --release \
  --dart-define=API_BASE_URL="$API_BASE_URL" \
  --dart-define=FOCUS_WS_URL="$FOCUS_WS_URL"
cd ..

# ── Docker build ───────────────────────────────────────────────────────────────

echo "==> Building Docker image ($LMS_IMAGE) ..."
docker build -t "$LMS_IMAGE" .

# ── Done ───────────────────────────────────────────────────────────────────────

echo ""
echo "Done. Push and redeploy:"
echo "  docker push $LMS_IMAGE"
echo "  aws ecs update-service --cluster arresto-cluster --service arresto-lms-service --force-new-deployment"
