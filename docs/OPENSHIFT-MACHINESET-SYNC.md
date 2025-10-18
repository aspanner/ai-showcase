# OpenShift MachineSet Sync Guide

## Problem

When you manually change the EC2 instance type (e.g., using AWS console or the `convert-ec2-instance.sh` script), OpenShift's Machine API doesn't automatically detect the change. This causes:

- MachineSets still showing the old instance type
- Machine objects having outdated instance type information
- Node labels not reflecting the actual EC2 instance type
- Potential issues with cluster autoscaling or machine management

## Solution

We provide a script that synchronizes OpenShift's Machine API objects with the actual EC2 instance types.

## The Issue Explained

OpenShift on AWS uses several layers to manage infrastructure:

1. **EC2 Instances** - The actual virtual machines in AWS
2. **Machine Objects** - OpenShift's representation of individual instances
3. **MachineSet Objects** - OpenShift's template for creating Machines (similar to Deployments for Pods)
4. **Node Objects** - Kubernetes nodes registered in the cluster

When you change the EC2 instance type directly:
- ✅ EC2 instance type changes
- ❌ MachineSet still has old instance type
- ❌ Machine object still has old instance type
- ❌ Node labels show old instance type

## Usage

### Method 1: Automatic (Recommended)

After converting the EC2 instance type, the EC2 management script will automatically prompt you:

```bash
./scripts/convert-ec2-instance.sh

# After successful conversion:
Do you want to sync OpenShift MachineSets/Machines with the new instance type? [Y/n]: y
```

### Method 2: Manual Sync

Run the sync script manually after changing instance types:

```bash
# Auto-detect instance type from EC2
./scripts/sync-openshift-machineset.sh --auto-detect

# Or specify instance type manually
./scripts/sync-openshift-machineset.sh --instance-type g6.8xlarge

# Interactive mode (will prompt, defaults to g6.8xlarge if you press Enter)
./scripts/sync-openshift-machineset.sh
```

## What the Script Does

1. **Checks for MachineSets**
   - Lists all MachineSets in the cluster
   - Shows current vs. target instance types

2. **Updates MachineSets**
   - Patches each MachineSet with the new instance type
   - This ensures new Machines will be created with the correct type

3. **Updates Machines**
   - Patches existing Machine objects
   - Updates machine annotations with new instance type

4. **Updates Node Labels**
   - Updates node labels to reflect the actual instance type
   - Sets both `node.openshift.io/instance-type` and `beta.kubernetes.io/instance-type` labels

5. **Provides Summary**
   - Shows current state of MachineSets, Machines, and Nodes
   - Offers next steps if further action is needed

## Prerequisites

- OpenShift CLI (`oc`) installed and configured
- Access to the OpenShift cluster (the script will prompt you to login)
- Cluster admin permissions (to modify Machine API objects)
- AWS CLI installed (optional, for auto-detection)

**Note:** The script will verify your kubeconfig and prompt you to confirm you're connected to the correct cluster before making any changes.

## Example Output

