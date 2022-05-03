data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "example" {
  name     = "az-kv-deploy"
  location = var.location
}

resource "random_string" "random" {
  length           = 8
  special          = false
  override_special = "/@£$"
  upper = false 
}
resource "azurerm_key_vault" "example" {
  name                        = "examplekeyvault-${random_string.random.result}"
  location                    = azurerm_resource_group.example.location
  resource_group_name         = azurerm_resource_group.example.name
  enabled_for_disk_encryption = false
  tenant_id                   = data.azurerm_client_config.current.tenant_id

  sku_name = "standard"
  enable_rbac_authorization = true

}


resource "azurerm_virtual_network" "example" {
  name                = "keyvault-network"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  address_space       = ["10.0.0.0/22"]

   tags = {
    component = "keyvault"
  }
}

resource "azurerm_subnet" "example" {
  name                 = "example-subnet"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.example.name
  address_prefixes     = ["10.0.1.0/24"]
  enforce_private_link_endpoint_network_policies = true
}

resource "azurerm_private_dns_zone" "example" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = azurerm_resource_group.example.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "example" {
  name                  = "private-endpoint-link"
  resource_group_name   = azurerm_resource_group.example.name
  private_dns_zone_name = azurerm_private_dns_zone.example.name
  virtual_network_id    = azurerm_virtual_network.example.id
}

resource "azurerm_private_endpoint" "example" {
  name                = "example-endpoint"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  subnet_id           = azurerm_subnet.example.id

  private_dns_zone_group {
    name = "zone-group"
    private_dns_zone_ids = [
        azurerm_private_dns_zone.example.id
    ]

  }
  private_service_connection {
    name                           = "example-privateserviceconnection"
    private_connection_resource_id = azurerm_key_vault.example.id
    subresource_names = [
        "vault"
    ]
    is_manual_connection           = false
  }
}