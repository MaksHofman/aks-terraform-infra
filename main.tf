# =============================================================
# PROVIDER - mówi Terraformowi "pracuj z Azure"
# =============================================================
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }

 
}

provider "azurerm" {
  features {}
}

# =============================================================
# RESOURCE GROUP - "folder" w Azure na wszystkie nasze zasoby
# =============================================================
resource "azurerm_resource_group" "k8s" {
  name     = "rg-k8s-${var.environment}"
  location = var.location

  tags = {
    Environment = var.environment
    Project     = "k8s-cluster"
    ManagedBy   = "Terraform"
  }
}

# =============================================================
# VIRTUAL NETWORK - prywatna sieć łącząca wszystkie VM-ki
# Bez tego VM-ki nie mogą ze sobą gadać
# =============================================================
resource "azurerm_virtual_network" "k8s" {
  name                = "vnet-k8s-${var.environment}"
  address_space       = ["10.0.0.0/16"]  # pula adresów IP dla całej sieci
  location            = azurerm_resource_group.k8s.location
  resource_group_name = azurerm_resource_group.k8s.name
}

# SUBNET - "pod-sieć" dla naszych VM-ek
resource "azurerm_subnet" "k8s" {
  name                 = "subnet-k8s"
  resource_group_name  = azurerm_resource_group.k8s.name
  virtual_network_name = azurerm_virtual_network.k8s.name
  address_prefixes     = ["10.0.1.0/24"]  # VM-ki dostaną adresy 10.0.1.x
}

# =============================================================
# NETWORK SECURITY GROUP - firewall, kto może się połączyć
# =============================================================
resource "azurerm_network_security_group" "k8s" {
  name                = "nsg-k8s-${var.environment}"
  location            = azurerm_resource_group.k8s.location
  resource_group_name = azurerm_resource_group.k8s.name

  # Pozwól na SSH (port 22) - żebyś mógł się zalogować
  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Pozwól na K8s API (port 6443) - kubectl będzie tego używał
  security_rule {
    name                       = "K8s-API"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "6443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Podepnij NSG do naszego subnetu
resource "azurerm_subnet_network_security_group_association" "k8s" {
  subnet_id                 = azurerm_subnet.k8s.id
  network_security_group_id = azurerm_network_security_group.k8s.id
}

# =============================================================
# MASTER NODE - jeden, zarządza całym klastrem K8s
# =============================================================

# Publiczny IP dla mastera - żebyś mógł się z nim połączyć z zewnątrz
resource "azurerm_public_ip" "master" {
  name                = "pip-k8s-master"
  location            = azurerm_resource_group.k8s.location
  resource_group_name = azurerm_resource_group.k8s.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# Karta sieciowa mastera (jak karta sieciowa w komputerze)
resource "azurerm_network_interface" "master" {
  name                = "nic-k8s-master"
  location            = azurerm_resource_group.k8s.location
  resource_group_name = azurerm_resource_group.k8s.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.k8s.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.0.1.10"  # stały prywatny IP mastera
    public_ip_address_id          = azurerm_public_ip.master.id
  }
}

# Sama VM - master
resource "azurerm_linux_virtual_machine" "master" {
  name                = "vm-k8s-master"
  location            = azurerm_resource_group.k8s.location
  resource_group_name = azurerm_resource_group.k8s.name
  size                = var.vm_size
  admin_username      = var.admin_username

  # Podepnij kartę sieciową
  network_interface_ids = [azurerm_network_interface.master.id]

  # Logowanie przez klucz SSH (bezpieczniejsze niż hasło)
  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key
  }

  # Dysk systemowy
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"  # najtańszy typ dysku
    disk_size_gb         = 30
  }

  # Ubuntu 22.04 LTS
  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  tags = {
    Role        = "master"
    Environment = var.environment
  }
}

# =============================================================
# WORKER NODES - trzy, tu faktycznie chodzą Twoje aplikacje
# =============================================================

# Karty sieciowe dla workerów (tworzymy 3 naraz pętlą count)
resource "azurerm_network_interface" "workers" {
  count               = 3  # <- magia! tworzy 3 karty naraz
  name                = "nic-k8s-worker-${count.index + 1}"
  location            = azurerm_resource_group.k8s.location
  resource_group_name = azurerm_resource_group.k8s.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.k8s.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.0.1.${20 + count.index}"  # 10.0.1.20, .21, .22
  }
}

# VM-ki dla workerów (znowu pętla count = 3)
resource "azurerm_linux_virtual_machine" "workers" {
  count               = 3
  name                = "vm-k8s-worker-${count.index + 1}"
  location            = azurerm_resource_group.k8s.location
  resource_group_name = azurerm_resource_group.k8s.name
  size                = var.vm_size
  admin_username      = var.admin_username

  network_interface_ids = [azurerm_network_interface.workers[count.index].id]

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = 30
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  tags = {
    Role        = "worker"
    Environment = var.environment
  }
}
