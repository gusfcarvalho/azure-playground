data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "example" {
  name     = "az-postgres-deploy"
  location = var.location
}

resource "random_string" "random" {
  length           = 8
  special          = false
  override_special = "/@£$"
  upper = false 
}

resource "azurerm_postgresql_server" "example" {
  name                = "example-psqlserver-${random_string.random.result}"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name

  administrator_login          = "psqladmin"
  administrator_login_password = "H@Sh1CoR3!"

  sku_name   = "GP_Gen5_4"
  version    = "9.6"
  storage_mb = 10240

  backup_retention_days        = 7
  geo_redundant_backup_enabled = false
  auto_grow_enabled            = false

  public_network_access_enabled    = false
  ssl_enforcement_enabled          = true
  ssl_minimal_tls_version_enforced = "TLS1_2"
}

resource "azurerm_virtual_network" "example" {
  name                = "postgres-network"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  address_space       = ["10.0.4.0/22"]

   tags = {
    component = "postgres"
  }
}

resource "azurerm_subnet" "example" {
  name                 = "postgres-subnet"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.example.name
  address_prefixes     = ["10.0.4.0/24"]
  enforce_private_link_endpoint_network_policies = true
}

resource "azurerm_private_dns_zone" "example" {
  name                = "privatelink.postgres.database.azure.com"
  resource_group_name = azurerm_resource_group.example.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "example" {
  name                  = "postgres-net-private-link"
  resource_group_name   = azurerm_resource_group.example.name
  private_dns_zone_name = azurerm_private_dns_zone.example.name
  virtual_network_id    = azurerm_virtual_network.example.id
}

resource "azurerm_private_endpoint" "example" {
  name                = "postgres-endpoint"
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
    name                           = "postgres-privateservice-connection"
    private_connection_resource_id = azurerm_postgresql_server.example.id
    subresource_names = [
        "postgresqlServer"
    ]
    is_manual_connection           = false
  }
}