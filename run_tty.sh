#!/bin/bash
# run_tty.sh - Run zwm from TTY
# This will replace your current X session!

set -e

echo "⚠️  WARNING: This will replace your current X session!"
echo "   Press Ctrl+C within 5 seconds to cancel..."
sleep 5

echo ""
echo "📦 Building zwm..."
cd /devel/zwm
zig build || {
    echo "❌ Build failed!"
    exit 1
}
echo "✅ Build successful!"
echo ""

echo "🚀 Starting zwm..."
startx ./zig-out/bin/zwm

