output "vm_public_ip" {
  description = "Public IP address of the VM"
  value       = module.vm.public_ip_address
}

output "vm_private_ip" {
  description = "Private IP address of the VM"
  value       = module.vm.private_ip_address
}

output "vnet_id" {
  description = "ID of the virtual network"
  value       = module.network.vnet_id
}

output "subnet_id" {
  description = "ID of the subnet"
  value       = module.network.subnet_id
}

output "nsg_id" {
  description = "ID of the network security group"
  value       = module.security.nsg_id
}
