resource "azurerm_resource_group" "app" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

resource "azurerm_virtual_network" "app" {
  name                = "${var.vm_name}-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.app.location
  resource_group_name = azurerm_resource_group.app.name
  tags                = var.tags
}

resource "azurerm_subnet" "app" {
  name                 = "${var.vm_name}-subnet"
  resource_group_name  = azurerm_resource_group.app.name
  virtual_network_name = azurerm_virtual_network.app.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_network_security_group" "app" {
  name                = "${var.vm_name}-nsg"
  location            = azurerm_resource_group.app.location
  resource_group_name = azurerm_resource_group.app.name
  tags                = var.tags

  security_rule {
    name                       = "Allow-SSH-from-Trusted-Source"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.ssh_source_cidr
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-HTTP"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "app" {
  subnet_id                 = azurerm_subnet.app.id
  network_security_group_id = azurerm_network_security_group.app.id
}

locals {
  access_storage_account_name = "app${substr(sha256("${var.resource_group_name}-${var.vm_name}"), 0, 21)}"
}

resource "azurerm_storage_account" "access" {
  name                     = local.access_storage_account_name
  resource_group_name      = azurerm_resource_group.app.name
  location                 = azurerm_resource_group.app.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"

  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false

  tags = var.tags
}

resource "azurerm_storage_table" "access" {
  name                 = "siteaccess"
  storage_account_name = azurerm_storage_account.access.name
}

resource "azurerm_user_assigned_identity" "access" {
  name                = "${var.vm_name}-access"
  resource_group_name = azurerm_resource_group.app.name
  location            = azurerm_resource_group.app.location
  tags                = var.tags
}

resource "azurerm_public_ip" "app" {
  name                = "${var.vm_name}-public-ip"
  location            = azurerm_resource_group.app.location
  resource_group_name = azurerm_resource_group.app.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_network_interface" "app" {
  name                = "${var.vm_name}-nic"
  location            = azurerm_resource_group.app.location
  resource_group_name = azurerm_resource_group.app.name
  tags                = var.tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.app.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.app.id
  }
}

resource "azurerm_linux_virtual_machine" "app" {
  name                            = var.vm_name
  computer_name                   = var.vm_name
  resource_group_name             = azurerm_resource_group.app.name
  location                        = azurerm_resource_group.app.location
  size                            = var.vm_size
  admin_username                  = var.admin_username
  disable_password_authentication = true
  network_interface_ids           = [azurerm_network_interface.app.id]
  custom_data = base64encode(<<-CLOUD_INIT
    #!/bin/bash
    set -euo pipefail
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get install --yes nginx
    cat > /var/www/html/index.html <<'HTML'
    ${file("${path.module}/index.html")}
    HTML
    systemctl enable --now nginx
    CLOUD_INIT
  )

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = var.os_disk_size_gb
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.access.id]
  }

  tags = var.tags
}

resource "azurerm_role_assignment" "access" {
  scope                = azurerm_storage_account.access.id
  role_definition_name = "Storage Table Data Contributor"
  principal_id         = azurerm_user_assigned_identity.access.principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_virtual_machine_extension" "access_counter" {
  name                       = "install-access-counter"
  virtual_machine_id         = azurerm_linux_virtual_machine.app.id
  publisher                  = "Microsoft.Azure.Extensions"
  type                       = "CustomScript"
  type_handler_version       = "2.1"
  auto_upgrade_minor_version = true

  settings = jsonencode({
    script = base64encode(templatefile("${path.module}/install-access-counter.sh.tftpl", {
      app_py_base64   = base64encode(file("${path.module}/app.py"))
      index_base64    = base64encode(file("${path.module}/index-v2.1.html"))
      storage_account = azurerm_storage_account.access.name
      table_name      = azurerm_storage_table.access.name
    }))
  })

  depends_on = [
    azurerm_role_assignment.access,
    azurerm_storage_table.access,
  ]
}
