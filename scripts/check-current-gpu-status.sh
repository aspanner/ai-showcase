#!/bin/bash
echo "Current GPU Status on Node:"
echo "=============================="
oc get nodes -o json | jq -r '.items[] | select(.status.capacity["nvidia.com/gpu"] != null) | "Node: \(.metadata.name)\nTotal GPU Capacity: \(.status.capacity["nvidia.com/gpu"])\nAllocatable GPUs: \(.status.allocatable["nvidia.com/gpu"])"'
echo ""
echo "Current GPU Usage:"
echo "=============================="
echo "rhaiis namespace:"
oc get pods -n rhaiis -o wide 2>/dev/null || echo "Not found"
echo ""
echo "llama-guard namespace:"
oc get pods -n llama-guard -o wide 2>/dev/null || echo "Not yet deployed"
