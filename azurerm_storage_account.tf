locals {
  storage_accounts_yaml = [for file in fileset("", "${var.yaml_root}/storage_account/*.yaml") : yamldecode(file(file))]
  storage_accounts      = { for yaml in local.storage_accounts_yaml : "${yaml.name}/${yaml.resource_group_name}" => yaml }
  storage_accounts_iam = { for role_assignment in flatten([
    for name, options in local.storage_accounts : [
      for role, role_assignments in try(options.iam, {}) : [
        for role_assignment_name, role_assignment in role_assignments : merge({
          storage_account_name = azurerm_storage_account.this[name].name
          resource_group_name  = azurerm_storage_account.this[name].resource_group_name
          scope                = azurerm_storage_account.this[name].id
          role_definition_name = role
        }, role_assignment)
      ]
    ]
  ]) : "${role_assignment.resource_group_name}/${role_assignment.storage_account_name}|${role_assignment.role_definition_name}|${role_assignment.principal_id}" => role_assignment }
  storage_accounts_virtual_network_links = [
    for name, options in local.storage_accounts : [
      for subname, subresource in try(options.virtual_network_links, {}) : merge({
        name                 = subname
        storage_account_name = azurerm_storage_account.this[name].name
        resource_group_name  = azurerm_storage_account.this[name].resource_group_name
      }, subresource)
    ]
  ]
}

resource "azurerm_role_assignment" "azurerm_storage_account" {
  for_each = local.windows_virtual_machines_iam

  scope                                  = each.value.scope
  role_definition_name                   = each.value.role_definition_name
  principal_id                           = each.value.principal_id
  condition                              = try(each.value.condition, null)
  condition_version                      = try(each.value.condition_version, null)
  delegated_managed_identity_resource_id = try(each.value.delegated_managed_identity_resource_id, null)
  skip_service_principal_aad_check       = try(each.value.skip_service_principal_aad_check, null)
}

output "azurerm_storage_account" {
  value = azurerm_storage_account.this
}
