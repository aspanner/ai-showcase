# GPU Time-Slicing Setup Guide

This guide helps you enable GPU time-slicing on your OpenShift cluster, allowing multiple workloads (e.g., rhaiis and llama-guard) to share the same GPU.

## For Fresh Installations

If you're installing the NVIDIA GPU Operator from scratch, use the comprehensive installation file:

```bash
oc apply -f nvidia-gpu-operator-with-timeslicing.yaml
```

See `NVIDIA-GPU-OPERATOR-INSTALL-GUIDE.md` for detailed instructions.

## For Existing GPU Operator Installations

This guide will help you enable GPU time-slicing on an existing OpenShift cluster with GPU Operator already installed.

## Prerequisites

- OpenShift cluster with NVIDIA GPU Operator installed
- Cluster admin privileges
- `oc` CLI tool configured and authenticated
- `jq` installed (for verification script)

## What is GPU Time-Slicing?

GPU time-slicing allows multiple workloads to time-share a single GPU. The NVIDIA driver schedules access to the GPU, allowing multiple containers to run on the same physical GPU. This is ideal for inference workloads where GPU utilization is not 100%.

**Note**: This provides time-sharing, not spatial partitioning. Both workloads will share GPU memory and compute, so performance may be slightly reduced compared to dedicated GPU access.

## Step-by-Step Instructions

### 1. Enable GPU Time-Slicing

Run the setup script:

```bash
./enable-gpu-timeslicing.sh
```

This script will:
- Create a ConfigMap with time-slicing configuration (2 replicas)
- Patch the NVIDIA GPU Operator ClusterPolicy
- Trigger a restart of the GPU device plugin pods

### 2. Wait for GPU Operator to Reconfigure

Monitor the GPU operator pods:

```bash
watch oc get pods -n nvidia-gpu-operator
```

Wait until all `nvidia-device-plugin-daemonset` pods are in `Running` state. This typically takes 2-3 minutes.

### 3. Verify Time-Slicing is Active

Run the verification script:

```bash
./verify-gpu-timeslicing.sh
```

**Expected output**: You should see `nvidia.com/gpu: "2"` in the node capacity, indicating that your single physical GPU now presents as 2 virtual GPUs.

### 4. Deploy Llama-Guard

Once time-slicing is confirmed, deploy the llama-guard service:

```bash
oc apply -f llama-guard-deployment.yml
```

### 5. Verify Both Deployments are Running

Check both namespaces:

```bash
oc get pods -n rhaiis
oc get pods -n llama-guard
```

Both pods should be in `Running` state and each using 1 GPU.

## Troubleshooting

### Issue: ClusterPolicy not found

If you get an error about `gpu-cluster-policy` not existing, check the actual name:

```bash
oc get clusterpolicy -n nvidia-gpu-operator
```

Then update the script with the correct name.

### Issue: GPU capacity still shows 1

- Ensure the device plugin pods have fully restarted
- Check the ConfigMap is applied: `oc get cm time-slicing-config -n nvidia-gpu-operator`
- Check ClusterPolicy: `oc get clusterpolicy gpu-cluster-policy -n nvidia-gpu-operator -o yaml`

### Issue: Pods stuck in Pending

Check GPU allocation:

```bash
oc describe node | grep -A 10 "Allocated resources"
```

### Performance Considerations

- Both workloads will share GPU memory (may need to reduce memory usage if VRAM is limited)
- GPU compute will be time-shared (expect some latency increase)
- For production with high throughput, consider using separate GPUs or GPU MIG (Multi-Instance GPU) if your GPU supports it

## Reverting Time-Slicing

To disable time-slicing and return to 1 GPU:

```bash
oc patch clusterpolicy gpu-cluster-policy \
  -n nvidia-gpu-operator \
  --type merge \
  --patch '{"spec": {"devicePlugin": {"config": {"name": ""}}}}'
```

## Configuration Details

The time-slicing configuration (`gpu-time-slicing-config.yaml`) sets:
- `replicas: 2` - Creates 2 virtual GPUs from 1 physical GPU
- `renameByDefault: false` - Keeps the original `nvidia.com/gpu` resource name

You can adjust `replicas` to create more virtual GPUs (e.g., 3 or 4), but be aware that more replicas means less GPU time per workload.

## Additional Resources

- [NVIDIA GPU Operator Documentation](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/)
- [OpenShift GPU Time-Slicing](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/gpu-sharing.html)
- [Red Hat OpenShift AI Documentation](https://access.redhat.com/documentation/en-us/red_hat_openshift_ai)
