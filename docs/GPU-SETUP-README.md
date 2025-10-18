# GPU Setup Files Overview

This directory contains configuration files and scripts for setting up NVIDIA GPU Operator with time-slicing on OpenShift.

## Quick Start

### For New Installations
```bash
# Install GPU Operator with time-slicing enabled (all-in-one)
oc apply -f nvidia-gpu-operator-with-timeslicing.yaml

# Wait for operator to be ready (2-5 minutes)
watch oc get csv -n nvidia-gpu-operator

# Verify time-slicing is enabled
./verify-gpu-timeslicing.sh
```

### For Existing Installations
```bash
# Enable time-slicing on existing GPU Operator
./enable-gpu-timeslicing.sh

# Verify
./verify-gpu-timeslicing.sh
```

## Files Description

### Installation & Configuration Files

| File | Purpose | When to Use |
|------|---------|-------------|
| `nvidia-gpu-operator-with-timeslicing.yaml` | **All-in-one installation** - Installs GPU Operator and configures time-slicing | Fresh cluster setup or complete reinstall |
| `gpu-time-slicing-config.yaml` | ConfigMap for time-slicing configuration only | Adding time-slicing to existing GPU Operator |
| `rhaiis-deployment.yml` | Qwen2-VL-2B vision-language model deployment | Deploy VLM inference service |
| `llama-guard-deployment.yml` | Llama-Guard-3-8B safety model deployment | Deploy guardrail/safety service |

### Scripts

| Script | Purpose |
|--------|---------|
| `enable-gpu-timeslicing.sh` | Automated script to enable time-slicing on existing GPU Operator |
| `verify-gpu-timeslicing.sh` | Verify that time-slicing is correctly configured |
| `check-current-gpu-status.sh` | Check current GPU allocation and pod status |

### Documentation

| Document | Content |
|----------|---------|
| `NVIDIA-GPU-OPERATOR-INSTALL-GUIDE.md` | **Comprehensive installation guide** with troubleshooting |
| `GPU-TIMESLICING-SETUP.md` | Guide for enabling time-slicing on existing installations |
| `GPU-SETUP-README.md` | This file - overview of all GPU setup files |

## Workflow

### Scenario 1: Fresh Cluster Setup

```
1. Apply nvidia-gpu-operator-with-timeslicing.yaml
2. Wait for all pods to be Running
3. Verify with verify-gpu-timeslicing.sh
4. Deploy workloads (rhaiis-deployment.yml, llama-guard-deployment.yml)
```

### Scenario 2: Existing GPU Operator (Time-Slicing Not Configured)

```
1. Run enable-gpu-timeslicing.sh
2. Wait for device plugin pods to restart
3. Verify with verify-gpu-timeslicing.sh
4. Deploy additional workloads
```

### Scenario 3: Already Running One Workload, Want to Add Another

```
1. Check current status: ./check-current-gpu-status.sh
2. Enable time-slicing: ./enable-gpu-timeslicing.sh
3. Verify: ./verify-gpu-timeslicing.sh
4. Deploy second workload: oc apply -f llama-guard-deployment.yml
```

## GPU Time-Slicing Explained

**What it does:**
- Allows multiple pods to share a single physical GPU
- Each physical GPU appears as multiple virtual GPUs (default: 2)
- NVIDIA driver schedules GPU access among workloads

**When to use:**
- ✅ Multiple inference workloads with low-moderate GPU utilization
- ✅ Development/testing environments
- ✅ Cost optimization (share expensive GPU hardware)

**When NOT to use:**
- ❌ Workloads requiring 100% dedicated GPU performance
- ❌ Real-time applications with strict latency requirements
- ❌ Training workloads (use MIG or separate GPUs instead)

## Configuration Options

### Change Number of Virtual GPUs

Edit `gpu-time-slicing-config.yaml` and change `replicas`:

```yaml
resources:
- name: nvidia.com/gpu
  replicas: 4  # 1 physical GPU → 4 virtual GPUs
```

**Recommendations:**
- **2 replicas**: Production inference (balanced performance)
- **3-4 replicas**: Multiple moderate workloads
- **1 replica**: Disable time-slicing (exclusive access)

### Per-Node Configuration

For clusters with multiple GPU nodes, you can configure different time-slicing per node:

1. Create multiple configs in ConfigMap (e.g., "low-share", "high-share")
2. Label nodes: `oc label node <node> nvidia.com/device-plugin.config=high-share`

## Verification Commands

```bash
# Check GPU capacity (should show 2 with default config)
oc get nodes -o json | jq '.items[].status.capacity | select(.["nvidia.com/gpu"] != null)'

# Check all pods using GPUs
oc get pods --all-namespaces -o json | \
  jq -r '.items[] | select(.spec.containers[].resources.limits["nvidia.com/gpu"] != null) | 
  "\(.metadata.namespace)/\(.metadata.name): \(.spec.containers[].resources.limits["nvidia.com/gpu"]) GPU"'

# Check GPU operator pod status
oc get pods -n nvidia-gpu-operator

# View device plugin logs
oc logs -n nvidia-gpu-operator -l app=nvidia-device-plugin-daemonset --tail=50
```

## Troubleshooting Quick Reference

| Issue | Quick Fix |
|-------|-----------|
| Pods in CrashLoopBackOff | Check logs: `oc logs -n nvidia-gpu-operator <pod> --all-containers` |
| GPU capacity shows 1 | Restart device plugin: `oc delete pod -n nvidia-gpu-operator -l app=nvidia-device-plugin-daemonset` |
| "No resources" error | Check ConfigMap format in `gpu-time-slicing-config.yaml` |
| Cannot deploy 2nd workload | Verify time-slicing: `./verify-gpu-timeslicing.sh` |

See `NVIDIA-GPU-OPERATOR-INSTALL-GUIDE.md` for detailed troubleshooting.

## Support & Resources

- [NVIDIA GPU Operator Docs](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/)
- [OpenShift AI Documentation](https://access.redhat.com/documentation/en-us/red_hat_openshift_ai_self-managed/)
- [GPU Time-Slicing Guide](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/gpu-sharing.html)

## Summary

This setup enables efficient GPU sharing on OpenShift, allowing you to run multiple AI/ML inference workloads (like Qwen2-VL and Llama-Guard) on a single GPU node. Perfect for cost optimization in development, testing, or low-to-moderate traffic production environments.
