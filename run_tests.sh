#!/bin/bash
set -e

echo "========================================================"
echo "          EVER DASH - COMPLETE TEST SUITE"
echo "========================================================"

# 1. Run Godot Engine Headless Unit & Integration Tests
echo ""
echo ">>> [1/2] Running Godot GDScript Client Tests..."
godot --headless --path . -s tests/test_auth_and_leaderboard.gd

# 2. Run Node.js / Supabase Schema & API Tests
echo ""
echo ">>> [2/2] Running Supabase Backend & Contract Tests..."
cd supabase
npm test
cd ..

echo ""
echo "========================================================"
echo "🎉 ALL TESTS PASSED ACROSS BOTH CLIENT AND BACKEND!"
echo "========================================================"
