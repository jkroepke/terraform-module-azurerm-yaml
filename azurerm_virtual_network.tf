locals {
  virtual_networks_yaml = [for file in fileset("", "${var.yaml_root}/virtual_network/*.yaml") : yamldecode(file(file))]
  virtual_networks      = { for yaml in local.virtual_networks_yaml : yaml.name => yaml }
  virtual_networks_subnets = [
    for yaml in local.virtual_networks_yaml : [
      for name, subresource in try(yaml.subnets, {}) : merge({
        name                 = name
        virtual_network_name = azurerm_virtual_network.this[yaml.name].name
        resource_group_name  = azurerm_virtual_network.this[yaml.name].resource_group_name
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
    for subnet in flatten(local.virtual_networks_subnets) : "${subnet.virtual_network_name}|${subnet.name}" => subnet
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
    "${subnet.virtual_network_name}|${subnet.name}|${subnet.route_table_id}" => subnet
    if try(subnet.route_table_id, subnet.route_table, null) != null
  }

  route_table_id = (
    can(each.value.route_table_id)
    ? (
      startswith(each.value.route_table_id, "/")
      ? each.value.route_table_id
      : (
        contains(keys(azurerm_network_security_group.this), each.value.route_table_id)
        ? azurerm_route_table.this[each.value.route_table_id].id
        : data.azurerm_route_table.subnet_route_table_association[each.value.route_table_id].id
      )
    )
    : null
  )

  subnet_id = azurerm_subnet.this["${each.value.virtual_network_name}|${each.value.name}"].id
}

data "azurerm_route_table" "subnet_route_table_association" {
  for_each = {
    for subnet in flatten(local.virtual_networks_subnets) : "${subnet.resource_group_name}/${subnet.route_table_id}" => subnet
    if(can(subnet.route_table_id) && !startswith(try(subnet.route_table, ""), "/") && !contains(keys(azurerm_route_table.this), try(subnet.route_table, "")))
  }

  name                = each.value.route_table_id
  resource_group_name = each.value.resource_group_name
}


output "azurerm_virtual_network" {
  value = azurerm_virtual_network.this
}

output "azurerm_subnet" {
  value = azurerm_subnet.this
}
