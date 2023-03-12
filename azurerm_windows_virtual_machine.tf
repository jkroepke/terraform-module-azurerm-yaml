locals {
  windows_virtual_machines_yaml = [for file in fileset("", "${var.yaml_root}/windows_virtual_machine/*.yaml") : yamldecode(file(file))]
  windows_virtual_machines      = { for yaml in local.windows_virtual_machines_yaml : "${yaml.resource_group_name}/${yaml.name}" => yaml }
  windows_virtual_machines_iam = { for role_assignment in flatten([
    for name, options in local.windows_virtual_machines : [
      for role, role_assignments in try(options.iam, {}) : [
        for role_assignment_name, role_assignment in role_assignments : merge({
          windows_virtual_machine_name = azurerm_windows_virtual_machine.this[name].name
          resource_group_name          = azurerm_windows_virtual_machine.this[name].resource_group_name
          scope                        = azurerm_windows_virtual_machine.this[name].id
          role_definition_name         = role
        }, role_assignment)
      ]
    ]
  ]) : "${role_assignment.resource_group_name}/${role_assignment.windows_virtual_machine_name}|${role_assignment.role_definition_name}|${role_assignment.principal_id}" => role_assignment }
  windows_virtual_machines_passwords = {
    for name, options in local.windows_virtual_machines : name => null
    if !contains(keys(options), "admin_password")
  }
  windows_virtual_machines_network_interface = { for nic in flatten([
    for name, options in local.windows_virtual_machines : [
      for subname, subresource in try(options.network_interfaces, {}) : merge({
        name                = subname
        resource_group_name = options.resource_group_name
      }, subresource)
    ]
  ]) : "${nic.resource_group_name}/${nic.name}" => nic }

  windows_virtual_machines_data_disks = [
    for name, options in local.windows_virtual_machines : [
      for subname, subresource in try(options.virtual_network_links, {}) : merge({
        name                         = subname
        windows_virtual_machine_name = azurerm_windows_virtual_machine.this[name].name
        resource_group_name          = azurerm_windows_virtual_machine.this[name].resource_group_name
      }, subresource)
    ]
  ]
}

resource "azurerm_role_assignment" "azurerm_windows_virtual_machine" {
  for_each = local.windows_virtual_machines_iam

  scope                                  = each.value.scope
  role_definition_name                   = each.value.role_definition_name
  principal_id                           = each.value.principal_id
  condition                              = try(each.value.condition, null)
  condition_version                      = try(each.value.condition_version, null)
  delegated_managed_identity_resource_id = try(each.value.delegated_managed_identity_resource_id, null)
  skip_service_principal_aad_check       = try(each.value.skip_service_principal_aad_check, null)
}

output "azurerm_windows_virtual_machine" {
  value = azurerm_windows_virtual_machine.this
}
