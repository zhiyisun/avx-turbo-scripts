#!/bin/zsh

# Script to download and build the AVX-Turbo project
# Created on: May 20, 2025

set -e  # Exit immediately if a command exits with a non-zero status

echo "Starting AVX-Turbo download and build process..."

# Define working directory
WORK_DIR=$(pwd)
REPO_DIR="${WORK_DIR}/avx-turbo"

# Step 1: Clone the repository
echo "Cloning AVX-Turbo repository..."
if [ -d "${REPO_DIR}" ]; then
    echo "Repository directory already exists. Updating..."
    cd "${REPO_DIR}"
    git pull
else
    git clone https://github.com/travisdowns/avx-turbo.git
    cd "${REPO_DIR}"
fi

# Step 2: Build the project
echo "Building AVX-Turbo project..."
make clean
make

echo "Build completed successfully."
