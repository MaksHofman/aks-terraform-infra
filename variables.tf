# =============================================================
# VARIABLES - parametry które możesz zmieniać bez edytowania main.tf
# Wartości podajesz w terraform.tfvars albo przez pipeline
# =============================================================

variable "environment" {
  description = "Nazwa środowiska (dev/staging/prod)"
  type        = string
  default     = "dev"
}

variable "location" {
  description = "Region Azure - westeurope jest blisko Polski"
  type        = string
  default     = "westeurope"
}

variable "vm_size" {
  description = "Rozmiar VM-ek. B2s = najtańsze co działa z K8s"
  type        = string
  default     = "Standard_B2s"
}

variable "admin_username" {
  description = "Nazwa użytkownika na VM-kach"
  type        = string
  default     = "azureuser"
}

variable "ssh_public_key" {
  description = "Twój publiczny klucz SSH. Pipeline wstrzykuje go jako secret."
  type        = string
  # NIE dawaj tu default! To secret - idzie przez pipeline variables
}

variable "suffix" {
  description = "Unikalny suffix dla storage account (tylko małe litery i cyfry, max 8 znaków)"
  type        = string
  default     = "abc123"
  # ZMIEŃ TO na coś unikalnego! Storage account musi mieć globalnie unikalną nazwę
}
