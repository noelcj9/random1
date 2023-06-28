output "resource_group_name" {
  value = azurerm_resource_group.rg.name
}

output "DC_public_ip_address" {
  value = azurerm_windows_virtual_machine.DC.public_ip_address
}

output "DC_private_ip_address" {
  value = azurerm_network_interface.dc_nic.private_ip_address
}

output "DC_admin_password" {
  sensitive = true
  value     = azurerm_windows_virtual_machine.DC.admin_password
}

output "winclient_public_ip_address" {
  value = azurerm_windows_virtual_machine.winclient.public_ip_address
}

output "winclient_admin_password" {
  sensitive = true
  value     = azurerm_windows_virtual_machine.winclient.admin_password
}

output "winclient_private_ip_address" {
  value = azurerm_network_interface.winclient_nic.private_ip_address
}

output "unixclient_public_ip_address" {
  value = azurerm_linux_virtual_machine.unixclient.public_ip_address
}

output "tls_private_key" {
  value     = tls_private_key.example_ssh.private_key_pem
  sensitive = true
}