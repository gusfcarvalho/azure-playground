terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.4.0"
    }
  }
}

provider "azurerm" {
  tenant_id = "2ed1d494-6c5a-4c5d-aa24-479446fb844d"
  features {}
}