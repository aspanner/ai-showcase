#!/bin/bash

# Script to verify GPU time-slicing is enabled

echo "========================================="
echo "GPU Time-Slicing Verification"
echo "========================================="
echo ""

echo "1. Checking GPU operator pods status..."
oc get pods -n nvidia-gpu-operator -l app=nvidia-device-plugin-daemonset
echo ""

echo "2. Checking node GPU capacity..."
echo "Looking for nvidia.com/gpu count (should show 2 if time-slicing is active):"
oc get nodes -o json | jq '.items[].status.capacity | select(.["nvidia.com/gpu"] != null) | .["nvidia.com/gpu"]'
echo ""

echo "3. Checking node allocatable GPUs..."
oc get nodes -o json | jq '.items[].status.allocatable | select(.["nvidia.com/gpu"] != null)'
echo ""

echo "4. Checking GPU allocation across namespaces..."
echo ""
echo "Current GPU usage in rhaiis namespace:"
oc get pods -n rhaiis -o json | jq -r '.items[] | select(.spec.containers[].resources.limits["nvidia.com/gpu"] != null) | "\(.metadata.name): \(.spec.containers[].resources.limits["nvidia.com/gpu"]) GPU"'
echo ""

echo "Current GPU usage in llama-guard namespace (if deployed):"
oc get pods -n llama-guard -o json 2>/dev/null | jq -r '.items[] | select(.spec.containers[].resources.limits["nvidia.com/gpu"] != null) | "\(.metadata.name): \(.spec.containers[].resources.limits["nvidia.com/gpu"]) GPU"' || echo "llama-guard not yet deployed"
echo ""

echo "========================================="
echo "If the GPU capacity shows '2', time-slicing is enabled!"
echo "You can now deploy both workloads."
echo "========================================="
