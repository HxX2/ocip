#!/bin/bash
# This script automates creating an OCI "Always Free" ARM instance
# by looping through all Availability Domains until capacity is found.

echo "--- Oracle Cloud ARM Instance Provisioner ---"

# --- Load Configuration ---
CONFIG_FILE="${1:-config.json}"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Config file '$CONFIG_FILE' not found!"
    echo "Usage: $0 [config.json]"
    echo ""
    echo "Create a config.json file with your OCI details."
    echo "See config.example.json for the format."
    exit 1
fi

echo "Loading configuration from: $CONFIG_FILE"

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo "Error: 'jq' is required but not installed."
    echo "Install it with:"
    echo "  - Ubuntu/Debian: sudo apt install jq"
    echo "  - macOS: brew install jq"
    echo "  - Windows: Download from https://stedolan.github.io/jq/download/"
    exit 1
fi

# Read configuration from JSON file
COMPARTMENT_ID=$(jq -r '.compartment_id' "$CONFIG_FILE")
IMAGE_ID=$(jq -r '.image_id' "$CONFIG_FILE")
SUBNET_ID=$(jq -r '.subnet_id' "$CONFIG_FILE")
REGION=$(jq -r '.region' "$CONFIG_FILE")
OCPU_COUNT=$(jq -r '.ocpu_count' "$CONFIG_FILE")
MEMORY_IN_GBS=$(jq -r '.memory_in_gbs' "$CONFIG_FILE")
SSH_KEY_PATH=$(jq -r '.ssh_key_path' "$CONFIG_FILE")
DISPLAY_NAME=$(jq -r '.display_name' "$CONFIG_FILE")
RATE_LIMIT_WAIT=$(jq -r '.rate_limit_wait // 90' "$CONFIG_FILE")
RATE_LIMIT_COOLDOWN=$(jq -r '.rate_limit_cooldown // 300' "$CONFIG_FILE")

# Expand tilde to home directory if present
SSH_KEY_PATH="${SSH_KEY_PATH/#\~/$HOME}"

if [ ! -f "$SSH_KEY_PATH" ]; then
    echo "Error: SSH key file not found at '$SSH_KEY_PATH'"
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
echo "  - Display Name: $DISPLAY_NAME"
echo "  - Rate Limit Wait: $RATE_LIMIT_WAIT seconds"
echo ""
echo "⚠️  Rate Limiting: Waiting $RATE_LIMIT_WAIT seconds between attempts to avoid API throttling"
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
        echo "⏳ Sending request to OCI (this may take 10-30 seconds)..."
        
        # Command to launch the instance (captures output but shows we're waiting)
        OUTPUT=$(oci compute instance launch \
            --region "$REGION" \
            --compartment-id "$COMPARTMENT_ID" \
            --image-id "$IMAGE_ID" \
            --subnet-id "$SUBNET_ID" \
            --availability-domain "$AD" \
            --shape "VM.Standard.A1.Flex" \
            --shape-config '{"ocpus":'"$OCPU_COUNT"',"memoryInGBs":'"$MEMORY_IN_GBS"'}' \
            --ssh-authorized-keys-file "$SSH_KEY_PATH" \
            --display-name "$DISPLAY_NAME" \
            --assign-private-dns-record true \
            --assign-public-ip true 2>&1)
        
        # Check the exit code of the last command
        EXIT_CODE=$?
        
        echo ""
        echo "━━━━━━━━━━ SERVER RESPONSE ━━━━━━━━━━"
        echo "$OUTPUT"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        
        # Check for rate limiting
        if echo "$OUTPUT" | grep -qi "TooManyRequests\|too many requests"; then
            echo "⚠️  RATE LIMITED! Cooling down for $RATE_LIMIT_COOLDOWN seconds..."
            echo "[$TIMESTAMP] Pausing to respect API limits."
            sleep $RATE_LIMIT_COOLDOWN
            continue
        fi
        
        # Check for success
        if [ $EXIT_CODE -eq 0 ] && echo "$OUTPUT" | grep -qi '"lifecycle-state"'; then
            echo "***********************************************"
            echo "SUCCESS! Instance created in $AD!"
            echo "***********************************************"
            echo "$OUTPUT" | grep -E '"display-name"|"id"|"lifecycle-state"|"public-ip"' || echo "$OUTPUT"
            echo ""
            echo "Check your OCI console to see your new instance."
            exit 0
        else
            # Check for specific errors
            if echo "$OUTPUT" | grep -qi "out of capacity\|out of host capacity"; then
                echo "❌ No capacity in $AD"
            elif echo "$OUTPUT" | grep -qi "limit exceeded"; then
                echo "❌ Service limit exceeded"
            else
                echo "❌ Failed in $AD"
            fi
            
            # Wait before next attempt to avoid rate limiting
            echo "⏳ Waiting $RATE_LIMIT_WAIT seconds before next attempt..."
            sleep $RATE_LIMIT_WAIT
        fi
    done
    
    echo "------------------------------------------------"
    echo "Cycled through all ADs. Pausing for 120 seconds before retrying all."
    echo "Total attempts so far: $ATTEMPT"
    echo "------------------------------------------------"
    sleep 120
done
