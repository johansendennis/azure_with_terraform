terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.3.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = "1244087b-9673-4698-8804-02c33afdf642"
}

# Create a resource group
resource "azurerm_resource_group" "rg" {
  name     = "myTFResourceGroup"
  location = "NorwayEast"
}

# Create a virtual network with tags
resource "azurerm_virtual_network" "vnet" { 
  name                = "myTFVNet" 
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  # Add tags
  tags = {
    environment = "Terraform Getting Started"
    owner       = "DevOps"
  }
}

# Create a subnet for the VM
resource "azurerm_subnet" "subnet" {
  name                 = "myTFSubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name 
  address_prefixes     = ["10.0.1.0/24"]
}

# Create the Azure Bastion subnet
resource "azurerm_subnet" "bastion_subnet" {
  name                 = "AzureBastionSubnet"  # Name must be exactly "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"] 
}

# Create a Public IP for the Bastion Host
resource "azurerm_public_ip" "bastion_pip" {
  name                = "myBastionPIP"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  allocation_method   = "Static"
  sku                 = "Standard"  # Required for Bastion
}

# Create Azure Bastion Host with Developer SKU
resource "azurerm_bastion_host" "bastion" {
  name                = "myBastionHost"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  virtual_network_id  = azurerm_virtual_network.vnet.id
  sku = "Basic" # standard for production

  ip_configuration {
    name                 = "myBastionIPConfig"
    subnet_id            = azurerm_subnet.bastion_subnet.id  # Correct reference to bastion subnet
    public_ip_address_id = azurerm_public_ip.bastion_pip.id
  }

  tags = {
    environment = "Terraform Getting Started"
    owner       = "DevOps"
  }
}

# Create a Network Security Group (NSG)
resource "azurerm_network_security_group" "nsg" {
  name                = "myTFNSG"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  # Add tags
  tags = {
    environment = "Terraform Getting Started"
    owner       = "DevOps"
  }
}

# NSG rule for Azure Bastion outbound connectivity to Azure Bastion service
resource "azurerm_network_security_rule" "allow_bastion_outbound" {
  name                        = "AllowBastionOutbound"
  priority                    = 100
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"  # Azure Bastion uses HTTPS
  source_address_prefix       = "*"
  destination_address_prefix  = "10.0.2.0/24"
  network_security_group_name = azurerm_network_security_group.nsg.name
  resource_group_name         = azurerm_resource_group.rg.name
}

# NSG rule to allow RDP traffic within the virtual network (for Azure Bastion)
resource "azurerm_network_security_rule" "allow_rdp_internal" {
  name                        = "AllowRDPInternal"
  priority                    = 200
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "3389"  # RDP port for Windows VMs
  source_address_prefix       = "10.0.2.0/24"
  destination_address_prefix  = "*"
  network_security_group_name = azurerm_network_security_group.nsg.name
  resource_group_name         = azurerm_resource_group.rg.name
}

# NSG rule for Azure Bastion subnet (Bastion can reach the VM over private IP)
resource "azurerm_network_security_rule" "allow_bastion_rdp" {
  name                        = "AllowBastionRDP"
  priority                    = 300
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "3389"  # RDP
  source_address_prefix       = "10.0.2.0/24"
  destination_address_prefix  = "*"
  network_security_group_name = azurerm_network_security_group.nsg.name
  resource_group_name         = azurerm_resource_group.rg.name
}

# Associate the NSG with the subnet
resource "azurerm_subnet_network_security_group_association" "subnet_nsg_association" {
  subnet_id                 = azurerm_subnet.subnet.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

# Create a Network Interface for the VM
resource "azurerm_network_interface" "nic" {
  name                = "myTFNIC"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "myTFNICIPConfig"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

# Create a variable for the admin password
variable "admin_password" {
  description = "The admin password for the Windows VM."
  type        = string
  sensitive   = true  # Mark as sensitive to avoid displaying it in output
}

# Create a Windows Virtual Machine
resource "azurerm_windows_virtual_machine" "win_vm" {
  name                = "myTFWindowsVM"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_DS1_v2"
  admin_username      = "adminuser"
  admin_password      = var.admin_password  # Using the variable for the password

  network_interface_ids = [
    azurerm_network_interface.nic.id,
  ]

  os_disk {
    name              = "myTFWindowsOSDisk"
    caching           = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }

  computer_name = "mywinvm"
}
