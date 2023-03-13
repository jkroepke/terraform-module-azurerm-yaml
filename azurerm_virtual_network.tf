locals {
  virtual_networks_yaml = [for file in fileset("", "${var.yaml_root}/virtual_network/*.yaml") : yamldecode(file(file))]
  virtual_networks      = { for yaml in local.virtual_networks_yaml : "${yaml.resource_group_name}/${yaml.name}" => yaml }
  virtual_networks_iam = { for role_assignment in flatten([
    for name, options in local.virtual_networks : [
      for role, role_assignments in try(options.iam, {}) : [
        for role_assignment_name, role_assignment in role_assignments : merge({
          virtual_network_name = azurerm_virtual_network.this[name].name
          resource_group_name  = azurerm_virtual_network.this[name].resource_group_name
          scope                = azurerm_virtual_network.this[name].id
          role_definition_name = role
        }, role_assignment)
      ]
    ]
  ]) : "${role_assignment.resource_group_name}/${role_assignment.virtual_network_name}|${role_assignment.role_definition_name}|${role_assignment.principal_id}" => role_assignment }
  virtual_networks_subnets = [
    for name, options in local.virtual_networks : [
      for subname, subresource in try(options.subnets, {}) : merge({
        name                 = subname
        virtual_network_name = azurerm_virtual_network.this[name].name
        resource_group_name  = azurerm_virtual_network.this[name].resource_group_name
      }, subresource)
    ]
  ]
  virtual_networks_peerings = [
    for name, options in local.virtual_networks : [
      for subname, subresource in try(options.peerings, {}) : merge({
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

  location = try(each.value.location, (
    contains(keys(azurerm_resource_group.this), each.value.resource_group_name)
    ? azurerm_resource_group.this[each.value.resource_group_name].location
    : var.default_location
  ))
  tags = merge(try(each.value.tags, {}), var.default_tags)
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
    can(azurerm_route_table.this[each.value.route_table_id].id)
    ? azurerm_route_table.this[each.value.route_table_id].id
    : (
      can(data.azurerm_route_table.subnet_route_table_association[each.value.route_table_id].id)
      ? data.azurerm_route_table.subnet_route_table_association[each.value.route_table_id].id
      : each.value.route_table_id
    )
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

resource "azurerm_virtual_network_peering" "this" {
  for_each = {
    for peering in flatten(local.virtual_networks_peerings) :
    "${peering.resource_group_name}/${peering.virtual_network_name}/${peering.name}" => peering
  }

  name                 = each.value.name
  resource_group_name  = each.value.resource_group_name
  virtual_network_name = each.value.virtual_network_name

  remote_virtual_network_id = (
    can(azurerm_virtual_network.this[each.value.remote_virtual_network_id].id)
    ? azurerm_virtual_network.this[each.value.remote_virtual_network_id].id
    : (
      can(data.azurerm_virtual_network.azurerm_virtual_network_peering[each.value.remote_virtual_network_id].id)
      ? data.azurerm_virtual_network.azurerm_virtual_network_peering[each.value.remote_virtual_network_id].id
      : each.value.route_table_id
    )
  )

  allow_virtual_network_access = try(each.value.allow_virtual_network_access, null)
  allow_forwarded_traffic      = try(each.value.allow_forwarded_traffic, null)
  allow_gateway_transit        = try(each.value.allow_gateway_transit, null)
  use_remote_gateways          = try(each.value.use_remote_gateways, null)

  triggers = {
    remote_address_space = join(",", (
      can(azurerm_virtual_network.this[each.value.remote_virtual_network_id].address_space)
      ? azurerm_virtual_network.this[each.value.remote_virtual_network_id].address_space
      : (
        can(data.azurerm_virtual_network.azurerm_virtual_network_peering[each.value.remote_virtual_network_id].address_space)
        ? data.azurerm_virtual_network.azurerm_virtual_network_peering[each.value.remote_virtual_network_id].address_space
        : []
      )
    ))
  }
}

data "azurerm_virtual_network" "azurerm_virtual_network_peering" {
  for_each = toset([
    for subnet in flatten(local.virtual_networks_subnets) : subnet.route_table_id
    if(can(subnet.route_table_id) && !startswith(try(subnet.route_table_id, ""), "/") && !contains(keys(azurerm_route_table.this), try(subnet.route_table_id, "")))
  ])

  name                = split("/", each.key)[1]
  resource_group_name = split("/", each.key)[0]
}

resource "azurerm_role_assignment" "azurerm_virtual_network" {
  for_each = local.virtual_networks_iam

  scope                                  = each.value.scope
  role_definition_name                   = each.value.role_definition_name
  principal_id                           = each.value.principal_id
  condition                              = try(each.value.condition, null)
  condition_version                      = try(each.value.condition_version, null)
  delegated_managed_identity_resource_id = try(each.value.delegated_managed_identity_resource_id, null)
  skip_service_principal_aad_check       = try(each.value.skip_service_principal_aad_check, null)
}
