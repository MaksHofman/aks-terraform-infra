variable "resource_group_name" {
  description = "Nazwa Resource Group dla AKS"
  type        = string
  default     = "aks-learning-rg"
}

variable "location" {
  description = "Region Azure"
  type        = string
  default     = "polandcentral"
}

variable "cluster_name" {
  description = "Nazwa klastra AKS"
  type        = string
  default     = "aks-learning-cluster"
}

variable "worker_count" {
  description = "Liczba worker node'ów (2 lub 3)"
  type        = number
  default     = 2
}

variable "worker_vm_size" {
  description = "Rozmiar VM dla worker node'ów"
  type        = string
  default     = "Standard_B2s_v2"  # 2 vCPU, 4GB RAM - tanie do nauki
}
