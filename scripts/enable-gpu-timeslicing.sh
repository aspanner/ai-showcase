#!/bin/bash

# Script to enable GPU time-slicing on OpenShift
# This allows multiple pods to share a single GPU

set -e

echo "========================================="
echo "GPU Time-Slicing Configuration Script"
echo "========================================="
echo ""

# Step 1: Create the time-slicing ConfigMap
echo "Step 1: Creating time-slicing ConfigMap..."
oc apply -f ../openshift/gpu-time-slicing-config.yaml

echo "✓ ConfigMap created"
echo ""

# Step 2: Patch the ClusterPolicy to use the time-slicing config
echo "Step 2: Patching NVIDIA GPU Operator ClusterPolicy..."
oc patch clusterpolicy gpu-cluster-policy \
  -n nvidia-gpu-operator \
  --type merge \
  --patch '{"spec": {"devicePlugin": {"config": {"name": "time-slicing-config", "default": "any"}}}}'

echo "✓ ClusterPolicy patched"
echo ""

# Step 3: Wait for GPU operator pods to restart
echo "Step 3: Waiting for GPU operator device plugin pods to restart..."
echo "This may take 2-3 minutes..."
sleep 10

# Check if pods are restarting
oc get pods -n nvidia-gpu-operator -l app=nvidia-device-plugin-daemonset

echo ""
echo "========================================="
echo "Configuration Applied Successfully!"
echo "========================================="
echo ""
echo "Next steps:"
echo "1. Wait for all nvidia-device-plugin-daemonset pods to be Running"
echo "2. Verify GPU time-slicing with: ./verify-gpu-timeslicing.sh"
echo "3. Deploy llama-guard: oc apply -f ../openshift/llama-guard-deployment.yml"
echo ""
