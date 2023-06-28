# Create public IPs
resource "azurerm_public_ip" "unixclient_public_ip" {
  name                = "unixclient_public_ip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Dynamic"
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "unixclient_nsg" {
  name                = "myNetworkSecurityGroup"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

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
}

# Create network interface
resource "azurerm_network_interface" "unixclient_nic" {
  name                = "myNIC"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_servers = [ "${azurerm_network_interface.dc_nic.private_ip_address}" ]


  ip_configuration {
    name                          = "my_nic_configuration"
    subnet_id                     = azurerm_subnet.my_terraform_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.unixclient_public_ip.id
  }
}

# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "example" {
  network_interface_id      = azurerm_network_interface.unixclient_nic.id
  network_security_group_id = azurerm_network_security_group.unixclient_nsg.id
}

# Generate random text for a unique storage account name
resource "random_id" "unixclient_storage_account_id" {
  keepers = {
    # Generate a new ID only when a new resource group is defined
    resource_group = azurerm_resource_group.rg.name
  }

  byte_length = 8
}

# Create storage account for boot diagnostics
resource "azurerm_storage_account" "unixclient_storage_account" {
  name                     = "diag${random_id.unixclient_storage_account_id.hex}"
  location                 = azurerm_resource_group.rg.location
  resource_group_name      = azurerm_resource_group.rg.name
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# Create (and display) an SSH key
resource "tls_private_key" "example_ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Create virtual machine
resource "azurerm_linux_virtual_machine" "unixclient" {
  name                  = "${var.unixclient_prefix}-vm"
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  network_interface_ids = [azurerm_network_interface.unixclient_nic.id]
  size                  = "Standard_DS1_v2"

  os_disk {
    name                 = "unixclient_disk"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  computer_name                   = "${var.unixclient_prefix}-vm"
  admin_username                  = "azureuser"
  admin_password                  = "Hello@1234321"
  disable_password_authentication = false

  admin_ssh_key {
    username   = "azureuser"
    public_key = tls_private_key.example_ssh.public_key_openssh
  }

  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.unixclient_storage_account.primary_blob_endpoint
  }
}

resource "azurerm_virtual_machine_extension" "unixclient_joindomain" {
  depends_on = [ azurerm_virtual_machine_extension.winclient_join_domain]
  name                 = "unixclient_joindomain"
  virtual_machine_id   = azurerm_linux_virtual_machine.unixclient.id
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.0"
  settings   = <<SETTINGS
    {
        "script": "${base64encode(templatefile(var.unixclient_joindomain_script,{PRIVATE_IP="${azurerm_windows_virtual_machine.DC.private_ip_address}",DOMAIN_FQDN="${var.Domain_DNSName}",DOMAIN_ADMIN="azureuser",PASSWORD="${random_password.password.result}",VM_NAME="${azurerm_linux_virtual_machine.unixclient.computer_name}"}))}"
    }
SETTINGS
}

# data "template_file" "unixclient_joindomain_template" {
#     vars     = {
#       PRIVATE_IP    =   "${azurerm_linux_virtual_machine.unixclient.private_ip_address}"
#       DOMAIN_FQDN   =   "${var.Domain_DNSName}"
#       DOMAIN_ADMIN  =   "azureuser"
#       PASSWORD      =   "'${random_password.password.result}'"
#       VM_NAME       =   "${azurerm_linux_virtual_machine.unixclient.computer_name}"
#   }
# }