#!/bin/bash

# OpenShift MachineSet Sync Script
# This script updates OpenShift MachineSets and Machines after manually changing EC2 instance types
#
# Usage:
#   ./sync-openshift-machineset.sh [--instance-type TYPE] [--help]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
NEW_INSTANCE_TYPE=""

# Function to print colored messages
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_header() {
    echo -e "\n${BLUE}============================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}============================================================${NC}\n"
}

# Function to display usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Sync OpenShift MachineSets and Machines with actual EC2 instance types

This script:
1. Detects current EC2 instance types
2. Updates MachineSet definitions
3. Patches Machine objects
4. Optionally recreates machines to pick up changes

OPTIONS:
    --instance-type TYPE    New instance type (e.g., g6.8xlarge)
    --auto-detect           Auto-detect instance type from EC2
    --help                  Display this help message

EXAMPLES:
    # Auto-detect and sync
    $0 --auto-detect

    # Specify instance type manually
    $0 --instance-type g6.8xlarge

    # Interactive mode (will prompt, defaults to g6.8xlarge if you press Enter)
    $0

EOF
    exit 1
}

# Parse command line arguments
AUTO_DETECT=false
while [[ $# -gt 0 ]]; do
    case $1 in
        --instance-type)
            NEW_INSTANCE_TYPE="$2"
            shift 2
            ;;
        --auto-detect)
            AUTO_DETECT=true
            shift
            ;;
        --help|-h)
            usage
            ;;
        *)
            print_error "Unknown option: $1"
            usage
            ;;
    esac
done

# Check if oc command is available
if ! command -v oc &> /dev/null; then
    print_error "OpenShift CLI (oc) is not installed or not in PATH"
    echo "Please install oc: https://docs.openshift.com/container-platform/latest/cli_reference/openshift_cli/getting-started-cli.html"
    exit 1
fi

print_header "OpenShift MachineSet Sync"

# Verify kubeconfig and prompt for login
echo "Verifying OpenShift cluster connection..."
echo ""

# Check if currently logged in
if oc whoami &> /dev/null; then
    CURRENT_USER=$(oc whoami 2>/dev/null || echo "unknown")
    CURRENT_SERVER=$(oc whoami --show-server 2>/dev/null || echo "unknown")
    CURRENT_CONTEXT=$(oc config current-context 2>/dev/null || echo "unknown")
    
    print_info "Currently connected to:"
    echo "  User:    $CURRENT_USER"
    echo "  Server:  $CURRENT_SERVER"
    echo "  Context: $CURRENT_CONTEXT"
    echo ""
    
    read -p "Is this the correct OpenShift cluster? (y/n): " CONFIRM
    
    if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
        print_warn "Please login to the correct OpenShift cluster"
        echo ""
        read -p "Enter your OpenShift cluster URL (e.g., https://api.cluster.example.com:6443): " CLUSTER_URL
        
        if [ -z "$CLUSTER_URL" ]; then
            print_error "No cluster URL provided"
            exit 1
        fi
        
        echo ""
        read -p "Enter username: " OC_USERNAME
        
        if [ -z "$OC_USERNAME" ]; then
            print_error "No username provided"
            exit 1
        fi
        
        read -s -p "Enter password: " OC_PASSWORD
        echo ""
        
        if [ -z "$OC_PASSWORD" ]; then
            print_error "No password provided"
            exit 1
        fi
        
        echo ""
        print_info "Logging in to OpenShift cluster..."
        oc login "$CLUSTER_URL" -u "$OC_USERNAME" -p "$OC_PASSWORD"
        
        if [ $? -ne 0 ]; then
            print_error "Failed to login to OpenShift cluster"
            exit 1
        fi
    fi
else
    print_warn "Not currently logged into any OpenShift cluster"
    echo ""
    read -p "Enter your OpenShift cluster URL (e.g., https://api.cluster.example.com:6443): " CLUSTER_URL
    
    if [ -z "$CLUSTER_URL" ]; then
        print_error "No cluster URL provided"
        exit 1
    fi
    
    echo ""
    read -p "Enter username: " OC_USERNAME
    
    if [ -z "$OC_USERNAME" ]; then
        print_error "No username provided"
        exit 1
    fi
    
    read -s -p "Enter password: " OC_PASSWORD
    echo ""
    
    if [ -z "$OC_PASSWORD" ]; then
        print_error "No password provided"
        exit 1
    fi
    
    echo ""
    print_info "Logging in to OpenShift cluster..."
    oc login "$CLUSTER_URL" -u "$OC_USERNAME" -p "$OC_PASSWORD"
    
    if [ $? -ne 0 ]; then
        print_error "Failed to login to OpenShift cluster"
        exit 1
    fi
