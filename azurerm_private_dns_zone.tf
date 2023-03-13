locals {
  private_dns_zones_yaml = [for file in fileset("", "${var.yaml_root}/private_dns_zone/*.yaml") : yamldecode(file(file))]
  private_dns_zones      = { for yaml in local.private_dns_zones_yaml : "${yaml.name}/${yaml.resource_group_name}" => yaml }
  private_dns_zones_iam = { for role_assignment in flatten([
    for name, options in local.private_dns_zones : [
      for role, role_assignments in try(options.iam, {}) : [
        for role_assignment_name, role_assignment in role_assignments : merge({
          _                    = name
          scope                = azurerm_private_dns_zone.this[name].id
          role_definition_name = role
        }, role_assignment)
      ]
    ]
  ]) : "${role_assignment._}|${role_assignment.role_definition_name}|${role_assignment.principal_id}" => role_assignment }
  private_dns_zones_virtual_network_links = [
    for name, options in local.private_dns_zones : [
      for subname, subresource in try(options.virtual_network_links, {}) : merge({
        name                  = subname
        private_dns_zone_name = azurerm_private_dns_zone.this[name].name
        resource_group_name   = azurerm_private_dns_zone.this[name].resource_group_name
      }, subresource)
    ]
  ]
}

resource "azurerm_private_dns_zone" "this" {
  for_each = local.private_dns_zones

  name = each.value.name
  resource_group_name = (
    contains(keys(azurerm_resource_group.this), each.value.resource_group_name)
    ? azurerm_resource_group.this[each.value.resource_group_name].name
    : each.value.resource_group_name
  )
  tags = merge(try(each.value.tags, {}), var.default_tags)
}

resource "azurerm_private_dns_zone_virtual_network_link" "this" {
  for_each = {
    for link in flatten(local.private_dns_zones_virtual_network_links) : "${link.resource_group_name}/${link.private_dns_zone_name}/${link.name}" => link
  }

  name                  = each.value.name
  private_dns_zone_name = each.value.private_dns_zone_name
  resource_group_name   = each.value.resource_group_name
  virtual_network_id = (
    can(azurerm_virtual_network.this[each.value.virtual_network_id].id)
    ? azurerm_virtual_network.this[each.value.virtual_network_id].id
    : (
      can(data.azurerm_virtual_network.azurerm_private_dns_zone_virtual_network_link[each.value.virtual_network_id].id)
      ? data.azurerm_virtual_network.azurerm_private_dns_zone_virtual_network_link[each.value.virtual_network_id].id
      : each.value.virtual_network_id
    )
  )
  registration_enabled = try(each.value.registration_enabled, null)

  tags = merge(try(each.value.tags, {}), var.default_tags)
}

data "azurerm_virtual_network" "azurerm_private_dns_zone_virtual_network_link" {
  for_each = toset([
    for link in flatten(local.private_dns_zones_virtual_network_links) : link.virtual_network_id
    if(!startswith(try(link.virtual_network_id, ""), "/") && !contains(keys(azurerm_virtual_network.this), link.virtual_network_id))
  ])

  name                = split("/", each.key)[1]
  resource_group_name = split("/", each.key)[0]
}

resource "azurerm_role_assignment" "azurerm_private_dns_zone" {
  for_each = local.private_dns_zones_iam

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
