# EC2 Instance Management Script

This bash script automates the management of AWS EC2 instances, including:
1. Listing EC2 instances in a region
2. Checking instance types
3. Converting instances to `g6.8xlarge` (or any specified type)
4. Restarting instances after modification

## Quick Start

**Easiest way to use (recommended for beginners):**
```bash
./scripts/convert-ec2-instance.sh
```
Just run the script with no arguments and it will interactively prompt you for everything!

**Other usage modes:**
- **Semi-interactive**: Provide some parameters (like region) and script prompts for the rest
- **Command-line**: Provide all parameters via arguments for automation/scripting

## Features

✅ **Fully Interactive** - No need to remember command-line arguments  
✅ **Smart Prompts** - Shows common AWS regions, hides secret keys while typing  
✅ **Instance Selection** - View all instances and pick by number  
✅ **Flexible** - Mix command-line args with interactive prompts  
✅ **Safe** - Validates all inputs and confirms credentials before proceeding  
✅ **Colored Output** - Easy-to-read progress with color-coded messages  
✅ **Auto-restart** - Handles stopping, modifying, and starting instances automatically

## Prerequisites

### AWS CLI
The script requires AWS CLI to be installed. Install it using one of these methods:

**macOS:**
```bash
brew install awscli
```

**Linux:**
```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
```

**Or via pip:**
```bash
pip install awscli
```

### jq (JSON processor)
The script uses `jq` to parse JSON responses. Install it:

**macOS:**
```bash
brew install jq
```

**Linux (Debian/Ubuntu):**
```bash
sudo apt-get install jq
```

**Linux (RHEL/CentOS):**
```bash
sudo yum install jq
```

### AWS Credentials
You need AWS credentials with the following permissions:
- `ec2:DescribeInstances`
- `ec2:DescribeRegions`
- `ec2:StopInstances`
- `ec2:StartInstances`
- `ec2:ModifyInstanceAttribute`

## Usage

### Fully Interactive Mode (Easiest - Recommended!)

The absolute easiest way to use the script is to just run it with no arguments! The script will prompt you for everything it needs:

```bash
./scripts/convert-ec2-instance.sh
```

**Example Fully Interactive Session:**
```
============================================================
EC2 Instance Management - Configuration
============================================================

Let's gather the required information to manage your EC2 instance.

Common AWS regions:
  - us-east-2 (Ohio) [default]
  - us-east-1 (N. Virginia)
  - us-west-2 (Oregon)
  - eu-west-1 (Ireland)
  - ap-southeast-1 (Singapore)

Enter AWS region [us-east-2]: us-east-2

Enter AWS Access Key ID: AKIAIOSFODNN7EXAMPLE
Enter AWS Secret Access Key: ****************

Use default target instance type (g6.8xlarge)? [Y/n]: y

Do you want to select an instance from a list? [Y/n]: y

[INFO] Testing AWS credentials...
[SUCCESS] AWS credentials validated successfully
[INFO] Connected to AWS Region: us-east-2

============================================================
Select EC2 Instance in us-east-2
============================================================

Available EC2 Instances:

  #  Instance ID          Name                           Instance Type        State
---------------------------------------------------------------------------------------------
  1) i-1234567890abc      my-web-server                  t3.medium            running
  2) i-0987654321def      my-gpu-instance                g5.xlarge            stopped
  3) i-abcdef123456       production-api                 t3.large             running

---------------------------------------------------------------------------------------------
Enter the number of the instance to convert (1-3, or 'q' to quit): 2

[SUCCESS] Selected instance: i-0987654321def (my-gpu-instance)

[Processing continues...]
```

### Semi-Interactive Mode

You can also provide some parameters on the command line, and the script will prompt for anything missing:

```bash
# Provide region, script will prompt for credentials and instance selection
./scripts/convert-ec2-instance.sh --region us-east-2

# Provide credentials via environment, script will prompt for region and instance
export AWS_ACCESS_KEY_ID=your_key
export AWS_SECRET_ACCESS_KEY=your_secret
./scripts/convert-ec2-instance.sh
```

### Traditional Command-Line Mode

For automation or if you prefer command-line arguments:

```bash
./scripts/convert-ec2-instance.sh \
    --region us-east-2 \
    --access-key-id YOUR_ACCESS_KEY_ID \
    --secret-access-key YOUR_SECRET_ACCESS_KEY \
    --interactive
```

This will:
1. Authenticate with AWS
2. Display all EC2 instances in the region with their details
3. Let you select which instance to convert by entering its number
4. Automatically convert it to g6.8xlarge (or your specified type)
5. Restart the instance

