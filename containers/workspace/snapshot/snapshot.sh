#!/bin/bash

echo "Running pre-container setup..."
copy-paths.sh

echo "Building image..."
docker-compose build --no-cache
