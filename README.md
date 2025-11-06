# OCI Ampere ARM Instance Auto-Provisioner

A bash script that automatically attempts to create an Oracle Cloud Infrastructure (OCI) "Always Free" Ampere ARM instance by cycling through all Availability Domains until capacity is found.

## What This Script Does

Oracle's Always Free Ampere A1 instances are highly sought after but often show "Out of capacity" errors. This script:

- ✅ **Config file based** - Set your parameters once in `config.json`
- ✅ **Loops through all Availability Domains** in your region
- ✅ **Continuously retries** until an instance is successfully created
- ✅ **Rate limiting protection** - Automatically handles "TooManyRequests" errors
- ✅ **Shows full server responses** - See exactly what OCI returns
- ✅ **Timestamps and attempt counts** for tracking progress
- ✅ **Validates inputs** before starting
- ✅ **Can run for hours or days** until capacity is found

## ⚠️ Important Notes

- **This can take a LONG time**: Days or even weeks depending on region and demand
- **Leave it running**: Use `screen` or `tmux` to keep it running in the background
- **Always Free limits**: You get up to 4 OCPUs and 24GB RAM total across all A1 instances
- **Rate limiting**: Script waits 90 seconds between attempts, 5 minutes if rate limited
- **Configuration saved**: Your settings are stored in `config.json` (keep it secure!)

---

## Prerequisites (One-Time Setup)

You must complete these steps manually before running the script.

### 1. Install Required Tools

**Install OCI CLI:**

**Linux/macOS:**
```bash
bash -c "$(curl -L https://raw.githubusercontent.com/oracle/oci-cli/master/scripts/install/install.sh)"
```

**Windows:**
- Download the installer from: https://docs.oracle.com/en-us/iaas/Content/API/SDKDocs/cliinstall.htm
- Or use PowerShell:
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "iex ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/oracle/oci-cli/master/scripts/install/install.ps1'))"
```

**Install jq (JSON processor):**

```bash
# Ubuntu/Debian
sudo apt install jq

# macOS
brew install jq

