# NVIDIA GPU Operator Installation Guide with Time-Slicing

This guide provides step-by-step instructions for installing the NVIDIA GPU Operator on OpenShift with GPU time-slicing enabled from the start.

## Overview

This installation will:
1. Install the NVIDIA GPU Operator via OpenShift OperatorHub
2. Configure GPU time-slicing to allow multiple workloads to share a single GPU
3. Enable monitoring and validation components

## Prerequisites

### Cluster Requirements
- OpenShift 4.10 or later
- At least one node with NVIDIA GPU(s)
- Cluster admin privileges
- `oc` CLI tool installed and configured

### Verify GPU Hardware

Check that your node has NVIDIA GPU(s):

```bash
# Check for nodes with GPU
oc get nodes -o json | jq '.items[] | select(.status.capacity["nvidia.com/gpu"] != null) | {name: .metadata.name, gpus: .status.capacity["nvidia.com/gpu"]}'
```

If no GPUs are shown, verify the hardware:

```bash
# SSH to node and check
lspci | grep -i nvidia
```

## Installation Methods

### Method 1: Using the All-in-One YAML File (Recommended)

This method installs the GPU Operator and configures time-slicing in one step.

**Step 1:** Apply the configuration

```bash
oc apply -f nvidia-gpu-operator-with-timeslicing.yaml
```

**Step 2:** Wait for operator installation

The Subscription will trigger the GPU Operator installation. This takes 2-5 minutes.

```bash
# Watch operator installation
watch oc get csv -n nvidia-gpu-operator

# Wait for STATUS: Succeeded
```

**Step 3:** Wait for all GPU operator pods to be running

```bash
# Watch pods until all are Running
watch oc get pods -n nvidia-gpu-operator
```

Expected pods:
- `gpu-operator-*` - Operator controller
- `gpu-feature-discovery-*` - GPU discovery
- `nvidia-container-toolkit-daemonset-*` - Container runtime integration
- `nvidia-cuda-validator-*` - Validation (Completed status is OK)
- `nvidia-dcgm-*` - GPU monitoring
- `nvidia-dcgm-exporter-*` - Metrics exporter
- `nvidia-device-plugin-daemonset-*` - Device plugin with time-slicing
- `nvidia-driver-daemonset-*` - GPU driver
- `nvidia-node-status-exporter-*` - Node status
- `nvidia-operator-validator-*` - Validator

**Step 4:** Verify time-slicing is enabled

```bash
# Check GPU capacity - should show 2 (or your configured replica count)
oc get nodes -o json | jq '.items[] | select(.status.capacity["nvidia.com/gpu"] != null) | {name: .metadata.name, capacity: .status.capacity["nvidia.com/gpu"], allocatable: .status.allocatable["nvidia.com/gpu"]}'
```

Expected output:
```json
{
  "name": "your-node-name",
  "capacity": "2",
  "allocatable": "2"
}
```

If you see `"2"`, time-slicing is successfully configured! ✅

**Step 5:** Verify with the verification script

```bash
./verify-gpu-timeslicing.sh
```

### Method 2: Step-by-Step Installation

If you prefer to install components separately:

**Step 1:** Install GPU Operator via OperatorHub UI

1. Navigate to OpenShift Console → OperatorHub
2. Search for "NVIDIA GPU Operator"
3. Click "Install"
4. Select namespace: `nvidia-gpu-operator` (create if needed)
5. Click "Install"
6. Wait for installation to complete

**Step 2:** Apply time-slicing ConfigMap

```bash
oc apply -f gpu-time-slicing-config.yaml
```

**Step 3:** Create or update ClusterPolicy with time-slicing

```bash
# If ClusterPolicy doesn't exist yet, it will be created by the operator
# Wait for it to appear, then patch it:
oc patch clusterpolicy gpu-cluster-policy \
  -n nvidia-gpu-operator \
  --type merge \
  --patch '{"spec": {"devicePlugin": {"config": {"name": "time-slicing-config", "default": "any"}}}}'
```

**Step 4:** Wait for device plugin pods to restart and verify

```bash
watch oc get pods -n nvidia-gpu-operator -l app=nvidia-device-plugin-daemonset
```

## Troubleshooting

### Issue: Pods in CrashLoopBackOff

**Symptom:** `nvidia-device-plugin-daemonset` or `gpu-feature-discovery` pods crash

**Solution:**

1. Check the ConfigMap format:
```bash
oc get configmap time-slicing-config -n nvidia-gpu-operator -o yaml
```

2. Ensure the config structure is correct (resources under timeSlicing):
```yaml
data:
  any: |-
    version: v1
    flags:
      migStrategy: "none"
    sharing:
      timeSlicing:
        resources:
        - name: nvidia.com/gpu
          replicas: 2
```

3. Check device plugin logs:
```bash
oc logs -n nvidia-gpu-operator -l app=nvidia-device-plugin-daemonset --all-containers=true --tail=50
```

4. If config is wrong, update and restart:
```bash
oc apply -f gpu-time-slicing-config.yaml
oc delete pod -n nvidia-gpu-operator -l app=nvidia-device-plugin-daemonset
```

### Issue: GPU capacity still shows 1

