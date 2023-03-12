locals {
  virtual_networks_yaml = [for file in fileset("", "${var.yaml_root}/virtual_network/*.yaml") : yamldecode(file(file))]
  virtual_networks      = { for yaml in local.virtual_networks_yaml : "${yaml.resource_group_name}/${yaml.name}" => yaml }
  virtual_networks_subnets = [
    for name, options in local.virtual_networks : [
      for subname, subresource in try(options.subnets, {}) : merge({
        name                 = subname
        virtual_network_name = azurerm_virtual_network.this[name].name
        resource_group_name  = azurerm_virtual_network.this[name].resource_group_name
      }, subresource)
    ]
  ]
}

resource "azurerm_virtual_network" "this" {
  for_each = local.virtual_networks

  name          = each.value.name
  address_space = each.value.address_space
  dns_servers   = try(each.value.dns_servers, null)

  resource_group_name = (
    contains(keys(azurerm_resource_group.this), each.value.resource_group_name)
    ? azurerm_resource_group.this[each.value.resource_group_name].name
    : each.value.resource_group_name
  )

  location = try(each.value.location, var.default_location)
  tags     = merge(try(each.value.tags, {}), var.default_tags)
}

resource "azurerm_subnet" "this" {
  for_each = {
    for subnet in flatten(local.virtual_networks_subnets) : "${subnet.resource_group_name}/${subnet.virtual_network_name}/${subnet.name}" => subnet
  }

  address_prefixes     = each.value.address_prefixes
  name                 = each.value.name
  resource_group_name  = each.value.resource_group_name
  virtual_network_name = each.value.virtual_network_name

  enforce_private_link_endpoint_network_policies = try(each.value.enforce_private_link_endpoint_network_policies, null)
  enforce_private_link_service_network_policies  = try(each.value.enforce_private_link_service_network_policies, null)
  private_endpoint_network_policies_enabled      = try(each.value.private_endpoint_network_policies_enabled, null)
  private_link_service_network_policies_enabled  = try(each.value.private_link_service_network_policies_enabled, null)

  dynamic "delegation" {
    for_each = try(each.value.delegations, {})

    content {
      name = delegation.key

      dynamic "service_delegation" {
        for_each = try(delegation.value.services, {})

        content {
          name    = service_delegation.key
          actions = service_delegation.value.actions
        }
      }
    }
  }
}

resource "azurerm_subnet_route_table_association" "this" {
  for_each = {
    for subnet in flatten(local.virtual_networks_subnets) :
    "${subnet.resource_group_name}/${subnet.virtual_network_name}/${subnet.name}/${subnet.route_table_id}" => subnet
    if try(subnet.route_table_id, null) != null
  }

  route_table_id = (
    can(each.value.route_table_id)
    ? (
      can(azurerm_route_table.this[each.value.route_table_id].id)
      ? azurerm_route_table.this[each.value.route_table_id].id
      : (
        can(data.azurerm_route_table.subnet_route_table_association[each.value.route_table_id].id)
        ? data.azurerm_route_table.subnet_route_table_association[each.value.route_table_id].id
        : each.value.route_table_id
      )
    )
    : null
  )

  subnet_id = azurerm_subnet.this["${each.value.resource_group_name}/${each.value.virtual_network_name}/${each.value.name}"].id
}

data "azurerm_route_table" "subnet_route_table_association" {
  for_each = {
    for subnet in flatten(local.virtual_networks_subnets) : subnet.route_table_id => subnet
    if(can(subnet.route_table_id) && !startswith(try(subnet.route_table_id, ""), "/") && !contains(keys(azurerm_route_table.this), try(subnet.route_table_id, "")))
  }

  name                = split(each.value.route_table_id, "/")[1]
  resource_group_name = split(each.value.route_table_id, "/")[0]
}


output "azurerm_virtual_network" {
  value = azurerm_virtual_network.this
}

output "azurerm_subnet" {
  value = azurerm_subnet.this
}
