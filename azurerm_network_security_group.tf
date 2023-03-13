locals {
  network_security_groups_yaml = [for file in fileset("", "${var.yaml_root}/network_security_group/*.yaml") : yamldecode(file(file))]
  network_security_groups      = { for yaml in local.network_security_groups_yaml : "${yaml.resource_group_name}/${yaml.name}" => yaml }
  network_security_groups_iam = { for role_assignment in flatten([
    for name, options in local.network_security_groups : [
      for role, role_assignments in try(options.iam, {}) : [
        for role_assignment_name, role_assignment in role_assignments : merge({
          _                    = name
          scope                = azurerm_network_security_group.this[name].id
          role_definition_name = role
        }, role_assignment)
      ]
    ]
  ]) : "${role_assignment._}|${role_assignment.role_definition_name}|${role_assignment.principal_id}" => role_assignment }
  network_security_groups_rules = { for rule in flatten([
    for name, options in local.network_security_groups : [
      for subname, subresource in try(options.rules, {}) : merge({
        _                           = name
        name                        = subname
        network_security_group_name = azurerm_network_security_group.this[name].name
        resource_group_name         = azurerm_network_security_group.this[name].resource_group_name
      }, subresource)
    ]
  ]) : "${rule._}/${rule.name}" => rule }
}

resource "azurerm_network_security_group" "this" {
  for_each = local.network_security_groups

  name = each.value.name

  resource_group_name = contains(keys(azurerm_resource_group.this), each.value.resource_group_name) ? azurerm_resource_group.this[each.value.resource_group_name].name : each.value.resource_group_name
  location = try(each.value.location, (
    contains(keys(azurerm_resource_group.this), each.value.resource_group_name)
    ? azurerm_resource_group.this[each.value.resource_group_name].location
    : var.default_location
  ))
  tags = merge(try(each.value.tags, {}), var.default_tags)

  lifecycle {
    ignore_changes = [security_rule]
  }
}

resource "azurerm_network_security_rule" "this" {
  for_each = local.network_security_groups_rules

  name        = each.value.name
  description = try(each.value.description, null)

  resource_group_name         = each.value.resource_group_name
  network_security_group_name = each.value.network_security_group_name

  access                                     = each.value.access
  direction                                  = each.value.direction
  priority                                   = each.value.priority
  protocol                                   = each.value.protocol
  source_port_range                          = try(each.value.source_port_range, null)
  source_port_ranges                         = try(each.value.source_port_ranges, null)
  destination_port_range                     = try(each.value.destination_port_range, null)
  destination_port_ranges                    = try(each.value.destination_port_ranges, null)
  source_address_prefix                      = try(each.value.source_address_prefix, null)
  source_address_prefixes                    = try(each.value.source_address_prefixes, null)
  destination_address_prefix                 = try(each.value.destination_address_prefix, null)
  destination_address_prefixes               = try(each.value.destination_address_prefixes, null)
  source_application_security_group_ids      = try(each.value.source_application_security_group_ids, null)
  destination_application_security_group_ids = try(each.value.destination_application_security_group_ids, null)
}

resource "azurerm_role_assignment" "azurerm_network_security_group" {
  for_each = local.network_security_groups_iam

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