# Windows (Git Bash/WSL)
# Download from: https://stedolan.github.io/jq/download/
```

### 2. Configure OCI CLI

Run the setup command in your terminal:

```bash
oci setup config
```

This interactive setup will ask you for:
- **User OCID**: Your user's unique identifier
- **Tenancy OCID**: Your account's unique identifier  
- **Region**: Your home region (e.g., `us-ashburn-1`)

The setup will generate an API key pair and save it to `~/.oci/oci_api_key.pem`.

### 3. Upload Your Public API Key

1. Go to your OCI Console
2. Click your profile icon (top right) → **User Settings**
3. Under **Resources**, click **API Keys**
4. Click **Add API Key**
5. Select **Paste Public Key**
6. Copy the contents of `~/.oci/oci_api_key_public.pem` and paste it
7. Click **Add**

---

## Configuration Setup

### Step 1: Create Your Config File

Copy the example config and edit it with your details:

```bash
cp config.example.json config.json
nano config.json  # or use your preferred editor
```

### Step 2: Fill in the Required Parameters

Here's how to get each parameter using OCI CLI or the console:

#### 🔹 **compartment_id** (Tenancy OCID)

```bash
# List compartments
oci iam compartment list --all
```
**Console:** Identity & Security → Compartments → Copy OCID

---

#### 🔹 **image_id** (ARM64 Image OCID)

```bash
# List images
oci compute image list --compartment-id <tenancy-ocid> --shape "VM.Standard.A1.Flex" --region <region> --output table
```
**Console:** Compute → Instances → Create Instance → Change Image → Copy OCID

> **Note:** Image IDs are region-specific!

---

#### 🔹 **subnet_id** (Subnet OCID)

```bash
# List subnets
oci network subnet list --compartment-id <tenancy-ocid> --region <region> --output table
```
**Console:** Networking → Virtual Cloud Networks → Select VCN → Subnets → Copy OCID

---

#### 🔹 **region** (OCI Region)

```bash
# List regions
oci iam region list --query "data[].name" --output table
```
**Common:** `us-ashburn-1`, `us-phoenix-1`, `eu-marseille-1`, `eu-frankfurt-1`, `uk-london-1`, `ap-tokyo-1`

---

#### 🔹 **ssh_key_path** (SSH Public Key Path)

```bash
# Check existing keys
ls ~/.ssh/*.pub

# Generate new key (if needed)
ssh-keygen -t ed25519 -C "your_email@example.com"
```
**Path:** `~/.ssh/id_ed25519.pub` or `~/.ssh/id_rsa.pub`

---

#### 🔹 **Other Parameters**

```json
{
  "ocpu_count": 4,              // 1-4 (max: 4)
  "memory_in_gbs": 24,          // 6-24 (max: 24)
  "display_name": "ampere-vm",  // Instance name
  "rate_limit_wait": 90,        // Seconds between attempts
  "rate_limit_cooldown": 300    // Cooldown after rate limit
}
```

---

### Example config.json

```json
{
  "compartment_id": "ocid1.compartment.oc1..aaaaaaaxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
  "image_id": "ocid1.image.oc1.REGION.aaaaaaaxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
  "subnet_id": "ocid1.subnet.oc1.REGION.aaaaaaaxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
  "region": "us-ashburn-1",
  "ocpu_count": 4,
  "memory_in_gbs": 24,
  "ssh_key_path": "~/.ssh/id_rsa.pub",
  "display_name": "AlwaysFree-ARM-Instance",
  "rate_limit_wait": 90,
  "rate_limit_cooldown": 300
}
```

---

## How to Use the Script

### 1. Make the script executable (Linux/macOS/Git Bash)
```bash
chmod +x create-ampere-instance.sh
```

### 2. Run the script

**With default config.json:**
```bash
./create-ampere-instance.sh
```

**With custom config file:**
```bash
./create-ampere-instance.sh my-config.json
```

### 3. Monitor the output

**Example output:**
```
--- Oracle Cloud ARM Instance Provisioner ---
Loading configuration from: config.json
Found 1 ADs: vBLH:EU-MARSEILLE-1-AD-1
Configuration: VM.Standard.A1.Flex | 4 OCPUs | 24 GB | eu-marseille-1
⚠️  Rate Limiting: 90s between attempts
------------------------------------------------
[2025-11-06 15:30:45] Attempt #1 - Trying AD: vBLH:EU-MARSEILLE-1-AD-1
⏳ Sending request to OCI...

━━━━━━━━━━ SERVER RESPONSE ━━━━━━━━━━
{"code": "InternalError", "message": "Out of host capacity"}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

❌ No capacity in vBLH:EU-MARSEILLE-1-AD-1
⏳ Waiting 90 seconds before next attempt...
```

### 4. Keep it running in the background

```bash
# Using screen (recommended)
screen -S oci-provision
./create-ampere-instance.sh
# Ctrl+A then D to detach, screen -r oci-provision to reattach

# Using tmux
tmux new -s oci-provision
./create-ampere-instance.sh
# Ctrl+B then D to detach, tmux attach -t oci-provision to reattach

# Using nohup
nohup ./create-ampere-instance.sh > provision.log 2>&1 &
tail -f provision.log  # Check progress
```

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| **jq not installed** | `sudo apt install jq` or `brew install jq` |
| **Can't fetch ADs** | Check region name and `~/.oci/config` file |
| **TooManyRequests** | Normal! Script auto-waits 5 min. Don't spam requests. |
| **Out of capacity** | Expected! Keep running. May take days/weeks. Try lower resources. |
| **Fails immediately** | Check `config.json` syntax, validate OCIDs, verify SSH key path exists |
| **Debug mode** | Run: `bash -x create-ampere-instance.sh` |

---

## Configuration Tips

### Always Free Tier Limits for Ampere A1
- **Total across all A1 instances**: 4 OCPUs and 24 GB RAM
- You can create:
  - 1 instance with 4 OCPUs + 24 GB
  - 2 instances with 2 OCPUs + 12 GB each
  - 4 instances with 1 OCPU + 6 GB each

### Recommended Settings for First Try
- **OCPUs**: 4 (maximum)
- **Memory**: 24 GB (maximum)
- This maximizes your chances as Oracle often releases capacity in full increments

### If Struggling to Get Capacity
Try adjusting your `config.json`:
- **OCPUs**: 1 or 2 (instead of 4)
- **Memory**: 6 or 12 GB (instead of 24)
- **Different region**: Some regions have more capacity
- **Increase wait times**: Set `rate_limit_wait` to 120-180 seconds