fi

# Verify connection and get cluster info
echo ""
print_info "Verifying cluster connection..."

if ! oc whoami &> /dev/null; then
    print_error "Not successfully logged into OpenShift cluster"
    exit 1
fi

CURRENT_USER=$(oc whoami)
CLUSTER_NAME=$(oc get infrastructure cluster -o jsonpath='{.status.infrastructureName}' 2>/dev/null || echo "unknown")
CLUSTER_VERSION=$(oc version -o json 2>/dev/null | grep -oP '"gitVersion":\s*"\K[^"]+' | head -1 || echo "unknown")

print_success "Successfully connected to OpenShift cluster"
print_info "Cluster: $CLUSTER_NAME"
print_info "User: $CURRENT_USER"
print_info "Version: $CLUSTER_VERSION"
echo ""

# Check if MachineSets exist
MACHINESETS=$(oc get machinesets -n openshift-machine-api -o name 2>/dev/null || echo "")

if [ -z "$MACHINESETS" ]; then
    print_warn "No MachineSets found in openshift-machine-api namespace"
    print_warn "This might be a single-node cluster or MachineSets are not used"
    echo ""
    
    # Try to update node labels/annotations instead
    print_info "Attempting to update node information..."
    
    NODES=$(oc get nodes -o name)
    for NODE in $NODES; do
        NODE_NAME=$(echo "$NODE" | cut -d'/' -f2)
        print_info "Processing node: $NODE_NAME"
        
        # Get EC2 instance ID from node
        INSTANCE_ID=$(oc get "$NODE" -o jsonpath='{.spec.providerID}' | grep -oP 'i-[a-z0-9]+' || echo "")
        
        if [ -n "$INSTANCE_ID" ]; then
            print_info "  Instance ID: $INSTANCE_ID"
            
            # If auto-detect, get actual instance type from EC2 metadata
            if [ "$AUTO_DETECT" = true ] && command -v aws &> /dev/null; then
                ACTUAL_TYPE=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" \
                    --query 'Reservations[0].Instances[0].InstanceType' \
                    --output text 2>/dev/null || echo "")
                if [ -n "$ACTUAL_TYPE" ]; then
                    print_info "  Detected EC2 type: $ACTUAL_TYPE"
                    NEW_INSTANCE_TYPE="$ACTUAL_TYPE"
                fi
            fi
            
            if [ -n "$NEW_INSTANCE_TYPE" ]; then
                print_info "  Updating node labels with instance type: $NEW_INSTANCE_TYPE"
                oc label node "$NODE_NAME" "node.openshift.io/instance-type=$NEW_INSTANCE_TYPE" --overwrite
                oc label node "$NODE_NAME" "beta.kubernetes.io/instance-type=$NEW_INSTANCE_TYPE" --overwrite
            fi
        fi
    done
    
    print_success "Node labels updated"
    echo ""
    print_info "Note: Without MachineSets, you may need to manually restart affected pods"
    exit 0
fi

# If instance type not provided, prompt or auto-detect
if [ -z "$NEW_INSTANCE_TYPE" ] && [ "$AUTO_DETECT" != true ]; then
    echo "Current MachineSets:"
    oc get machinesets -n openshift-machine-api -o custom-columns=NAME:.metadata.name,INSTANCE-TYPE:.spec.template.spec.providerSpec.value.instanceType,REPLICAS:.spec.replicas
    echo ""
    read -p "Enter new instance type [g6.8xlarge]: " NEW_INSTANCE_TYPE
    
    # Use default if no input provided
    if [ -z "$NEW_INSTANCE_TYPE" ]; then
        NEW_INSTANCE_TYPE="g6.8xlarge"
        print_info "Using default instance type: g6.8xlarge"
    fi
fi

# Auto-detect instance type from EC2
if [ "$AUTO_DETECT" = true ]; then
    print_info "Auto-detecting instance type from EC2..."
    
    # Get a Machine to find its instance ID
    MACHINE=$(oc get machines -n openshift-machine-api -o name 2>/dev/null | head -1)
    if [ -n "$MACHINE" ]; then
        INSTANCE_ID=$(oc get "$MACHINE" -n openshift-machine-api -o jsonpath='{.spec.providerID}' | grep -oP 'i-[a-z0-9]+' || echo "")
        
        if [ -n "$INSTANCE_ID" ] && command -v aws &> /dev/null; then
            DETECTED_TYPE=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" \
                --query 'Reservations[0].Instances[0].InstanceType' \
                --output text 2>/dev/null || echo "")
            
            if [ -n "$DETECTED_TYPE" ]; then
                NEW_INSTANCE_TYPE="$DETECTED_TYPE"
                print_success "Detected instance type: $NEW_INSTANCE_TYPE"
            else
                print_error "Could not detect instance type from EC2"
                exit 1
            fi
        else
            print_error "AWS CLI not available or could not get instance ID"
            exit 1
        fi
    fi
