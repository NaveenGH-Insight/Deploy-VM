variable "subscription_id" {
  description = "Azure subscription ID for deployment."
  type        = string
}

variable "resource_group_name" {
  description = "Existing resource group where resources will be created."
  type        = string
}

variable "vm_name" {
  description = "Base name for the Windows VM and related resources."
  type        = string

  validation {
    condition     = length(var.vm_name) <= 64 && can(regex("^[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?$", var.vm_name))
    error_message = "vm_name must be 1-64 characters, contain only letters, digits, and hyphens, and start/end with a letter or digit."
  }
}

variable "vm_size" {
  description = "Azure VM size."
  type        = string
}

variable "os_disk_storage_account_type" {
  description = "Managed OS disk storage SKU supported in the target region."
  type        = string
}

variable "os_disk_size_gb" {
  description = "Managed OS disk size in GiB; must meet the selected image's minimum."
  type        = number
}

variable "admin_username" {
  description = "Local Windows administrator account name."
  type        = string
}

variable "admin_password" {
  description = "Strong local Windows administrator password. Supply through a CI secret as TF_VAR_admin_password."
  type        = string
  sensitive   = true
  nullable    = false

  validation {
    condition     = length(var.admin_password) >= 14 && can(regex("[A-Z]", var.admin_password)) && can(regex("[a-z]", var.admin_password)) && can(regex("[0-9]", var.admin_password)) && can(regex("[^A-Za-z0-9]", var.admin_password))
    error_message = "Use at least 14 characters with uppercase, lowercase, numeric, and special characters."
  }
}

variable "vnet_address_space" {
  description = "Non-overlapping private address space for the new VNet."
  type        = list(string)
}

variable "subnet_address_prefix" {
  description = "Subnet prefix for the Windows VM."
  type        = string
}

variable "vpn_client_address_prefixes" {
  description = "Optional VPN client CIDRs to allow through Windows Defender Firewall; the NSG already allows Azure's VirtualNetwork service tag."
  type        = list(string)
}

variable "windows_image_publisher" {
  description = "Marketplace publisher for the Windows client image."
  type        = string
  default     = "MicrosoftWindowsDesktop"
}

variable "windows_image_offer" {
  description = "Windows client image offer."
  type        = string
  default     = "Windows-11"
}

variable "windows_image_sku" {
  description = "Windows 11 Marketplace SKU available to the target subscription and region."
  type        = string
}

variable "windows_image_version" {
  description = "Marketplace image version; latest selects the current published version."
  type        = string
}

variable "sql_media_url" {
  description = "Microsoft SQL Server 2022 Express media URL."
  type        = string
  default     = "https://download.microsoft.com/download/3/8/d/38de7036-2433-4207-8eae-06e247e17b25/SQLEXPR_x64_ENU.exe"
}

variable "sql_tcp_port" {
  description = "Static TCP port for the SQL Server Express instance."
  type        = number

  validation {
    condition     = var.sql_tcp_port >= 1 && var.sql_tcp_port <= 65535
    error_message = "sql_tcp_port must be between 1 and 65535."
  }
}

variable "tags" {
  description = "Environment-specific tags applied to created resources."
  type        = map(string)
}