### List all instances in a region:
```bash
./scripts/convert-ec2-instance.sh \
    --region us-east-2 \
    --access-key-id YOUR_ACCESS_KEY_ID \
    --secret-access-key YOUR_SECRET_ACCESS_KEY \
    --list-instances
```

### Process a specific instance (non-interactive):
```bash
./scripts/convert-ec2-instance.sh \
    --region us-east-2 \
    --instance-id i-1234567890abcdef0 \
    --access-key-id YOUR_ACCESS_KEY_ID \
    --secret-access-key YOUR_SECRET_ACCESS_KEY
```

### Convert to a different instance type:
```bash
./scripts/convert-ec2-instance.sh \
    --region us-west-2 \
    --instance-id i-1234567890abcdef0 \
    --access-key-id YOUR_ACCESS_KEY_ID \
    --secret-access-key YOUR_SECRET_ACCESS_KEY \
    --target-type g6.12xlarge
```

Or in interactive mode:
```bash
./scripts/convert-ec2-instance.sh \
    --region us-west-2 \
    --interactive \
    --target-type g6.12xlarge \
    --access-key-id YOUR_ACCESS_KEY_ID \
    --secret-access-key YOUR_SECRET_ACCESS_KEY
```

### Using Environment Variables

Set AWS credentials as environment variables to avoid passing them in the command:

```bash
export AWS_ACCESS_KEY_ID=your_access_key_id
export AWS_SECRET_ACCESS_KEY=your_secret_access_key

# Interactive mode with environment variables (uses default region us-east-2)
./scripts/convert-ec2-instance.sh --interactive

# Or specify a different region
./scripts/convert-ec2-instance.sh --region us-east-2 --interactive

# Or with specific instance
./scripts/convert-ec2-instance.sh \
    --region us-east-2 \
    --instance-id i-1234567890abcdef0
```

## Command-Line Arguments

| Argument | Required | Description |
|----------|----------|-------------|
| `--region` | Yes | AWS region (e.g., us-east-2, us-west-2) |
| `--instance-id` | Yes* | EC2 Instance ID to process |
| `--access-key-id` | No** | AWS Access Key ID |
| `--secret-access-key` | No** | AWS Secret Access Key |
| `--target-type` | No | Target instance type (default: g6.8xlarge) |
| `--interactive` | No | Interactive mode - select instance from a list |
| `--list-instances` | No | List all instances in the region and exit |
| `-h, --help` | No | Display help message and exit |

\* Not required when using `--list-instances` or `--interactive`  
\*\* Can be provided via environment variables `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` (default region: us-east-2)

## Examples

### Example 0: Fully Interactive Mode (No Arguments - EASIEST!)

Just run the script and it will ask you for everything:

```bash
./scripts/convert-ec2-instance.sh
```

The script will prompt you step by step for:
- AWS region (with suggestions)
- AWS credentials (secret key is hidden)
- Target instance type (with default)
- Whether to select from a list or enter instance ID
- Which instance to convert (if you chose list mode)

### Example 1: Semi-Interactive Mode with Credentials Set
```bash
# Set credentials
export AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE
export AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY

# Run - script will only prompt for region and instance selection
./scripts/convert-ec2-instance.sh
```

Since credentials are already set, the script will only prompt for region and instance selection:
```
Enter AWS region [us-east-2]: us-east-2
Use default target instance type (g6.8xlarge)? [Y/n]: y
Do you want to select an instance from a list? [Y/n]: y
```

Then displays all instances and prompts you:
```
============================================================
Select EC2 Instance in us-east-2
============================================================

Available EC2 Instances:

  #  Instance ID          Name                           Instance Type        State
---------------------------------------------------------------------------------------------
  1) i-1234567890abc      my-web-server                  t3.medium            running
  2) i-0987654321def      my-gpu-instance                g5.xlarge            stopped
  3) i-abcdef123456       production-api                 t3.large             running

---------------------------------------------------------------------------------------------
Enter the number of the instance to convert (1-3, or 'q' to quit): 2

[SUCCESS] Selected instance: i-0987654321def (my-gpu-instance)

============================================================
Processing Instance: i-0987654321def
============================================================

Instance Name:          my-gpu-instance
Current Instance Type:  g5.xlarge
Current State:          stopped
Target Instance Type:   g6.8xlarge

[WARN] Conversion needed: g5.xlarge -> g6.8xlarge

[INFO] Modifying instance type to g6.8xlarge...
[SUCCESS] Instance type modified to g6.8xlarge successfully
[INFO] Starting instance i-0987654321def...
[SUCCESS] Instance started successfully

============================================================
✓ Successfully converted instance to g6.8xlarge and started it!
============================================================

[SUCCESS] Operation completed successfully!

[INFO] Please wait up to 10 minutes for the OpenShift cluster to be up and running properly.
```

