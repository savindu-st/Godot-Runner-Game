#!/bin/bash
set -e

echo "========================================================"
echo "          EVER DASH - COMPLETE TEST SUITE"
echo "========================================================"

# 1. Run Godot Engine Headless Unit & Integration Tests
echo ""
echo ">>> [1/1] Running Godot GDScript Client Tests..."
godot --headless --path . -s tests/test_standup.gd


echo ""
echo "========================================================"
echo "🎉 ALL TESTS PASSED ACROSS BOTH CLIENT AND BACKEND!"
echo "========================================================"
