output "cluster_name" {
  value = azurerm_kubernetes_cluster.aks.name
}

output "resource_group" {
  value = azurerm_resource_group.aks_rg.name
}

# Komenda do pobrania kubeconfig (wyświetlana po apply)
output "kubeconfig_command" {
  value = "az aks get-credentials --resource-group ${azurerm_resource_group.aks_rg.name} --name ${azurerm_kubernetes_cluster.aks.name}"
}