```bash
$ ./scripts/sync-openshift-machineset.sh --auto-detect

============================================================
OpenShift MachineSet Sync
============================================================

Verifying OpenShift cluster connection...

[INFO] Currently connected to:
  User:    kube:admin
  Server:  https://api.cluster-xyz.example.com:6443
  Context: default/api-cluster-xyz-example-com:6443/kube:admin

Is this the correct OpenShift cluster? (y/n): y

[INFO] Verifying cluster connection...
[SUCCESS] Successfully connected to OpenShift cluster
[INFO] Cluster: ocp-cluster-xyz
[INFO] User: kube:admin
[INFO] Version: v1.27.6+f67aeb3

Current MachineSets:
NAME                                    INSTANCE-TYPE   REPLICAS
ocp-cluster-xyz-worker-us-east-2a      t3.xlarge       1

Enter new instance type [g6.8xlarge]: 
[INFO] Using default instance type: g6.8xlarge
[INFO] Target instance type: g6.8xlarge

Updating MachineSets...
[INFO] MachineSet: ocp-cluster-xyz-worker-us-east-2a
[INFO]   Current type: t3.xlarge
[INFO]   New type: g6.8xlarge
[INFO]   Patching MachineSet...
[SUCCESS]   MachineSet updated

[SUCCESS] All MachineSets updated

Updating existing Machine objects...
[INFO] Machine: ocp-cluster-xyz-worker-us-east-2a-abc123
[INFO]   Current type: t3.xlarge
[INFO]   Patching Machine...
[INFO]   Updating node labels: ip-10-0-1-100.ec2.internal
[SUCCESS]   Machine updated

[SUCCESS] All Machines updated

============================================================
Summary
============================================================

MachineSets updated:
NAME                                    INSTANCE-TYPE   REPLICAS
ocp-cluster-xyz-worker-us-east-2a      g6.8xlarge      1

Machines status:
NAME                                          PHASE     TYPE         REGION       ZONE            AGE
ocp-cluster-xyz-worker-us-east-2a-abc123     Running   g6.8xlarge   us-east-2    us-east-2a      5d

Nodes status:
NAME                              STATUS   ROLES    AGE   VERSION
ip-10-0-1-100.ec2.internal       Ready    worker   5d    v1.27.6+f67aeb3

[SUCCESS] OpenShift MachineSet sync completed!

[INFO] Next steps:
  1. Verify nodes show the correct instance type: oc get nodes -o wide
  2. Check machine status: oc get machines -n openshift-machine-api
  3. If needed, recreate machines: oc delete machine <machine-name> -n openshift-machine-api
  4. Wait for GPU operator to reinitialize if you have GPUs
```

## Verification

After running the sync script, verify the changes:

### Check MachineSets
```bash
oc get machinesets -n openshift-machine-api \
  -o custom-columns=NAME:.metadata.name,INSTANCE-TYPE:.spec.template.spec.providerSpec.value.instanceType,REPLICAS:.spec.replicas
```

### Check Machines
```bash
oc get machines -n openshift-machine-api -o wide
```

### Check Node Labels
```bash
oc get nodes --show-labels | grep instance-type
```

Or for specific node:
```bash
oc get node <node-name> -o jsonpath='{.metadata.labels.node\.openshift\.io/instance-type}'
```

## For Single-Node Clusters

If you're running a single-node OpenShift cluster (SNO), there might not be MachineSets. The script will detect this and update node labels directly:

```bash
[WARN] No MachineSets found in openshift-machine-api namespace
[WARN] This might be a single-node cluster or MachineSets are not used

[INFO] Attempting to update node information...
[INFO] Processing node: sno-node.example.com
[INFO]   Instance ID: i-1234567890abcdef0
[INFO]   Detected EC2 type: g6.8xlarge
[INFO]   Updating node labels with instance type: g6.8xlarge
[SUCCESS] Node labels updated
```

## Cluster Login Verification

The script includes built-in verification to ensure you're connected to the correct OpenShift cluster:

### If Already Logged In
The script will display your current connection details and ask for confirmation:
```
[INFO] Currently connected to:
  User:    kube:admin
  Server:  https://api.cluster-xyz.example.com:6443
  Context: default/api-cluster-xyz-example-com:6443/kube:admin

Is this the correct OpenShift cluster? (y/n):
```

- Type `y` to proceed with the current cluster
- Type `n` to login to a different cluster

### If Not Logged In
The script will prompt you to login:
```
[WARN] Not currently logged into any OpenShift cluster

Enter your OpenShift cluster URL (e.g., https://api.cluster.example.com:6443): https://api.cluster.example.com:6443

Enter username: admin
Enter password: ********

[INFO] Logging in to OpenShift cluster...
Login successful.
```

The password is hidden while you type for security.

### Login to Different Cluster
If you answer "n" when asked about the current cluster:
```
[WARN] Please login to the correct OpenShift cluster

Enter your OpenShift cluster URL (e.g., https://api.cluster.example.com:6443): https://api.prod.example.com:6443

Enter username: production-admin
Enter password: ****************

[INFO] Logging in to OpenShift cluster...
Login successful.

[INFO] Verifying cluster connection...
[SUCCESS] Successfully connected to OpenShift cluster
[INFO] Cluster: prod-cluster-xyz
[INFO] User: production-admin
[INFO] Version: v1.27.6+f67aeb3
```

