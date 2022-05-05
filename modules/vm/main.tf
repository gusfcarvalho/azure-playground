data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "example" {
  name     = "az-vm-deploy"
  location = var.location
}

resource "random_string" "random" {
  length           = 8
  special          = false
  override_special = "/@£$"
  upper = false 
}

resource "azurerm_virtual_network" "vm" {
  name                = "vm-network"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  address_space       = ["10.0.8.0/22"]

   tags = {
    component = "vm"
  }
}

resource "azurerm_resource_group_policy_assignment" "example" {
  name                 = "example"
  resource_group_id    = azurerm_resource_group.example.id
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/702dd420-7fcc-42c5-afe8-4026edd20fe0"
}

resource "azurerm_private_dns_zone_virtual_network_link" "example" {
  name                  = "link-dns-with-vm-network"
  resource_group_name   = "az-postgres-deploy"
  private_dns_zone_name = "privatelink.postgres.database.azure.com"
  virtual_network_id    = azurerm_virtual_network.vm.id
}

resource "azurerm_network_interface" "example" {
  name                = "example-nic"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name

  ip_configuration {
    name                          = "vm-internal"
    subnet_id                     = azurerm_subnet.example.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id = azurerm_public_ip.example.id
  }
  
}

resource "azurerm_linux_virtual_machine" "example" {
  name                = "example-machine-${random_string.random.result}"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  size                = "Standard_F2"
  admin_username      = "adminuser"
  network_interface_ids = [
    azurerm_network_interface.example.id,
  ]

  admin_ssh_key {
    username   = "adminuser"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }
}
data "azurerm_virtual_network" "postgres" {
  name                = "postgres-network"
  resource_group_name = "az-postgres-deploy"
}
resource "azurerm_subnet" "example" {
  name                 = "vm-subnet"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.vm.name
  address_prefixes     = ["10.0.9.0/24"]
  enforce_private_link_endpoint_network_policies = true
}

resource "azurerm_public_ip" "example" {
  name                = "vm-public-ip"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  allocation_method   = "Dynamic"

}
resource "azurerm_virtual_network_peering" "vm-to-postgres" {
  name                      = "peer-vm-to-postgres"
  resource_group_name       = azurerm_resource_group.example.name
  virtual_network_name      = azurerm_virtual_network.vm.name
  remote_virtual_network_id = data.azurerm_virtual_network.postgres.id
}

resource "azurerm_virtual_network_peering" "postgres-to-vm" {
  name                      = "peer-postgres-to-vm"
  resource_group_name       = "az-postgres-deploy"
  virtual_network_name      = data.azurerm_virtual_network.postgres.name
  remote_virtual_network_id = azurerm_virtual_network.vm.id
}