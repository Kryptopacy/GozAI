#!/usr/bin/env bash
# GozAI Cloud Deployment Script
# Automates backend deployment to Google Cloud Run
# 
# Usage: ./deploy.sh [--project PROJECT_ID] [--region REGION]
#
# Prerequisites:
#   - gcloud CLI installed and authenticated
#   - Docker installed (for local builds)
#   - GEMINI_API_KEY set as environment variable or in .env

set -euo pipefail

# Configuration
PROJECT_ID="${1:-gozai-app}"
REGION="${2:-us-central1}"
SERVICE_NAME="gozai-backend"
IMAGE_NAME="gcr.io/${PROJECT_ID}/${SERVICE_NAME}"

echo "=== GozAI Cloud Deployment ==="
echo "Project: ${PROJECT_ID}"
echo "Region:  ${REGION}"
echo "Service: ${SERVICE_NAME}"
echo ""

# Step 1: Ensure gcloud and environment are configured
echo "[1/5] Configuring gcloud project and environment..."
if [[ -z "${GEMINI_API_KEY:-}" ]]; then
    # Try multiple common locations for secrets
    for env_file in ".env" "backend/.env" "assets/app.env"; do
        if [[ -f "$env_file" ]]; then
            echo "Attempting to load secrets from $env_file..."
            export $(grep GEMINI_API_KEY "$env_file" | xargs)
            if [[ -n "${GEMINI_API_KEY:-}" ]]; then break; fi
        fi
    done
fi

if [[ -z "${GEMINI_API_KEY:-}" ]]; then
    echo "ERROR: GEMINI_API_KEY is not set. Please set it as an environment variable or in one of: .env, backend/.env, assets/app.env"
    exit 1
fi

gcloud config set project "${PROJECT_ID}"

# Step 2: Enable required APIs
echo "[2/5] Enabling required Google Cloud APIs..."
gcloud services enable \
    run.googleapis.com \
    cloudbuild.googleapis.com \
    artifactregistry.googleapis.com \
    aiplatform.googleapis.com \
    generativelanguage.googleapis.com \
    --quiet

# Step 3: Build and push container image
echo "[3/5] Building container image..."
cd backend
gcloud builds submit --tag "${IMAGE_NAME}" --quiet
cd ..

# Step 4: Deploy to Cloud Run
echo "[4/5] Deploying to Cloud Run..."
gcloud run deploy "${SERVICE_NAME}" \
    --image "${IMAGE_NAME}" \
    --region "${REGION}" \
    --platform managed \
    --allow-unauthenticated \
    --memory 1Gi \
    --cpu 1 \
    --min-instances 0 \
    --max-instances 10 \
    --set-env-vars "GOOGLE_CLOUD_PROJECT=${PROJECT_ID},GEMINI_API_KEY=${GEMINI_API_KEY}" \
    --quiet

# Step 5: Get service URL
echo "[5/5] Deployment complete!"
SERVICE_URL=$(gcloud run services describe "${SERVICE_NAME}" \
    --region "${REGION}" \
    --format "value(status.url)")
echo ""
echo "=== Deployment Successful ==="
echo "Service URL: ${SERVICE_URL}"
echo ""
echo "Test with:"
echo "  curl ${SERVICE_URL}/health"
