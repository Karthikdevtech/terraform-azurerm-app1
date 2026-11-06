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

  tags = var.tags
}
