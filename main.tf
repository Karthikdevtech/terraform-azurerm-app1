resource "azurerm_resource_group" "static_site" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

resource "azurerm_storage_account" "static_site" {
  name                     = var.storage_account_name
  resource_group_name      = azurerm_resource_group.static_site.name
  location                 = azurerm_resource_group.static_site.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"

  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false

  tags = var.tags
}

resource "azurerm_storage_account_static_website" "static_site" {
  storage_account_id = azurerm_storage_account.static_site.id
  index_document     = "index.html"
}

resource "azurerm_storage_blob" "index" {
  name                 = "index.html"
  storage_account_name = azurerm_storage_account.static_site.name
  storage_container_id = "${azurerm_storage_account.static_site.id}/blobServices/default/containers/$web"
  type                 = "Block"
  source               = "${path.module}/index.html"
  content_type         = "text/html"
  content_md5          = filemd5("${path.module}/index.html")

  depends_on = [azurerm_storage_account_static_website.static_site]
}
