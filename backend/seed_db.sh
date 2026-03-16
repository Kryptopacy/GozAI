#!/usr/bin/env bash
# GozAI Database Seeding Script
# Run this from Google Cloud Shell to populate your Firestore database.

set -euo pipefail

echo "=== GozAI: Seeding Firestore Database ==="

# 1. Ensure we are in the backend directory
if [[ ! -f "seed_rag_firestore.py" ]]; then
    echo "Please run this script from inside the 'backend' directory."
    exit 1
fi

# 2. Set up a temporary Python virtual environment
echo "[1/3] Setting up temporary Python environment..."
python3 -m venv .seed_venv
source .seed_venv/bin/activate

# 3. Install required dependencies
echo "[2/3] Installing dependencies..."
pip install --quiet firebase-admin google-genai numpy

# 4. Run the seeding script
echo "[3/3] Running the seed script..."
python3 seed_rag_firestore.py

# 5. Cleanup
deactivate
rm -rf .seed_venv
echo "=== Seeding Complete! ==="
