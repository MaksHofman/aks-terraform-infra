# =============================================================
# OUTPUTS - Terraform wypisze te wartości po "apply"
# Pipeline używa ich żeby wiedzieć gdzie są VM-ki
# =============================================================

output "master_public_ip" {
  description = "Publiczny IP mastera - tu się łączysz przez SSH i kubectl"
  value       = azurerm_public_ip.master.ip_address
}

output "master_private_ip" {
  description = "Prywatny IP mastera w sieci wewnętrznej"
  value       = azurerm_network_interface.master.private_ip_address
}

output "worker_private_ips" {
  description = "Prywatne IP wszystkich workerów"
  value       = azurerm_network_interface.workers[*].private_ip_address
}

output "resource_group_name" {
  description = "Nazwa resource group - przyda się do az cli"
  value       = azurerm_resource_group.k8s.name
}
