locals {
  public_ips_yaml = [for file in fileset("", "${var.yaml_root}/public_ip/*.yaml") : yamldecode(file(file))]
  public_ips      = { for yaml in local.public_ips_yaml : "${yaml.resource_group_name}/${yaml.name}" => yaml }
  public_ips_iam = { for role_assignment in flatten([
    for name, options in local.public_ips : [
      for role, role_assignments in try(options.iam, {}) : [
        for role_assignment_name, role_assignment in role_assignments : merge({
          _                    = name
          scope                = azurerm_user_assigned_identity.this[name].id
          role_definition_name = role
        }, role_assignment)
      ]
    ]
  ]) : "${role_assignment._}|${role_assignment.role_definition_name}|${role_assignment.principal_id}" => role_assignment }
}

resource "azurerm_role_assignment" "public_ip" {
  for_each = local.public_ips_iam

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
