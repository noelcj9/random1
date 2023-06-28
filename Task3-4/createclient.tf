# Create public IPs
resource "azurerm_public_ip" "winclient_public_ip" {
  name                = "${var.winclient_prefix}-${local.random_location}-public-ip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Dynamic"
}

# Create Network Security Group and rules
resource "azurerm_network_security_group" "winclient_nsg" {
  name                = "${var.winclient_prefix}-${local.random_location}-nsg"
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
resource "azurerm_network_interface" "winclient_nic" {
  name                = "${var.winclient_prefix}-${local.random_location}-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_servers = [ "${azurerm_network_interface.dc_nic.private_ip_address}" ]

  ip_configuration {
    name                          = "my_nic_configuration"
    subnet_id                     = azurerm_subnet.my_terraform_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.winclient_public_ip.id
  }
}

# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "winclient_bind" {
  network_interface_id      = azurerm_network_interface.winclient_nic.id
  network_security_group_id = azurerm_network_security_group.winclient_nsg.id
}

# Generate random text for a unique storage account name
resource "random_id" "winclient_storage_account_id" {
  keepers = {
    # Generate a new ID only when a new resource group is defined
    resource_group = azurerm_resource_group.rg.name
  }

  byte_length = 8
}

# Create storage account for boot diagnostics
resource "azurerm_storage_account" "winclient_storage_account" {
  name                     = "diag${random_id.winclient_storage_account_id.hex}"
  location                 = azurerm_resource_group.rg.location
  resource_group_name      = azurerm_resource_group.rg.name
  account_tier             = "Standard"
  account_replication_type = "LRS"
}


# Create virtual machine
resource "azurerm_windows_virtual_machine" "winclient" {
  depends_on = [ azurerm_virtual_machine_extension.install_ad ]
  name                  = "${var.winclient_prefix}-vm"
  admin_username        = "azureuser"
  admin_password        = random_password.password.result
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  network_interface_ids = [azurerm_network_interface.winclient_nic.id]
  size                  = "Standard_DS1_v2"

  os_disk {
    name                 = "winclient_disk"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsDesktop"
    offer     = "Windows-10"
    sku       = "win10-22h2-pro"
    version   = "latest"
  }


  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.winclient_storage_account.primary_blob_endpoint
  }
}

resource "azurerm_virtual_machine_extension" "winclient_join_domain" {
  name = "join_domain"
  virtual_machine_id   = azurerm_windows_virtual_machine.winclient.id
  publisher = "Microsoft.Compute"
  type = "JsonADDomainExtension"
  type_handler_version = "1.3"
  # What the settings mean: https://docs.microsoft.com/en-us/windows/desktop/api/lmjoin/nf-lmjoin-netjoindomain
  settings = <<SETTINGS
  {
    "Name": "contoso.local",
    "User": "contoso.local\\azureuser",
    "Restart": "true",
    "Options": "3"
  }
  SETTINGS
  protected_settings = <<PROTECTED_SETTINGS
  {
    "Password": "${random_password.password.result}"
  }
  PROTECTED_SETTINGS
  depends_on = [azurerm_windows_virtual_machine.DC, azurerm_virtual_machine_extension.install_ad]
}