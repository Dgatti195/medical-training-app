#!/bin/bash

# Quick start script for treatment extraction
# Usage: ./run_treatment_extraction.sh

echo "=========================================="
echo "TREATMENT EXTRACTION FOR 447 DISEASES"
echo "=========================================="
echo ""

# Check if virtual environment exists
if [ ! -d "medical_env" ]; then
    echo "❌ Virtual environment not found!"
    echo "Creating virtual environment..."
    python3 -m venv medical_env
    echo "Installing required packages..."
    ./medical_env/bin/pip install anthropic pdfplumber python-dotenv
fi

# Check if .env file exists
if [ ! -f "../config/.env" ]; then
    echo "❌ API key configuration not found!"
    echo "Please create ../config/.env with:"
    echo "ANTHROPIC_API_KEY=your_key_here"
    exit 1
fi

# Activate virtual environment and run
echo "✓ Environment ready"
echo "✓ Running treatment extractor..."
echo ""

./medical_env/bin/python3 treatment_extractor.py

echo ""
echo "=========================================="
echo "DONE!"
echo "=========================================="
