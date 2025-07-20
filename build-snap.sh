#!/bin/bash

# Linux Photo Booth Snap Builder
# This script builds the snap package for the Linux Photo Booth application

set -e

echo "Starting Linux Photo Booth Snap build..."

# Check if snapcraft is installed
if ! command -v snapcraft &> /dev/null; then
    echo "ERROR: snapcraft is not installed. Please install it first:"
    echo "   sudo snap install snapcraft --classic"
    exit 1
fi

# Check if we're in the right directory
if [ ! -f "pubspec.yaml" ]; then
    echo "ERROR: pubspec.yaml not found. Please run this script from the project root."
    exit 1
fi

# Clean previous builds
echo "Cleaning previous builds..."
rm -rf build/
rm -f *.snap

# Build the snap package
echo "Building snap package..."
echo "Note: For Raspberry Pi (arm64) builds, use: snapcraft --destructive-mode"
snapcraft --use-lxd

# Check if build was successful
if ls linux-photo-booth_*.snap 1> /dev/null 2>&1; then
    echo "Snap package built successfully!"
    echo "Package: $(ls linux-photo-booth_*.snap)"
    echo ""
    echo "To install the snap package:"
    echo "   sudo snap install --dangerous linux-photo-booth_*.snap"
    echo ""
    echo "To test the snap package:"
    echo "   snapcraft try"
else
    echo "Snap package build failed!"
    exit 1
fi 