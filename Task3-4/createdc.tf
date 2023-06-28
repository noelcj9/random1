locals {
  random_location = join("",random_shuffle.locations.result)
}

resource "azurerm_resource_group" "rg" {
  location = var.resource_group_location
  name     = "${var.DC_prefix}-${local.random_location}-rg"
}

# Create virtual network
resource "azurerm_virtual_network" "my_terraform_network" {
  name                = "${var.DC_prefix}-${local.random_location}-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Create subnet
resource "azurerm_subnet" "my_terraform_subnet" {
  name                 = "${var.DC_prefix}-${local.random_location}-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.my_terraform_network.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Create public IPs
resource "azurerm_public_ip" "dc_public_ip" {
  name                = "${var.DC_prefix}-${local.random_location}-public-ip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Dynamic"

}

# Create Network Security Group and rules
resource "azurerm_network_security_group" "dc_nsg" {
  name                = "${var.DC_prefix}-${local.random_location}-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "RDP"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "web"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Create network interface
resource "azurerm_network_interface" "dc_nic" {
  name                = "${var.DC_prefix}-${local.random_location}-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "dc_nic_configuration"
    subnet_id                     = azurerm_subnet.my_terraform_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.dc_public_ip.id
  }
}

# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "dc_bind" {
  network_interface_id      = azurerm_network_interface.dc_nic.id
  network_security_group_id = azurerm_network_security_group.dc_nsg.id
}

# Create storage account for boot diagnostics
resource "azurerm_storage_account" "dc_storage_account" {
  name                     = "diag${random_id.dc_storage_account_id.hex}"
  location                 = azurerm_resource_group.rg.location
  resource_group_name      = azurerm_resource_group.rg.name
  account_tier             = "Standard"
  account_replication_type = "LRS"
}


# Create virtual machine
resource "azurerm_windows_virtual_machine" "DC" {
  name                  = "${var.DC_prefix}-vm"
  admin_username        = "azureuser"
  admin_password        = random_password.password.result
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  network_interface_ids = [azurerm_network_interface.dc_nic.id]
  size                  = "Standard_DS1_v2"

  os_disk {
    name                 = "DC_disk"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2016-Datacenter"
    version   = "latest"
  }


  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.dc_storage_account.primary_blob_endpoint
  }
}

# Generate random text for a unique storage account name
resource "random_id" "dc_storage_account_id" {
  keepers = {
    # Generate a new ID only when a new resource group is defined
    resource_group = azurerm_resource_group.rg.name
  }

  byte_length = 8
}

resource "random_password" "password" {
  length      = 20
  min_lower   = 1
  min_upper   = 1
  min_numeric = 1
  min_special = 1
  special     = true
  override_special = "!#*()-_=+[]<>:?"
}

resource "random_password" "AdministratorPassword" {
  length      = 8
  min_lower   = 1
  min_upper   = 1
  min_numeric = 1
  min_special = 1
  special     = true
}

#Install Active Directory on the DC01 VM
resource "azurerm_virtual_machine_extension" "install_ad" {
  name                 = "install_ad"
  virtual_machine_id   = azurerm_windows_virtual_machine.DC.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.9"
  
  protected_settings = <<SETTINGS
  {    
    "commandToExecute": "powershell -command \"[System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String('${base64encode(data.template_file.ADDS.rendered)}')) | Out-File -filepath ADDS.ps1\" && powershell -ExecutionPolicy Unrestricted -File ADDS.ps1 -Domain_DNSName ${data.template_file.ADDS.vars.Domain_DNSName} -Domain_NETBIOSName ${data.template_file.ADDS.vars.Domain_NETBIOSName} -SafeModeAdministratorPassword ${data.template_file.ADDS.vars.SafeModeAdministratorPassword}"
  }
  SETTINGS

}

#Variable input for the ADDS.ps1 script
data "template_file" "ADDS" {
    template = "${file("ADDS.ps1")}"
    vars = {
        Domain_DNSName          = "${var.Domain_DNSName}"
        Domain_NETBIOSName      = "${var.netbios_name}"
        SafeModeAdministratorPassword = "${random_password.AdministratorPassword.result}"
  }
}

resource "random_shuffle" "locations" {
  keepers = {
    first = "${timestamp()}"
  }
  input        = ["japan", "china", "beijing", "tokyo", "vienna", "hungary", "austria", "london", "paris", "france", "sydney", "australia", "berlin", "germany", "mumbai", "india", "rio de janeiro", "brazil", "istanbul", "turkey", "cairo", "egypt", "moscow", "russia", "rome", "italy", "toronto", "canada"]
  result_count = 1
}