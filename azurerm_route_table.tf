locals {
  route_tables_yaml = [for file in fileset("", "${var.yaml_root}/route_table/*.yaml") : yamldecode(file(file))]
  route_tables      = { for yaml in local.route_tables_yaml : "${yaml.resource_group_name}/${yaml.name}" => yaml }
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
  location            = try(each.value.location, var.default_location)
  tags                = merge(try(each.value.tags, {}), var.default_tags)

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

output "azurerm_route_table" {
  value = azurerm_route_table.this
}
