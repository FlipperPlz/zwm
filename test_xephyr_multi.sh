#!/bin/bash
# test_xephyr_multi.sh - Test ZWM with multiple monitors in Xephyr
set -e

echo "╔══════════════════════════════════════╗"
echo "║   ZWM Multi-Monitor Xephyr Test     ║"
echo "╚══════════════════════════════════════╝"
echo ""

# Build zwm
echo "📦 Building zwm..."
cd /devel/zwm
zig build || {
    echo "❌ Build failed!"
    exit 1
}
echo "✅ Build successful!"
echo ""

# Check if Xephyr is installed
if ! command -v Xephyr &> /dev/null; then
    echo "❌ Xephyr not found. Install with:"
    echo "   sudo pacman -S xorg-server-xephyr  # Arch"
    echo "   sudo apt install xserver-xephyr    # Debian/Ubuntu"
    exit 1
fi

# Check if xterm is installed
if ! command -v xterm &> /dev/null; then
    echo "⚠️  xterm not found. Install with:"
    echo "   sudo pacman -S xterm  # Arch"
    echo "   sudo apt install xterm # Debian/Ubuntu"
fi

echo "🚀 Starting Xephyr with 2 monitors on display :1..."
echo "   Monitor 1: 1600x900 at (0,0)"
echo "   Monitor 2: 1366x768 at (1600,0)"

# Start Xephyr with two screens (simulating two monitors side by side)
Xephyr -screen 1600x900+0+0 -screen 1366x768+1600+0 -br -reset -terminate :1 2>/dev/null &
XEPHYR_PID=$!
echo "   Xephyr PID: $XEPHYR_PID"
sleep 3

# Check if Xephyr started
if ! ps -p $XEPHYR_PID > /dev/null; then
    echo "❌ Xephyr failed to start!"
    echo "   Please install Xephyr:"
    echo "   sudo pacman -S xorg-server-xephyr  # Arch"
    echo "   sudo apt install xserver-xephyr    # Debian/Ubuntu"
    exit 1
fi

echo "✅ Xephyr running on :1 with multi-monitor setup"
echo ""

echo "🪟 Starting zwm..."
DISPLAY=:1 ./zig-out/bin/zwm &
ZWM_PID=$!
echo "   ZWM PID: $ZWM_PID"
sleep 1

# Check if zwm started
if ! ps -p $ZWM_PID > /dev/null; then
    echo "❌ ZWM failed to start!"
    kill $XEPHYR_PID 2>/dev/null
    exit 1
fi

echo "✅ ZWM running!"
echo ""

# Launch test applications if xterm is available
if command -v xterm &> /dev/null; then
    echo "🪟 Launching test terminal on each monitor..."
    sleep 1
    
    # Launch terminals - they should appear on different monitors
    DISPLAY=:1 xterm -geometry 80x24+100+50 &
    DISPLAY=:1 xterm -geometry 80x24+1800+50 &
    
    echo "✅ Test terminals launched"
    echo ""
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✨ ZWM Multi-Monitor Test Running!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📋 What to check:"
echo "   1. Bar should appear on both monitors"
echo "   2. Windows should overlap on the correct monitors"
echo "   3. Windows should be within visible bounds"
echo "   4. Debug output should show monitor geometry"
echo ""
echo "📊 Expected setup:"
echo "   Monitor 0: 1600x900 at (0,0) - should have bar"
echo "   Monitor 1: 1366x768 at (1600,0) - should have bar"
echo ""
echo "Press Ctrl+C to stop and cleanup..."
echo ""

# Wait for user interrupt
trap "echo ''; echo '🛑 Stopping...'; kill $ZWM_PID $XEPHYR_PID 2>/dev/null; echo '✅ Cleanup complete!'; exit 0" INT

# Keep running
while ps -p $ZWM_PID > /dev/null && ps -p $XEPHYR_PID > /dev/null; do
    sleep 1
done

echo ""
echo "⚠️  Process terminated unexpectedly"
kill $ZWM_PID $XEPHYR_PID 2>/dev/null
echo "✅ Cleanup complete!"