The script prompts for username and password, with the password hidden for security.

## Troubleshooting

### Error: "Failed to login to OpenShift cluster"
This typically means:
- Invalid cluster URL
- Incorrect username or password
- Network connectivity issues
- Certificate verification failed

Try logging in manually first:
```bash
oc login <cluster-url> -u <username>
```

If you have certificate issues, you may need to add `--insecure-skip-tls-verify`:
```bash
oc login <cluster-url> -u <username> --insecure-skip-tls-verify
```

Once you've confirmed login works manually, run the script again.

### Error: "Could not patch Machine (may be immutable)"
Some Machine fields are immutable. The script updates what it can (annotations and labels) which should be sufficient for most use cases.

### MachineSets not found
If you see "No MachineSets found", this is normal for:
- Single-node OpenShift (SNO) clusters
- Manually provisioned clusters
- Some managed OpenShift services

The script will still update node labels in these cases.

### GPU Operator Not Detecting GPUs After Change
After changing to a GPU instance type:

1. Wait for the GPU operator pods to restart
2. Check GPU operator status:
   ```bash
   oc get pods -n nvidia-gpu-operator
   ```

3. If needed, restart GPU operator pods:
   ```bash
   oc delete pod -n nvidia-gpu-operator -l app=nvidia-driver-daemonset
   ```

4. Verify GPUs are detected:
   ```bash
   oc get nodes -o json | jq '.items[].status.capacity | select(.["nvidia.com/gpu"] != null)'
   ```

## Complete Workflow Example

Here's the complete process for changing an instance type:

```bash
# Step 1: Convert EC2 instance type
./scripts/convert-ec2-instance.sh
# Select your instance and new type
# Answer "y" when asked to sync OpenShift

# Step 2: Wait for cluster to stabilize (5-10 minutes)
watch oc get nodes

# Step 3: Verify the change
oc get machinesets -n openshift-machine-api
oc get machines -n openshift-machine-api
oc get nodes --show-labels | grep instance-type

# Step 4: If using GPUs, verify GPU detection
oc get nodes -o json | jq '.items[].status.capacity'

# Step 5: Restart affected workloads if needed
oc rollout restart deployment/<your-deployment> -n <namespace>
```

## Integration with EC2 Management Script

The EC2 instance management script automatically offers to run the OpenShift sync after successful instance type conversion:

```bash
./scripts/convert-ec2-instance.sh

# After conversion completes:
[SUCCESS] Operation completed successfully!
[INFO] Please wait up to 10 minutes for the OpenShift cluster to be up and running properly.

Do you want to sync OpenShift MachineSets/Machines with the new instance type? [Y/n]: 
```

If you choose "yes", the sync script runs automatically with the correct instance type.

## When to Run This Script

Run the sync script whenever:
- ✅ You manually change EC2 instance types via AWS console
- ✅ You use the `convert-ec2-instance.sh` script to convert instances
- ✅ You migrate from one instance family to another
- ✅ You upgrade to newer instance types (e.g., g5 → g6)
- ✅ MachineSets show incorrect instance types
- ✅ Node labels don't match actual EC2 instance types

## Important Notes

1. **No Downtime**: The script only updates metadata; it doesn't restart instances or nodes
2. **Idempotent**: Safe to run multiple times; it only updates what's needed
3. **Permissions**: Requires cluster-admin or sufficient RBAC permissions
4. **Read-Only Mode**: The script includes a dry-run mode (coming soon) to preview changes
5. **Backup**: While the script is safe, consider taking etcd backups before major changes

## Support

For issues or questions:
- Check OpenShift Machine API documentation: https://docs.openshift.com/container-platform/latest/machine_management/index.html
- Review Machine API operator logs: `oc logs -n openshift-machine-api -l api=clusterapi`

