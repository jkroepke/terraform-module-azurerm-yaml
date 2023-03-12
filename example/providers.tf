terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.47"
    }
  }
}

provider "azurerm" {
  features {}
}
