# Azure Linux VM Module

This repository contains one Terraform Registry module. Version `2.0.0` is a major, breaking change from `1.x`: instead of Azure Storage static website hosting, it creates an Ubuntu Linux VM and serves `index.html` using Nginx.

The module also creates a virtual network, subnet, network security group, static public IP, and network interface. HTTP (port 80) is open to the internet so the website can be viewed. SSH (port 22) is restricted to the configured source CIDR and uses an SSH public key; password authentication is disabled.

## Requirements

- Terraform 1.5 or later
- Azure CLI and an Azure subscription with permission to create networking and compute resources
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

Terraform outputs `website_url`, `vm_public_ip`, and `ssh_command`. The website is available over HTTP after the VM finishes its first-boot Nginx setup. Destroy the resources when finished experimenting:

```powershell
terraform destroy
```

## Release and upgrade

Publish this module as `v2.0.0` in the Terraform Registry. Update any calling configuration to version `2.0.0` and provide `ssh_public_key` and `ssh_source_cidr`.

This major upgrade removes the v1 Storage website resources and creates VM/network resources. Review the Terraform plan carefully before applying: it will destroy the old static website resources in the same state. Keep and use the `1.x` registry release if you need to continue managing the v1 deployment.

Semantic versioning roadmap:

- `2.0.0`: breaking move from Storage static website to Ubuntu VM + Nginx.
- `2.1.0`: planned backward-compatible database and access-counting capability; monitoring design needs to be selected.
- `2.1.1`: planned patch release to increase the OS disk default from 30 GB.