fi

if [ -z "$NEW_INSTANCE_TYPE" ]; then
    print_error "Instance type not specified"
    usage
fi

print_info "Target instance type: $NEW_INSTANCE_TYPE"
echo ""

# Update each MachineSet
echo "Updating MachineSets..."
for MACHINESET in $MACHINESETS; do
    MACHINESET_NAME=$(echo "$MACHINESET" | cut -d'/' -f2)
    
    CURRENT_TYPE=$(oc get "$MACHINESET" -n openshift-machine-api -o jsonpath='{.spec.template.spec.providerSpec.value.instanceType}')
    
    print_info "MachineSet: $MACHINESET_NAME"
    print_info "  Current type: $CURRENT_TYPE"
    print_info "  New type: $NEW_INSTANCE_TYPE"
    
    if [ "$CURRENT_TYPE" = "$NEW_INSTANCE_TYPE" ]; then
        print_success "  Already up to date"
        continue
    fi
    
    # Patch the MachineSet
    print_info "  Patching MachineSet..."
    oc patch "$MACHINESET" -n openshift-machine-api --type='json' \
        -p="[{\"op\": \"replace\", \"path\": \"/spec/template/spec/providerSpec/value/instanceType\", \"value\": \"$NEW_INSTANCE_TYPE\"}]"
    
    print_success "  MachineSet updated"
done

echo ""
print_success "All MachineSets updated"

# Update existing Machines
echo ""
echo "Updating existing Machine objects..."

MACHINES=$(oc get machines -n openshift-machine-api -o name)
for MACHINE in $MACHINES; do
    MACHINE_NAME=$(echo "$MACHINE" | cut -d'/' -f2)
    
    CURRENT_TYPE=$(oc get "$MACHINE" -n openshift-machine-api -o jsonpath='{.spec.providerSpec.value.instanceType}' 2>/dev/null || echo "unknown")
    
    print_info "Machine: $MACHINE_NAME"
    print_info "  Current type: $CURRENT_TYPE"
    
    if [ "$CURRENT_TYPE" = "$NEW_INSTANCE_TYPE" ]; then
        print_success "  Already up to date"
        continue
    fi
    
    # Patch the Machine
    print_info "  Patching Machine..."
    oc patch "$MACHINE" -n openshift-machine-api --type='json' \
        -p="[{\"op\": \"replace\", \"path\": \"/spec/providerSpec/value/instanceType\", \"value\": \"$NEW_INSTANCE_TYPE\"}]" 2>/dev/null || print_warn "  Could not patch Machine (may be immutable)"
    
    # Update machine instance-type annotation
    oc annotate "$MACHINE" -n openshift-machine-api \
        "machine.openshift.io/instance-type=$NEW_INSTANCE_TYPE" --overwrite
    
    # Update corresponding node labels
    NODE_NAME=$(oc get "$MACHINE" -n openshift-machine-api -o jsonpath='{.status.nodeRef.name}' 2>/dev/null || echo "")
    if [ -n "$NODE_NAME" ]; then
        print_info "  Updating node labels: $NODE_NAME"
        oc label node "$NODE_NAME" "node.openshift.io/instance-type=$NEW_INSTANCE_TYPE" --overwrite 2>/dev/null || true
        oc label node "$NODE_NAME" "beta.kubernetes.io/instance-type=$NEW_INSTANCE_TYPE" --overwrite 2>/dev/null || true
    fi
    
    print_success "  Machine updated"
done

echo ""
print_success "All Machines updated"

# Summary
print_header "Summary"

echo "MachineSets updated:"
oc get machinesets -n openshift-machine-api -o custom-columns=NAME:.metadata.name,INSTANCE-TYPE:.spec.template.spec.providerSpec.value.instanceType,REPLICAS:.spec.replicas

echo ""
echo "Machines status:"
oc get machines -n openshift-machine-api -o wide

echo ""
echo "Nodes status:"
oc get nodes -o wide

echo ""
print_success "OpenShift MachineSet sync completed!"
echo ""
print_info "Next steps:"
echo "  1. Verify nodes show the correct instance type: oc get nodes -o wide"
echo "  2. Check machine status: oc get machines -n openshift-machine-api"
echo "  3. If needed, recreate machines: oc delete machine <machine-name> -n openshift-machine-api"
echo "  4. Wait for GPU operator to reinitialize if you have GPUs"
echo ""

