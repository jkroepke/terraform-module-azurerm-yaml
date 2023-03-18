resource "azurerm_virtual_network" "this" {
  for_each = local.virtual_networks

  address_space           = each.value.address_space
  bgp_community           = try(each.value.bgp_community, null)
  dns_servers             = try(each.value.dns_servers, null)
  edge_zone               = try(each.value.edge_zone, null)
  flow_timeout_in_minutes = try(each.value.flow_timeout_in_minutes, null)
  location = try(each.value.location, (
    contains(keys(azurerm_resource_group.this), each.value.resource_group_name)
    ? azurerm_resource_group.this[each.value.resource_group_name].location
    : var.default_location
  ))
  name                = each.value.name
  resource_group_name = contains(keys(azurerm_resource_group.this), each.value.resource_group_name) ? azurerm_resource_group.this[each.value.resource_group_name].name : each.value.resource_group_name
  subnet              = try(each.value.subnet, null)
  tags                = merge(try(each.value.tags, {}), var.default_tags)

  dynamic "ddos_protection_plan" {
    for_each = contains(keys(each.value), "ddos_protection_plan") ? { 1 : each.value.ddos_protection_plan } : {}
    content {
      enable = ddos_protection_plan.value.enable
      id     = ddos_protection_plan.value.id
    }
  }
}

resource "azurerm_subnet" "this" {
  for_each = {
    for subnet in flatten(local.virtual_networks_subnets) : "${subnet.resource_group_name}/${subnet.virtual_network_name}/${subnet.name}" => subnet
  }

  address_prefixes                               = each.value.address_prefixes
  enforce_private_link_endpoint_network_policies = try(each.value.enforce_private_link_endpoint_network_policies, null)
  enforce_private_link_service_network_policies  = try(each.value.enforce_private_link_service_network_policies, null)
  name                                           = each.value.name
  private_endpoint_network_policies_enabled      = try(each.value.private_endpoint_network_policies_enabled, null)
  private_link_service_network_policies_enabled  = try(each.value.private_link_service_network_policies_enabled, null)
  resource_group_name                            = contains(keys(azurerm_resource_group.this), each.value.resource_group_name) ? azurerm_resource_group.this[each.value.resource_group_name].name : each.value.resource_group_name
  service_endpoint_policy_ids                    = try(each.value.service_endpoint_policy_ids, null)
  service_endpoints                              = try(each.value.service_endpoints, null)
  virtual_network_name                           = each.value.virtual_network_name

  dynamic "delegation" {
    for_each = contains(keys(each.value), "delegation") ? each.value.delegation : {}
    content {
      name = delegation.key

      dynamic "service_delegation" {
        for_each = contains(keys(delegation.value), "service_delegation") ? { 1 : delegation.value.service_delegation } : {}
        content {
          actions = try(service_delegation.value.actions, null)
          name    = service_delegation.value.name
        }
      }
    }
  }
}

