variable "location" {
  description = "Azure region (pick one your subscription allows, e.g. southafricanorth, eastus)"
  type        = string
  default     = "southafricanorth"
}

variable "vm_size" {
  description = "Cheap burstable size; change if not available in your region"
  type        = string
  default     = "Standard_B1s"
}
