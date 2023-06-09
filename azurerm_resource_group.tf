locals {
  resource_groups_yaml = [for file in fileset("", "${var.yaml_root}/resource_group/*.yaml") : yamldecode(file(file))]
  resource_groups      = { for yaml in local.resource_groups_yaml : yaml.name => yaml }
  resource_groups_iam = { for role_assignment in flatten([
    for name, options in local.resource_groups : [
      for role, role_assignments in try(options.iam, {}) : [
        for role_assignment_name, role_assignment in role_assignments : merge({
          _                    = name
          scope                = azurerm_resource_group.this[name].id
          role_definition_name = role
        }, role_assignment)
      ]
    ]
  ]) : "${role_assignment._}|${role_assignment.role_definition_name}|${role_assignment.principal_id}" => role_assignment }
}

resource "azurerm_resource_group" "this" {
  for_each = local.resource_groups

  name     = each.value.name
  location = try(each.value.location, var.default_location)
  tags     = merge(try(each.value.tags, {}), var.default_tags)
}

resource "azurerm_role_assignment" "azurerm_resource_group" {
  for_each = local.resource_groups_iam

  scope                = each.value.scope
  role_definition_name = each.value.role_definition_name
  principal_id = (
    contains(keys(azurerm_user_assigned_identity.this), each.value.principal_id)
    ? azurerm_user_assigned_identity.this[each.value.principal_id].principal_id
    : (
      contains(keys(azurerm_windows_virtual_machine.this), each.value.principal_id)
      ? azurerm_windows_virtual_machine.this[each.value.principal_id].identity.0.principal_id
      : each.value.principal_id
    )
  )
  condition                              = try(each.value.condition, null)
  condition_version                      = try(each.value.condition_version, null)
  delegated_managed_identity_resource_id = try(each.value.delegated_managed_identity_resource_id, null)
  skip_service_principal_aad_check       = try(each.value.skip_service_principal_aad_check, null)
}
