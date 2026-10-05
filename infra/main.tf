terraform {
  required_version = ">= 1.8.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.8"
    }
  }

  backend "azurerm" {}
}

provider "azurerm" {
  features {}

  subscription_id = var.subscription_id
}

data "azurerm_resource_group" "target" {
  name = var.resource_group_name
}

locals {
  name_prefix = var.vm_name
  trusted_firewall_ranges = distinct(concat(
    var.vnet_address_space,
    var.vpn_client_address_prefixes,
  ))
  sql_install_script = templatefile("${path.module}/scripts/install-sql.ps1.tftpl", {
    sql_media_url           = var.sql_media_url
    trusted_firewall_ranges = jsonencode(local.trusted_firewall_ranges)
  })
}

resource "azurerm_virtual_network" "vm" {
  name                = "${local.name_prefix}-vnet"
  location            = data.azurerm_resource_group.target.location
  resource_group_name = data.azurerm_resource_group.target.name
  address_space       = var.vnet_address_space
  tags                = var.tags
}

resource "azurerm_subnet" "vm" {
  name                            = "workload"
  resource_group_name             = data.azurerm_resource_group.target.name
  virtual_network_name            = azurerm_virtual_network.vm.name
  address_prefixes                = [var.subnet_address_prefix]
  default_outbound_access_enabled = false
}

resource "azurerm_public_ip" "egress" {
  name                = "${local.name_prefix}-nat-pip"
  location            = data.azurerm_resource_group.target.location
  resource_group_name = data.azurerm_resource_group.target.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_nat_gateway" "egress" {
  name                    = "${local.name_prefix}-nat"
  location                = data.azurerm_resource_group.target.location
  resource_group_name     = data.azurerm_resource_group.target.name
  sku_name                = "Standard"
  idle_timeout_in_minutes = 10
  tags                    = var.tags
}

resource "azurerm_nat_gateway_public_ip_association" "egress" {
  nat_gateway_id       = azurerm_nat_gateway.egress.id
  public_ip_address_id = azurerm_public_ip.egress.id
}

resource "azurerm_subnet_nat_gateway_association" "vm" {
  subnet_id      = azurerm_subnet.vm.id
  nat_gateway_id = azurerm_nat_gateway.egress.id
}

resource "azurerm_network_security_group" "vm" {
  name                = "${local.name_prefix}-nsg"
  location            = data.azurerm_resource_group.target.location
  resource_group_name = data.azurerm_resource_group.target.name
  tags                = var.tags
}

resource "azurerm_network_security_rule" "rdp_from_private_networks" {
  name                        = "Allow-RDP-From-VNet"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "3389"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "*"
  resource_group_name         = data.azurerm_resource_group.target.name
  network_security_group_name = azurerm_network_security_group.vm.name
}

resource "azurerm_network_security_rule" "sql_from_private_networks" {
  name                        = "Allow-SQL-From-VNet"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "1433"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "*"
  resource_group_name         = data.azurerm_resource_group.target.name
  network_security_group_name = azurerm_network_security_group.vm.name
}

resource "azurerm_network_security_rule" "deny_other_inbound" {
  name                        = "Deny-Other-Inbound"
  priority                    = 4095
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = data.azurerm_resource_group.target.name
  network_security_group_name = azurerm_network_security_group.vm.name
}

resource "azurerm_network_interface" "vm" {
  name                = "${local.name_prefix}-nic"
  location            = data.azurerm_resource_group.target.location
  resource_group_name = data.azurerm_resource_group.target.name
  tags                = var.tags

  ip_configuration {
    name                          = "primary"
    subnet_id                     = azurerm_subnet.vm.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_network_interface_security_group_association" "vm" {
  network_interface_id      = azurerm_network_interface.vm.id
  network_security_group_id = azurerm_network_security_group.vm.id
}

resource "azurerm_windows_virtual_machine" "vm" {
  name                = var.vm_name
  computer_name       = substr(replace(var.vm_name, "-", ""), 0, 15)
  location            = data.azurerm_resource_group.target.location
  resource_group_name = data.azurerm_resource_group.target.name
  size                = var.vm_size
  admin_username      = var.admin_username
  admin_password      = var.admin_password
  network_interface_ids = [
    azurerm_network_interface.vm.id,
  ]

  secure_boot_enabled = true
  vtpm_enabled        = true

  os_disk {
    name                 = "${local.name_prefix}-os"
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
    disk_size_gb         = 128
  }

  source_image_reference {
    publisher = var.windows_image_publisher
    offer     = var.windows_image_offer
    sku       = var.windows_image_sku
    version   = var.windows_image_version
  }

  boot_diagnostics {}
  tags = var.tags

  depends_on = [
    azurerm_network_interface_security_group_association.vm,
    azurerm_subnet_nat_gateway_association.vm,
  ]
}

resource "azurerm_virtual_machine_run_command" "install_sql" {
  name               = "install-sql-express-2022"
  location           = data.azurerm_resource_group.target.location
  virtual_machine_id = azurerm_windows_virtual_machine.vm.id

  source {
    script = local.sql_install_script
  }
}
