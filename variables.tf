variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "datahub-rg"
}
variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
  # No default value - must be provided in terraform.tfvars
}

variable "tenant_id" {
  description = "Azure tenant ID"
  type        = string
  # No default value - must be provided in terraform.tfvars
}
variable "location" {
  description = "Azure region to deploy resources"
  type        = string
  default     = "westus2"
}

# Network variables
variable "vnet_name" {
  description = "Name of the virtual network"
  type        = string
  default     = "datahub-vnet"
}

variable "address_space" {
  description = "Address space for the virtual network"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "subnet_name" {
  description = "Name of the subnet"
  type        = string
  default     = "datahub-subnet"
}

variable "subnet_prefixes" {
  description = "Address prefixes for the subnet"
  type        = list(string)
  default     = ["10.0.1.0/24"]
}

# Security variables
variable "nsg_name" {
  description = "Name of the network security group"
  type        = string
  default     = "datahub-nsg"
}

# VM variables
variable "vm_name" {
  description = "Name of the virtual machine"
  type        = string
  default     = "datahub-vm"
}

variable "vm_size" {
  description = "Size of the virtual machine"
  type        = string
  default     = "Standard_D2s_v3"
}

variable "admin_username" {
  description = "Admin username for the VM"
  type        = string
  default     = "adminuser"
}

