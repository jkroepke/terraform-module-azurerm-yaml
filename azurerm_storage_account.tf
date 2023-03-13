locals {
  storage_accounts_yaml = [for file in fileset("", "${var.yaml_root}/storage_account/*.yaml") : yamldecode(file(file))]
  storage_accounts      = { for yaml in local.storage_accounts_yaml : "${yaml.resource_group_name}/${yaml.name}" => yaml }
  storage_accounts_iam = { for role_assignment in flatten([
    for name, options in local.storage_accounts : [
      for role, role_assignments in try(options.iam, {}) : [
        for role_assignment_name, role_assignment in role_assignments : merge({
          _                    = name
          scope                = azurerm_storage_account.this[name].id
          role_definition_name = role
        }, role_assignment)
      ]
    ]
  ]) : "${role_assignment._}|${role_assignment.role_definition_name}|${role_assignment.principal_id}" => role_assignment }
  storage_accounts_private_endpoints = { for private_endpoints in flatten([
    for name, options in local.storage_accounts : [
      for subname, subresource in try(options.private_endpoints, {}) : merge({
        _                              = name
        name                           = subname
        resource_group_name            = subresource.resource_group_name
        private_connection_resource_id = azurerm_storage_account.this[name].id
      }, subresource)
    ]
  ]) : "${private_endpoints._}/${private_endpoints.name}" => private_endpoints }
}

resource "azurerm_private_endpoint" "azurerm_storage_account" {
  for_each = local.storage_accounts_private_endpoints

  name = each.value.name
  subnet_id = (contains(keys(azurerm_subnet.this), each.value.subnet_id)
    ? azurerm_subnet.this[each.value.subnet_id].id
    : each.value.subnet_id
  )
  custom_network_interface_name = try(each.value.custom_network_interface_name, null)

  private_service_connection {
    name                           = each.value.private_service_connection.name
    is_manual_connection           = try(each.value.private_service_connection.is_manual_connection, null)
    private_connection_resource_id = each.value.private_connection_resource_id
  }

  dynamic "private_dns_zone_group" {
    for_each = contains(keys(each.value), "private_dns_zone_group") ? { 1 : each.value.private_dns_zone_group } : {}
    content {
      name = private_dns_zone_group.value.name
      private_dns_zone_ids = [
        for id in private_dns_zone_group.value.private_dns_zone_ids : (
          contains(keys(azurerm_private_dns_zone.this), id)
          ? azurerm_private_dns_zone.this[id].id
          : id
        )
      ]
    }
  }

  dynamic "ip_configuration" {
    for_each = contains(keys(each.value), "ip_configuration") ? { 1 : each.value.ip_configuration } : {}
    content {
      name               = ip_configuration.value.name
      private_ip_address = ip_configuration.value.private_ip_address
      subresource_name   = try(ip_configuration.value.subresource_name, null)
      member_name        = try(ip_configuration.value.member_name, null)
    }
  }

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

resource "azurerm_role_assignment" "azurerm_storage_account" {
  for_each = local.windows_virtual_machines_iam

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
