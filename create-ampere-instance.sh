#!/bin/bash
# This script automates creating an OCI "Always Free" ARM instance
# by looping through all Availability Domains until capacity is found.

echo "--- Oracle Cloud ARM Instance Provisioner ---"
echo "Please provide your OCI details. These are NOT saved."
echo "Find these details in your OCI console."
echo ""

# --- User Inputs ---
read -p "Enter your Compartment ID (ocid1.compartment...): " COMPARTMENT_ID
read -p "Enter your Image ID (ocid1.image...): " IMAGE_ID
read -p "Enter your Subnet ID (ocid1.subnet...): " SUBNET_ID
read -p "Enter your Region (e.g., us-ashburn-1): " REGION
read -p "Enter your desired OCPU count (1-4, default 4): " OCPU_COUNT
OCPU_COUNT=${OCPU_COUNT:-4}
read -p "Enter your desired Memory in GB (6-24, default 24): " MEMORY_IN_GBS
MEMORY_IN_GBS=${MEMORY_IN_GBS:-24}

echo ""
echo "Paste your full public SSH key (e.g., ssh-rsa AAAA...):"
echo "(Press Ctrl+D on a new line when done)"
SSH_KEY=$(cat)

if [ -z "$SSH_KEY" ]; then
    echo "No SSH key provided. Exiting."
    exit 1
fi

# Validate inputs
if [[ ! "$COMPARTMENT_ID" =~ ^ocid1\.compartment\. ]] && [[ ! "$COMPARTMENT_ID" =~ ^ocid1\.tenancy\. ]]; then
    echo "Error: Invalid Compartment ID format"
    exit 1
fi

if [[ ! "$IMAGE_ID" =~ ^ocid1\.image\. ]]; then
    echo "Error: Invalid Image ID format"
    exit 1
fi

if [[ ! "$SUBNET_ID" =~ ^ocid1\.subnet\. ]]; then
    echo "Error: Invalid Subnet ID format"
    exit 1
fi

# Suppress file permissions warning for the key
export OCI_CLI_SUPPRESS_FILE_PERMISSIONS_WARNING=true

echo "------------------------------------------------"
echo "Fetching Availability Domains (ADs) for region $REGION..."
# Get ADs, trim whitespace, remove quotes, and store in an array
ADS=($(oci iam availability-domain list --region "$REGION" --query "data[].name" --raw-output 2>&1))

if [ ${#ADS[@]} -eq 0 ] || [[ "${ADS[0]}" == *"Error"* ]]; then
    echo "Could not fetch Availability Domains. Check your region and OCI config."
    echo "Make sure you have run 'oci setup config' first."
    exit 1
fi

echo "Found ${#ADS[@]} ADs: ${ADS[*]}"
echo "Configuration:"
echo "  - Shape: VM.Standard.A1.Flex"
echo "  - OCPUs: $OCPU_COUNT"
echo "  - Memory: $MEMORY_IN_GBS GB"
echo "  - Region: $REGION"
echo ""
echo "Starting provisioning loop. This may take hours or days."
echo "Press Ctrl+C to stop."
echo "------------------------------------------------"

# Counter for attempts
ATTEMPT=0

while true
do
    # Loop through each Availability Domain
    for AD in "${ADS[@]}"
    do
        ATTEMPT=$((ATTEMPT + 1))
        TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
        echo "[$TIMESTAMP] Attempt #$ATTEMPT - Trying AD: $AD"
        
        # Command to launch the instance
        oci compute instance launch \
            --region "$REGION" \
            --compartment-id "$COMPARTMENT_ID" \
            --image-id "$IMAGE_ID" \
            --subnet-id "$SUBNET_ID" \
            --availability-domain "$AD" \
            --shape "VM.Standard.A1.Flex" \
            --shape-config '{"ocpus":'"$OCPU_COUNT"',"memoryInGBs":'"$MEMORY_IN_GBS"'}' \
            --ssh-authorized-keys-file <(echo "$SSH_KEY") \
            --display-name "AlwaysFree-ARM-Instance" \
            --assign-private-dns-record true \
            --assign-public-ip true \
            --wait-for-state RUNNING 2>&1
        
        # Check the exit code of the last command
        EXIT_CODE=$?
        if [ $EXIT_CODE -eq 0 ]; then
            echo "***********************************************"
            echo "SUCCESS! Instance created in $AD!"
            echo "***********************************************"
            echo "Check your OCI console to see your new instance."
            exit 0
        else
            # 500-series errors are usually capacity/internal errors
            echo "Failed in $AD (likely 'Out of Capacity' or 'Out of host capacity')."
            echo "Waiting 10 seconds before trying next AD..."
            sleep 10
        fi
    done
    
    echo "------------------------------------------------"
    echo "Cycled through all ADs. Pausing for 60 seconds before retrying all."
    echo "Total attempts so far: $ATTEMPT"
    echo "------------------------------------------------"
    sleep 60
done
