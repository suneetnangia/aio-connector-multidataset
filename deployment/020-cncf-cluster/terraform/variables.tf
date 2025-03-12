/*
 * Optional Variables
 */

variable "vm_username" {
  type        = string
  description = <<-EOF
    Username used for the host VM that will be given kube-config settings on setup.
    (Otherwise, 'resource_prefix' if it exists as a user)
EOF
  default     = null
}

variable "custom_locations_oid" {
  type        = string
  description = <<-EOF
    The object id of the Custom Locations Entra ID application for your tenant.
    If none is provided, the script will attempt to retrieve this requiring 'Application.Read.All' or 'Directory.Read.All' permissions.

    ```sh
    az ad sp show --id bc313c14-388c-4e7d-a58e-70017303ee3b --query id -o tsv
    ```
EOF
  default     = null
}

variable "enable_arc_auto_upgrade" {
  type        = bool
  description = "Enable or disable auto-upgrades of Arc agents. (Otherwise, 'false' for 'env=prod' else 'true' for all other envs)."
  default     = null
}

variable "should_add_current_user_cluster_admin" {
  type        = bool
  description = "Gives the current logged in user cluster-admin permissions with the new cluster."
  default     = true
}

variable "cluster_admin_oid" {
  type        = string
  description = "The Object ID that will be given cluster-admin permissions with the new cluster. (Otherwise, current logged in user if 'should_add_current_user_cluster_admin=true')"
  default     = null
}

variable "should_output_script" {
  type        = bool
  description = "Should write out the script to a file. (Specified by 'var.script_output_filepath')"
  default     = false
}

variable "script_output_filepath" {
  type        = string
  description = "The location of where to write out the script file. (Otherwise, '{path.root}/out')"
  default     = null
}

variable "should_deploy_script_to_vm" {
  type        = bool
  description = "Should deploy the script to an Azure VM assuming that it exists."
  default     = true
}