### Example 2: List All Instances
```bash
./scripts/convert-ec2-instance.sh \
    --region us-east-2 \
    --access-key-id AKIAIOSFODNN7EXAMPLE \
    --secret-access-key wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY \
    --list-instances
```

Output:
```
Instance ID          Name                           Type            State
--------------------------------------------------------------------------------
i-1234567890abc      my-web-server                  t3.medium       running
i-0987654321def      my-gpu-instance                g5.xlarge       stopped
```

### Example 3: Convert Specific Instance to g6.8xlarge (Non-Interactive)
```bash
./scripts/convert-ec2-instance.sh \
    --region us-east-2 \
    --instance-id i-1234567890abc \
    --access-key-id AKIAIOSFODNN7EXAMPLE \
    --secret-access-key wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
```

### Example 4: Convert to Custom Instance Type
```bash
./scripts/convert-ec2-instance.sh \
    --region us-west-2 \
    --instance-id i-1234567890abc \
    --target-type g5.12xlarge \
    --access-key-id AKIAIOSFODNN7EXAMPLE \
    --secret-access-key wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
```

### Example 5: Interactive Mode with Custom Instance Type
```bash
./scripts/convert-ec2-instance.sh \
    --region us-west-2 \
    --interactive \
    --target-type p4d.24xlarge \
    --access-key-id AKIAIOSFODNN7EXAMPLE \
    --secret-access-key wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
```

## How It Works

### Interactive Mode Flow:
1. **Authentication**: The script authenticates with AWS using the provided credentials
2. **List Instances**: Retrieves all EC2 instances in the specified region
3. **User Selection**: Displays instances in a numbered list and waits for user input
4. **Instance Processing**: Once selected, proceeds with the conversion process

### Instance Processing Flow:
1. **Instance Discovery**: Retrieves information about the specified or selected EC2 instance
2. **Type Check**: Compares the current instance type with the target type
3. **Modification** (if types differ):
   - Stops the instance (if running)
   - Modifies the instance type
   - Starts the instance
4. **Restart** (if types match): Simply restarts the instance

## Important Notes

### Instance Compatibility
- Not all instance types are available in all regions
- Instance type changes may require EBS volume modifications
- Some instance types require specific AMIs or configurations
- Changing instance types may affect pricing

### Downtime
- The instance will be stopped during the type modification process
- Total downtime typically ranges from 2-5 minutes
- Elastic IPs will remain associated with the instance
- EBS volumes will remain attached

### Permissions
The IAM user or role must have sufficient permissions to:
- View instances (`ec2:DescribeInstances`)
- Stop instances (`ec2:StopInstances`)
- Start instances (`ec2:StartInstances`)
- Modify instance attributes (`ec2:ModifyInstanceAttribute`)

### Sample IAM Policy
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ec2:DescribeInstances",
                "ec2:DescribeRegions",
                "ec2:StopInstances",
                "ec2:StartInstances",
                "ec2:ModifyInstanceAttribute"
            ],
            "Resource": "*"
        }
    ]
}
```

## Troubleshooting

### "AWS CLI is not installed"
- Install AWS CLI following the installation instructions in the Prerequisites section
- Verify installation: `aws --version`

### "command not found: jq"
- Install jq following the installation instructions in the Prerequisites section
- Verify installation: `jq --version`

### "No AWS credentials provided" or "Failed to authenticate with AWS"
- Ensure you're passing `--access-key-id` and `--secret-access-key`
- Or set `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` environment variables
- Verify your credentials are correct and active

### "Instance not found"
- Verify the instance ID is correct
- Ensure the instance is in the specified region
- Check that your AWS credentials have permission to view the instance

### "Failed to modify instance type"
- The instance must be stopped before modification
- Check if the target instance type is available in your region
- Verify your instance architecture (x86 vs ARM) is compatible with the target type
- Ensure your IAM user/role has the `ec2:ModifyInstanceAttribute` permission

## Security Best Practices

1. **Never commit AWS credentials** to version control
2. **Use IAM roles** when running on EC2 instead of hardcoded credentials
3. **Apply least privilege** - only grant necessary permissions
4. **Rotate credentials** regularly
5. **Use AWS Secrets Manager** or Parameter Store for credential storage
6. **Enable CloudTrail** to audit API calls

## Support

For issues or questions:
- Check AWS EC2 documentation: https://docs.aws.amazon.com/ec2/
- Review AWS CLI documentation: https://docs.aws.amazon.com/cli/latest/reference/ec2/
- jq documentation: https://stedolan.github.io/jq/manual/

