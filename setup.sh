#!/bin/bash

# Update and install system dependencies
echo "Installing system dependencies..."
apt-get update
apt-get install -y python3-pip docker.io docker-compose

# Enable and start Docker service
systemctl enable docker
systemctl start docker

# Install Python dependencies
echo "Installing Python dependencies..."
python3 -m pip install --upgrade pip wheel setuptools
python3 -m pip install --upgrade acryl-datahub

# Start DataHub using Docker
echo "Starting DataHub..."
datahub docker quickstart

echo "DataHub setup complete! Access the UI at http://localhost:9002"
echo "Default credentials: username: datahub, password: datahub"
