# Configure the Azure provider
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0.2"
    }
  }

  required_version = ">= 1.1.0"
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id
}

# Create Resource Group
resource "azurerm_resource_group" "TFVM" {

  name     = "TF_Virtual_Machines"
  location = "West US"

  tags = {
    Environment = "Terraform Built VM"
    Team        = "DevOps"
  }
}

# Create Virtual Network
resource "azurerm_virtual_network" "vNet" {

  name                = "TF_vNet"
  location            = azurerm_resource_group.TFVM.location
  resource_group_name = azurerm_resource_group.TFVM.name
  address_space       = ["10.0.0.0/16"]

}

# Create Subnet
resource "azurerm_subnet" "Subnet" {

  name                 = "TF_Subnet"
  resource_group_name  = azurerm_resource_group.TFVM.name
  virtual_network_name = azurerm_virtual_network.vNet.name
  address_prefixes     = ["10.0.1.0/24"]

}

# Create Network Interface
resource "azurerm_network_interface" "NIC" {

  name                = "TFVM_NIC"
  resource_group_name = azurerm_resource_group.TFVM.name
  location            = azurerm_resource_group.TFVM.location

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.Subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.Public.id
  }
}

# Create Public IP
resource "azurerm_public_ip" "Public" {

  name                = "TFIoT_Public_IP"
  resource_group_name = azurerm_resource_group.TFVM.name
  location            = azurerm_resource_group.TFVM.location
  sku                 = "Standard"
  allocation_method   = "Static"
}

# Create Network Security Group
resource "azurerm_network_security_group" "NSG" {

  name                = "TF_NSG"
  location            = azurerm_resource_group.TFVM.location
  resource_group_name = azurerm_resource_group.TFVM.name

  security_rule {
    name                       = "allow-ssh"
    priority                   = "100"
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  

}

# Create Network Interface Security Group Association
resource "azurerm_network_interface_security_group_association" "NISGA" {
  network_interface_id      = azurerm_network_interface.NIC.id
  network_security_group_id = azurerm_network_security_group.NSG.id
}


# Create Windows virtual machine
resource "azurerm_virtual_machine" "WVM" {
  name                  = "WindowsVM"
  location              = azurerm_resource_group.TFVM.location
  resource_group_name   = azurerm_resource_group.TFVM.name
  network_interface_ids = [azurerm_network_interface.NIC.id]
  vm_size               = "Standard_B1s"

  # Create disk for VM
  storage_os_disk {
    name              = "TFwin_Disk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  # Create Storage disk for VM   
  storage_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-azure-edition"
    version   = "latest"
  }

  # Create OS profile    
  os_profile {
    computer_name  = "TFVM2"
    admin_username = var.admin_username
    admin_password = var.admin_password
  }
  
  os_profile_windows_config {
  }

}

