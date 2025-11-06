# OCI Ampere ARM Instance Auto-Provisioner

A bash script that automatically attempts to create an Oracle Cloud Infrastructure (OCI) "Always Free" Ampere ARM instance by cycling through all Availability Domains until capacity is found.

## What This Script Does

Oracle's Always Free Ampere A1 instances are highly sought after but often show "Out of capacity" errors. This script:

- ✅ Loops through all Availability Domains in your region
- ✅ Continuously retries until an instance is successfully created
- ✅ Displays timestamps and attempt counts for tracking
- ✅ Validates your input IDs before starting
- ✅ Can run for hours or days until capacity is found

## ⚠️ Important Notes

- **This can take a LONG time**: Days or even weeks depending on region and demand
- **Leave it running**: Use `screen` or `tmux` to keep it running in the background
- **Always Free limits**: You get up to 4 OCPUs and 24GB RAM total across all A1 instances
- **The script does NOT save your credentials**: You enter them each time you run it

---

## Prerequisites (One-Time Setup)

You must complete these steps manually before running the script.

### 1. Install OCI CLI

Install the Oracle Cloud Infrastructure command-line tool:

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

## How to Find Your IDs

The script will ask you for these values. Here's where to find them in the OCI Console:

### Compartment ID
1. Go to **Identity & Security** → **Compartments**
2. Find your compartment (or use the root compartment)
3. Click it and copy the **OCID**

**Example:** `ocid1.compartment.oc1..aaaaaaaxxxxxxxxxxxxxxxxxxxxx`

### Subnet ID
1. Go to **Networking** → **Virtual Cloud Networks**
2. Click your VCN (create one if you don't have it)
3. Click **Subnets** in the left menu
4. Click your subnet and copy the **OCID**

**Example:** `ocid1.subnet.oc1.iad.aaaaaaaxxxxxxxxxxxxxxxxxxxxx`

### Image ID
1. Go to **Compute** → **Instances** → **Create Instance**
2. In the "Image and shape" section, click **Change image**
3. Select **Platform Images**
4. Choose an **Always Free-eligible** ARM64 image (like Ubuntu or Oracle Linux)
5. Copy the **OCID** shown


> **Note:** Image IDs are region-specific. Make sure to use an image from your region.

### Region
This is your OCI region identifier. Common examples:
- `us-ashburn-1` (US East)
- `eu-frankfurt-1` (Germany)
- `ap-tokyo-1` (Japan)

Your region should match what you configured during `oci setup config`.

### SSH Public Key
This is the full text of your SSH public key file, typically located at:
- Linux/macOS: `~/.ssh/id_rsa.pub`
- Windows: `C:\Users\YourName\.ssh\id_rsa.pub`

**To view it:**
```bash
cat ~/.ssh/id_rsa.pub
```

It should look like: `ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC...`

**Don't have an SSH key?** Generate one:
```bash
ssh-keygen -t rsa -b 4096
```

---

## How to Use the Script

### 1. Make the script executable (Linux/macOS)
```bash
chmod +x create-ampere-instance.sh
```

### 2. Run the script
```bash
./create-ampere-instance.sh
```

### 3. Enter your details when prompted
- Compartment ID
- Image ID  
- Subnet ID
- Region
- OCPU count (1-4, default: 4)
- Memory in GB (6-24, default: 24)
- SSH public key (paste and press Ctrl+D)

### 4. Let it run
The script will continuously attempt to create the instance. You'll see output like:

```
[2025-11-06 10:30:45] Attempt #1 - Trying AD: nUoC:US-ASHBURN-AD-1
Failed in nUoC:US-ASHBURN-AD-1 (likely 'Out of Capacity').
Waiting 10 seconds before trying next AD...
[2025-11-06 10:31:00] Attempt #2 - Trying AD: nUoC:US-ASHBURN-AD-2
...
```

### 5. Keep it running in the background

**Using `screen` (recommended):**
```bash
screen -S oci-provision
./create-ampere-instance.sh
# Press Ctrl+A then D to detach
# Reattach later with: screen -r oci-provision
```

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
Try requesting less:
- **OCPUs**: 1 or 2
- **Memory**: 6 or 12 GB
