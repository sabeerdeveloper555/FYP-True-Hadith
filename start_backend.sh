#!/bin/bash

echo "Starting Flask Backend Server..."
echo ""

# Check if virtual environment exists
if [ ! -d "venv" ]; then
    echo "Creating virtual environment..."
    python3 -m venv venv
fi

# Activate virtual environment
source venv/bin/activate

# Install dependencies if needed
echo "Installing/Updating dependencies..."
pip install -r requirements.txt

echo ""
echo "Starting Flask server on http://localhost:5000"
echo "Press Ctrl+C to stop the server"
echo ""

# Run Flask backend
python backend_api_example.py

