output "vm_id" {
  description = "Resource ID of the Windows VM."
  value       = azurerm_windows_virtual_machine.vm.id
}

output "private_ip_address" {
  description = "Private IP address used for RDP and SQL over the connected private network."
  value       = azurerm_network_interface.vm.private_ip_address
}

output "sql_server_name" {
  description = "SQL Server Express named instance."
  value       = "${azurerm_windows_virtual_machine.vm.name}\\SQLEXPRESS"
}

output "sql_tcp_port" {
  description = "Configured private SQL Server TCP port."
  value       = var.sql_tcp_port
}

output "nat_gateway_public_ip" {
  description = "Stable outbound-only public IP used by the private subnet."
  value       = azurerm_public_ip.egress.ip_address
}
