variable "location" {
  type        = string
  description = "Location for all resources in this module"
  validation {
    condition     = length(var.location) > 0
    error_message = "Location name must not be empty."
  }
}

variable "resource_group_name" {
  type        = string
  description = "The name for the resource group."

  validation {
    condition     = length(var.resource_group_name) > 0
    error_message = "Resource group name must not be empty."
  }
}

variable "storage_account" {
  type = object({
    name             = string
    tier             = string
    replication_type = string
  })
  default = {
    name             = ""
    tier             = "Standard"
    replication_type = "LRS"
  }
  description = "Storage account name, tier and replication_type for the Storage Account to be created. Defaults to a randomly generated name, \"Standard\" tier and \"LRS\" replication_type"
}

variable "environment" {
  type        = string
  description = "Environment for all resources in this module: dev, test, or prod"
}

variable "resource_prefix" {
  type        = string
  description = "Prefix for all resources in this module"
}

variable "instance" {
  type        = string
  description = "Instance identifier for naming resources: 001, 002, etc..."
}
