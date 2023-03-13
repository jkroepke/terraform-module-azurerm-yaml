locals {
  route_tables_yaml = [for file in fileset("", "${var.yaml_root}/route_table/*.yaml") : yamldecode(file(file))]
  route_tables      = { for yaml in local.route_tables_yaml : "${yaml.resource_group_name}/${yaml.name}" => yaml }
  route_tables_iam = { for role_assignment in flatten([
    for name, options in local.route_tables : [
      for role, role_assignments in try(options.iam, {}) : [
        for role_assignment_name, role_assignment in role_assignments : merge({
          route_table_name     = azurerm_route_table.this[name].name
          resource_group_name  = azurerm_route_table.this[name].resource_group_name
          scope                = azurerm_route_table.this[name].id
          role_definition_name = role
        }, role_assignment)
      ]
    ]
  ]) : "${role_assignment.resource_group_name}/${role_assignment.route_table_name}|${role_assignment.role_definition_name}|${role_assignment.principal_id}" => role_assignment }
  route_tables_routes = [
    for name, options in local.route_tables : [
      for subname, subresource in try(options.routes, {}) : merge({
        name                = subname
        route_table_name    = azurerm_route_table.this[name].name
        resource_group_name = azurerm_route_table.this[name].resource_group_name
      }, subresource)
    ]
  ]
}

resource "azurerm_route_table" "this" {
  for_each = local.route_tables

  name                          = each.value.name
  disable_bgp_route_propagation = try(each.value.disable_bgp_route_propagation, null)

  resource_group_name = contains(keys(azurerm_resource_group.this), each.value.resource_group_name) ? azurerm_resource_group.this[each.value.resource_group_name].name : each.value.resource_group_name
  location = try(each.value.location, (
    contains(keys(azurerm_resource_group.this), each.value.resource_group_name)
    ? azurerm_resource_group.this[each.value.resource_group_name].location
    : var.default_location
  ))
  tags = merge(try(each.value.tags, {}), var.default_tags)

  lifecycle {
    ignore_changes = [route]
  }
}

resource "azurerm_route" "this" {
  for_each = {
    for route in flatten(local.route_tables_routes) : "${route.resource_group_name}/${route.route_table_name}/${route.name}" => route
  }

  name                   = each.value.name
  resource_group_name    = each.value.resource_group_name
  route_table_name       = each.value.route_table_name
  address_prefix         = each.value.address_prefix
  next_hop_type          = each.value.next_hop_type
  next_hop_in_ip_address = try(each.value.next_hop_in_ip_address, null)
}

resource "azurerm_role_assignment" "azurerm_route_table" {
  for_each = local.route_tables_iam

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
