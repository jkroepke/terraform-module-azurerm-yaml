locals {
  key_vaults_yaml = [for file in fileset("", "${var.yaml_root}/key_vault/*.yaml") : yamldecode(file(file))]
  key_vaults = { for yaml in local.key_vaults_yaml : "${yaml.resource_group_name}/${yaml.name}" => merge({
    tenant_id = data.azurerm_client_config.current.tenant_id
  }, yaml) }
  key_vaults_access_policies = { for access_policy in flatten([
    for name, options in local.user_assigned_identities : [
      for subname, subresource in try(options.access_policies, {}) : merge({
        _                   = name
        name                = subname
        key_vault_id        = azurerm_key_vault.this[name].id
        resource_group_name = options.resource_group_name
      }, subresource)
    ]
  ]) : "${access_policy._}/${access_policy.name}" => access_policy }
  key_vaults_iam = { for role_assignment in flatten([
    for name, options in local.key_vaults : [
      for role, role_assignments in try(options.iam, {}) : [
        for role_assignment_name, role_assignment in role_assignments : merge({
          _                    = name
          scope                = azurerm_key_vault.this[name].id
          role_definition_name = role
        }, role_assignment)
      ]
    ]
  ]) : "${role_assignment._}|${role_assignment.role_definition_name}|${role_assignment.principal_id}" => role_assignment }
}

resource "azurerm_role_assignment" "azurerm_key_vault" {
  for_each = local.key_vaults_iam

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