**Cause:** Time-slicing config not applied or device plugin not restarted

**Solution:**

1. Verify ClusterPolicy references the ConfigMap:
```bash
oc get clusterpolicy gpu-cluster-policy -n nvidia-gpu-operator -o jsonpath='{.spec.devicePlugin.config}'
```

Expected: `{"default":"any","name":"time-slicing-config"}`

2. Force restart device plugin:
```bash
oc delete pod -n nvidia-gpu-operator -l app=nvidia-device-plugin-daemonset
```

3. Wait 1-2 minutes and recheck GPU capacity

### Issue: Driver pod fails to start

**Symptom:** `nvidia-driver-daemonset` pod fails

**Common causes:**
- Secure Boot enabled (not supported with NVIDIA drivers)
- Missing kernel headers
- Incompatible kernel version

**Solution:**

1. Check driver pod logs:
```bash
oc logs -n nvidia-gpu-operator -l app=nvidia-driver-daemonset --all-containers=true
```

2. For Secure Boot issues, disable Secure Boot in BIOS

3. For kernel issues, ensure node OS is up to date:
```bash
oc debug node/<node-name>
chroot /host
dnf update
```

### Issue: Validator pod fails

**Symptom:** `nvidia-operator-validator` or `nvidia-cuda-validator` fails

**Solution:**

Check validator logs for specific errors:
```bash
oc logs -n nvidia-gpu-operator nvidia-operator-validator-xxxxx
```

Usually validator failures indicate driver or runtime issues. Resolve driver/toolkit issues first.

## Configuration Options

### Adjusting Time-Slicing Replicas

To change the number of virtual GPUs (default is 2), edit the ConfigMap:

```yaml
sharing:
  timeSlicing:
    resources:
    - name: nvidia.com/gpu
      replicas: 4  # Change this number
```

Higher replicas = more workloads can share, but less GPU time per workload.

**Recommended values:**
- 2-3 replicas: For production inference workloads
- 4-8 replicas: For development/testing with light GPU usage
- 1 replica: Disables time-slicing (exclusive GPU access)

### Using Different Configs Per Node

You can create multiple configs and apply them to different nodes using labels:

1. Create multiple config sections in the ConfigMap:
```yaml
data:
  two-replicas: |-
    version: v1
    sharing:
      timeSlicing:
        resources:
        - name: nvidia.com/gpu
          replicas: 2
  four-replicas: |-
    version: v1
    sharing:
      timeSlicing:
        resources:
        - name: nvidia.com/gpu
          replicas: 4
```

2. Label nodes:
```bash
oc label node <node-name> nvidia.com/device-plugin.config=four-replicas
```

## Monitoring GPU Usage

### View GPU Metrics

```bash
# Check GPU usage via DCGM exporter
oc get pods -n nvidia-gpu-operator -l app=nvidia-dcgm-exporter

# Port-forward to view metrics
oc port-forward -n nvidia-gpu-operator <dcgm-exporter-pod> 9400:9400

# Access metrics at http://localhost:9400/metrics
```

### Check Pod GPU Allocation

```bash
# List all pods using GPUs
oc get pods --all-namespaces -o json | \
  jq -r '.items[] | select(.spec.containers[].resources.limits["nvidia.com/gpu"] != null) | 
  "\(.metadata.namespace)/\(.metadata.name): \(.spec.containers[].resources.limits["nvidia.com/gpu"]) GPU(s)"'
```

## Deploying Workloads with Time-Sliced GPUs

After time-slicing is enabled, deploy workloads normally. Each requests `nvidia.com/gpu: 1`:

```yaml
resources:
  limits:
    nvidia.com/gpu: 1
  requests:
    nvidia.com/gpu: 1
```

The device plugin will allocate time-sliced GPU access automatically.

## Uninstalling

To remove the GPU Operator:

```bash
# Delete ClusterPolicy (stops all GPU operator components)
oc delete clusterpolicy gpu-cluster-policy

# Uninstall operator
oc delete subscription gpu-operator-certified -n nvidia-gpu-operator
oc delete csv -n nvidia-gpu-operator $(oc get csv -n nvidia-gpu-operator -o name)

# Clean up namespace
oc delete namespace nvidia-gpu-operator
```

## Additional Resources

- [NVIDIA GPU Operator Documentation](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/)
- [OpenShift AI GPU Documentation](https://docs.redhat.com/en/documentation/red_hat_openshift_ai_self-managed/)
- [GPU Time-Slicing Guide](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/gpu-sharing.html)
- [NVIDIA DCGM Metrics](https://docs.nvidia.com/datacenter/dcgm/latest/dcgm-api/dcgm-api-field-ids.html)

## Next Steps

Once GPU time-slicing is verified:

1. Deploy your first workload (e.g., rhaiis):
   ```bash
   oc apply -f rhaiis-deployment.yml
   ```

2. Deploy your second workload (e.g., llama-guard):
   ```bash
   oc apply -f llama-guard-deployment.yml
   ```

3. Monitor GPU sharing:
   ```bash
   ./verify-gpu-timeslicing.sh
   ```

Both workloads will share the same physical GPU via time-slicing! 🎉
