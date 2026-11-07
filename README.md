# Azure Linux VM Module

This repository contains one Terraform Registry module.

- `2.0.0` replaced the v1 Storage static website with an Ubuntu VM running Nginx.
- `2.1.0` adds a page-load counter backed by Azure Table Storage. This is a backward-compatible addition: existing VM inputs and website/SSH outputs remain available.
- `2.1.1` keeps the original VM bootstrap content unchanged so installing the counter does not force VM replacement.
- `2.1.2` uses a user-assigned managed identity for the table permission and increases the default OS disk size to 64 GB.
- `2.1.3` adds a separately managed 32 GB data disk, attached at LUN 0 and mounted as `/mnt/app-data`.

The module creates a virtual network, subnet, network security group, static public IP, network interface, VM, Storage account, table, user-assigned managed identity, and managed data disk. HTTP (port 80) is open to serve the site; SSH (port 22) is restricted to the configured source CIDR and uses an SSH public key. The VM's user-assigned managed identity is granted `Storage Table Data Contributor`; no storage key is placed on the VM.

Azure Table Storage is a low-cost, usage-based NoSQL option for a small learning counter. Azure charges for storage and transactions; charges depend on usage and region. The API increments the total for each browser page load. It does not identify unique visitors. The counter uses conditional updates so concurrent page loads do not silently overwrite each other.

The 32 GB Standard_LRS managed data disk is billed separately. On first setup, the VM extension formats a blank disk as ext4 and mounts it at `/mnt/app-data`; the mount is added to `/etc/fstab` by UUID so it survives VM restarts. Do not put files on this disk that you need to keep if you plan to roll back to `2.0.0`.

## Requirements

- Terraform 1.5 or later
- Azure CLI and an Azure subscription with permission to create networking, compute, storage, and role assignments
- An SSH key pair

Create a key pair on Windows if needed:

```powershell
ssh-keygen -t ed25519 -f "$env:USERPROFILE\.ssh\app-v2"
```

Use the `.pub` public key file in Terraform configuration. Never provide or upload the private key.

## Deploy locally

```powershell
az login
az account set --subscription "<subscription-id>"
terraform init
terraform fmt -check
terraform validate
```

Provide the public key and your public IP in a `terraform.tfvars` file:

```hcl
ssh_public_key  = "ssh-ed25519 AAAA... your-key-comment"
ssh_source_cidr = "203.0.113.10/32"
```

Replace the example CIDR with your actual public IP in `/32` notation. Then review and apply:

```powershell
terraform plan
terraform apply
```

Terraform outputs `website_url`, `vm_public_ip`, `ssh_command`, `access_count_table_name`, `data_disk_name`, and `data_disk_mount_path`. Open the website URL; each page load increments the counter shown on the page. The first request may briefly fail while Azure propagates the managed-identity role assignment; reload the page to retry. The website itself remains available if the counter is temporarily unavailable.

Destroy the resources when finished experimenting:

```powershell
terraform destroy
```

## Release and upgrade

Publish this module as `v2.1.3` in the Terraform Registry, then update the calling configuration to version `2.1.3`. The original `index.html` remains the VM's creation-time bootstrap page; the VM extension installs the counter-enabled `index-v2.1.html` and mounts the data disk without changing the VM's `custom_data`. A user-assigned managed identity provides the table permission. Review the Terraform plan before applying and confirm that the VM is not replaced.

### Rolling back to `2.0.0`

In the calling configuration, set the module version to `2.0.0` and explicitly preserve the running VM's current `vm_size` and `os_disk_size_gb` values. For example, if they are still `Standard_F1als_v7` and 64 GB:

```hcl
module "app1" {
  source  = "app.terraform.io/learn-devops-project123/app1/azurerm"
  version = "2.0.0"

  vm_size         = "Standard_F1als_v7"
  os_disk_size_gb = 64

  ssh_public_key  = var.ssh_public_key
  ssh_source_cidr = var.ssh_source_cidr
}
```

Then run `terraform init -upgrade` and `terraform plan`. Proceed only if the plan does not say the VM must be replaced. The rollback removes the counter resources and the data disk/attachment; data on the data disk is deleted. Back it up first if it matters. The 64 GB OS disk and VM size overrides are essential to avoid a VM replacement caused by shrinking the OS disk or changing the VM SKU.

Semantic-versioning roadmap:

- `2.0.0`: breaking move from Storage static website to Ubuntu VM + Nginx.
- `2.1.0`: add the Azure Table Storage page-load counter.
- `2.1.1`: preserve the existing VM during the page-counter upgrade.
- `2.1.2`: use a user-assigned managed identity and increase the OS disk default to 64 GB.
- `2.1.3`: add an independently managed 32 GB data disk and document a safe rollback.
