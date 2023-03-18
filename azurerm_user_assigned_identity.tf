locals {
  user_assigned_identities_yaml = [for file in fileset("", "${var.yaml_root}/user_assigned_identity/*.yaml") : yamldecode(file(file))]
  user_assigned_identities      = { for yaml in local.user_assigned_identities_yaml : "${yaml.resource_group_name}/${yaml.name}" => yaml }
  user_assigned_identities_iam = { for role_assignment in flatten([
    for name, options in local.user_assigned_identities : [
      for role, role_assignments in try(options.iam, {}) : [
        for role_assignment_name, role_assignment in role_assignments : merge({
          _                    = name
          scope                = azurerm_user_assigned_identity.this[name].id
          role_definition_name = role
        }, role_assignment)
      ]
    ]
  ]) : "${role_assignment._}|${role_assignment.role_definition_name}|${role_assignment.principal_id}" => role_assignment }

  user_assigned_identities_federated_identity_credentials = { for cred in flatten([
    for name, options in local.user_assigned_identities : [
      for subname, subresource in try(options.federated_identity_credentials, {}) : merge({
        _                   = name
        name                = subname
        parent_id           = azurerm_user_assigned_identity.this[name].id
        resource_group_name = azurerm_user_assigned_identity.this[name].resource_group_name
      }, subresource)
    ]
  ]) : "${cred._}/${cred.name}" => cred }
}

resource "azurerm_user_assigned_identity" "this" {
  for_each = local.user_assigned_identities

  name = each.value.name
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

resource "azurerm_federated_identity_credential" "this" {
  for_each = local.user_assigned_identities_federated_identity_credentials

  name                = each.value.name
  resource_group_name = each.value.resource_group_name
  audience            = each.value.audience
  issuer              = each.value.issuer
  parent_id           = each.value.parent_id
  subject             = each.value.subject
}

resource "azurerm_role_assignment" "azurerm_user_assigned_identity" {
  for_each = local.user_assigned_identities_iam

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
