variable "subscription_id" {
  description = "Azure subscription ID that contains the existing resource group."
  type        = string
  default     = "3e3f5f63-438b-4205-b50e-df27fa676994"
}

variable "resource_group_name" {
  description = "Existing resource group where the VM and network resources will be created."
  type        = string
  default     = "GenAI-Test"
}

variable "vm_name" {
  description = "Name for the Windows VM and related resources."
  type        = string
  default     = "genai-sql-win11-vm"
}

variable "vm_size" {
  description = "Azure VM size."
  type        = string
  default     = "Standard_D2s_v5"
}

variable "admin_username" {
  description = "Local Windows administrator account name."
  type        = string
  default     = "azureadmin"
}

variable "admin_password" {
  description = "Strong password for the local Windows administrator. Supply through TF_VAR_admin_password."
  type        = string
  sensitive   = true
  nullable    = false

  validation {
    condition     = length(var.admin_password) >= 14 && can(regex("[A-Z]", var.admin_password)) && can(regex("[a-z]", var.admin_password)) && can(regex("[0-9]", var.admin_password)) && can(regex("[^A-Za-z0-9]", var.admin_password))
    error_message = "Use at least 14 characters with uppercase, lowercase, numeric, and special characters."
  }
}

variable "vnet_address_space" {
  description = "Private address space for the new VNet."
  type        = list(string)
  default     = ["10.50.0.0/16"]
}

variable "subnet_address_prefix" {
  description = "Subnet prefix for the Windows VM."
  type        = string
  default     = "10.50.1.0/24"
}

variable "vpn_client_address_prefixes" {
  description = "Optional VPN client CIDRs to allow through Windows Defender Firewall; the NSG already allows Azure's VirtualNetwork service tag."
  type        = list(string)
  default     = []
}

variable "windows_image_publisher" {
  description = "Windows client image publisher."
  type        = string
  default     = "MicrosoftWindowsDesktop"
}

variable "windows_image_offer" {
  description = "Windows client image offer."
  type        = string
  default     = "Windows-11"
}

variable "windows_image_sku" {
  description = "Windows 11 Enterprise marketplace SKU; confirm it is visible to this subscription before applying."
  type        = string
  default     = "win11-25h2-ent"
}

variable "windows_image_version" {
  description = "Marketplace image version. latest keeps the image patched at deployment time."
  type        = string
  default     = "latest"
}

variable "sql_media_url" {
  description = "Version-pinned Microsoft SQL Server 2022 Express media URL."
  type        = string
  default     = "https://download.microsoft.com/download/3/8/d/38de7036-2433-4207-8eae-06e247e17b25/SQLEXPR_x64_ENU.exe"
}

variable "tags" {
  description = "Tags applied to resources created by this project."
  type        = map(string)
  default = {
    workload    = "sql-express-devtest"
    managed_by  = "terraform"
    environment = "devtest"
  }
}
