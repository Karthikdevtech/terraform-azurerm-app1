# Azure Static Website Module

This repository is a single Terraform module. Version 1 (`1.0.0`) creates an Azure resource group and a StorageV2 account, enables static website hosting, and uploads `index.html` to the `$web` container.

## Deploy version 1

Prerequisites: Terraform 1.5 or later, Azure CLI, and an Azure subscription with permission to create resource groups and storage accounts.

```powershell
az login
az account set --subscription "<subscription-id>"
terraform init
terraform fmt -check
terraform validate
terraform plan -var="storage_account_name=<globally-unique-name>"
terraform apply -var="storage_account_name=<globally-unique-name>"
```

The storage account name must be 3-24 lowercase letters or numbers and globally unique across Azure. Override the defaults as needed:

```powershell
terraform apply `
  -var="storage_account_name=<globally-unique-name>" `
  -var="resource_group_name=rg-my-static-site" `
  -var="location=westus2"
```

Terraform prints the website URL as `static_website_url`. When finished experimenting, run `terraform destroy` to remove the resources.

## Semantic versioning learning roadmap

Use `MAJOR.MINOR.PATCH`:

- **Major**: incompatible changes to the module interface or behavior. Planned `2.0.0`: replace the static website deployment with virtual machines.
- **Minor**: backward-compatible functionality. Planned `2.1.0`: add a database and tracking of access counts (the measurement/telemetry design still needs to be selected).
- **Patch**: backward-compatible fixes or changes that do not alter the module contract. Planned `2.1.1`: increase disk space, once the VM/database design exists.

For Terraform Registry releases, publish a Git tag such as `v1.0.0`. Keep the module files at the repository root; the registry expects one module in this repository.
