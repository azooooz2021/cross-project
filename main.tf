# Provider configuration moved to provider.tf

# Create the resource group first
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

module "network" {
  source              = "./modules/network"
  resource_group_name = var.resource_group_name
  location            = var.location
  vnet_name           = var.vnet_name
  address_space       = var.address_space
  subnet_name         = var.subnet_name
  subnet_prefixes     = var.subnet_prefixes
  
  depends_on = [azurerm_resource_group.rg]
}

module "security" {
  source              = "./modules/security"
  resource_group_name = var.resource_group_name
  location            = var.location
  nsg_name            = var.nsg_name
  subnet_id           = module.network.subnet_id
  
  depends_on = [azurerm_resource_group.rg, module.network]
}

module "vm" {
  source              = "./modules/vm"
  resource_group_name = var.resource_group_name
  location            = var.location
  vm_name             = var.vm_name
  vm_size             = var.vm_size
  admin_username      = var.admin_username
  subnet_id           = module.network.subnet_id
  nsg_id              = module.security.nsg_id
  
  depends_on = [azurerm_resource_group.rg, module.network, module.security]
}
