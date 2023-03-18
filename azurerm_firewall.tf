locals {
  firewalls_yaml = [for file in fileset("", "${var.yaml_root}/firewall/*.yaml") : yamldecode(file(file))]
  firewalls = { for yaml in local.firewalls_yaml : "${yaml.resource_group_name}/${yaml.name}" => yaml }
  firewalls_policies = { for policy in flatten([
    for name, options in local.firewalls : [merge({
      _                   = name
      resource_group_name = options.resource_group_name
      }, options.policy)
    ] if try(options.policy, null) != null
  ]) : "${policy._}/${policy.name}" => policy }
  firewalls_policy_rule_collection_groups = { for policy_rule_collection_group in flatten([
    for name, options in local.firewalls_policies : [
      for subname, subresource in try(options.rule_collection_groups, {}) : merge({
        _                   = name
        name                = subname
        resource_group_name = options.resource_group_name
        firewall_policy_id  = azurerm_firewall_policy.this[name].id
      }, subresource)
    ]
  ]) : "${policy_rule_collection_group._}/${policy_rule_collection_group.name}" => policy_rule_collection_group }
  firewalls_iam = { for role_assignment in flatten([
    for name, options in local.firewalls : [
      for role, role_assignments in try(options.iam, {}) : [
        for role_assignment_name, role_assignment in role_assignments : merge({
          _                    = name
          scope                = azurerm_firewall.this[name].id
          role_definition_name = role
        }, role_assignment)
      ]
    ]
  ]) : "${role_assignment._}|${role_assignment.role_definition_name}|${role_assignment.principal_id}" => role_assignment }
}

resource "azurerm_role_assignment" "azurerm_firewall" {
  for_each = local.firewalls_iam

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
