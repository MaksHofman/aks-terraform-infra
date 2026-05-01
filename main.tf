terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }

  # Backend trzyma stan Terraforma w Twoim Blob Storage
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "tfstatetest331"
    container_name       = "tfstate"
    key                  = "aks/terraform.tfstate"
  }
}

provider "azurerm" {
  features {}
}

# Resource Group dla AKS
resource "azurerm_resource_group" "aks_rg" {
  name     = var.resource_group_name
  location = var.location
}

# Virtual Network
resource "azurerm_virtual_network" "vnet" {
  name                = "aks-vnet"
  location            = azurerm_resource_group.aks_rg.location
  resource_group_name = azurerm_resource_group.aks_rg.name
  address_space       = ["10.0.0.0/16"]
}

# Subnet dla node'ów AKS
resource "azurerm_subnet" "aks_subnet" {
  name                 = "aks-subnet"
  resource_group_name  = azurerm_resource_group.aks_rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Klaster AKS
resource "azurerm_kubernetes_cluster" "aks" {
  name                = var.cluster_name
  location            = azurerm_resource_group.aks_rg.location
  resource_group_name = azurerm_resource_group.aks_rg.name
  dns_prefix          = var.cluster_name

  # Control plane (master) - zarządzany przez Azure, bezpłatny
  default_node_pool {
    name           = "workers"
    node_count     = var.worker_count
    vm_size        = var.worker_vm_size
    vnet_subnet_id = azurerm_subnet.aks_subnet.id
  }

  # Tożsamość klastra (zamiast service principal)
  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin = "azure"
    dns_service_ip = "10.0.2.10"
    service_cidr   = "10.0.2.0/24"
  }

  tags = {
    Environment = "learning"
  }
}
