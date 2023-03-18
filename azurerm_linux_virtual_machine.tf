locals {
  linux_virtual_machines_yaml = [for file in fileset("", "${var.yaml_root}/linux_virtual_machine/*.yaml") : yamldecode(file(file))]
  linux_virtual_machines      = { for yaml in local.linux_virtual_machines_yaml : "${yaml.resource_group_name}/${yaml.name}" => yaml }
  linux_virtual_machines_iam = {
    for role_assignment in flatten([
      for name, options in local.linux_virtual_machines : [
        for role, role_assignments in try(options.iam, {}) : [
          for role_assignment_name, role_assignment in role_assignments : merge({
            _                    = name
            scope                = azurerm_linux_virtual_machine.this[name].id
            role_definition_name = role
          }, role_assignment)
        ]
      ]
    ]) : "${role_assignment._}|${role_assignment.role_definition_name}|${role_assignment.principal_id}" => role_assignment
  }
  linux_virtual_machines_passwords = {
    for name, options in local.linux_virtual_machines : name => null
    if(try(options.disable_password_authentication, true) == false && !contains(keys(options), "admin_password"))
  }
  linux_virtual_machines_network_interface = {
    for nic in flatten([
      for name, options in local.linux_virtual_machines : [
        for subname, subresource in try(options.network_interfaces, {}) : merge(subresource, {
          name                = subname
          resource_group_name = options.resource_group_name
          tags                = merge(try(options.tags, {}), try(subresource.tags, {}))
        })
      ]
    ]) : "${nic.resource_group_name}/${nic.name}" => nic
  }
  linux_virtual_machines_network_extension = {
    for extension in flatten([
      for name, options in local.linux_virtual_machines : [
        for subname, subresource in try(options.extensions, {}) : merge(subresource, {
          _                  = name
          name               = subname
          virtual_machine_id = azurerm_linux_virtual_machine.this[name].id
          tags               = merge(try(options.tags, {}), try(subresource.tags, {}))
        })
      ]
    ]) : "${extension._}/${extension.name}" => extension
  }

  linux_virtual_machines_data_disks = [
    for name, options in local.linux_virtual_machines : [
      for subname, subresource in try(options.virtual_network_links, {}) : merge(subresource, {
        name                       = subname
        linux_virtual_machine_name = azurerm_linux_virtual_machine.this[name].name
        resource_group_name        = azurerm_linux_virtual_machine.this[name].resource_group_name
        tags                       = merge(try(options.tags, {}), try(subresource.tags, {}))
      })
    ]
  ]
}

resource "azurerm_virtual_machine_extension" "azurerm_linux_virtual_machine" {
  for_each = local.linux_virtual_machines_network_extension

  name                 = each.value.name
  virtual_machine_id   = each.value.virtual_machine_id
  publisher            = each.value.publisher
  type                 = each.value.type
  type_handler_version = each.value.type_handler_version

  auto_upgrade_minor_version  = try(each.value.auto_upgrade_minor_version, null)
  automatic_upgrade_enabled   = try(each.value.automatic_upgrade_enabled, null)
  failure_suppression_enabled = try(each.value.failure_suppression_enabled, null)

  settings = (contains(keys(each.value), "settings")
    ? jsonencode(each.value.settings)
    : null
  )
  protected_settings = (contains(keys(each.value), "protected_settings")
    ? jsonencode(each.value.protected_settings)
    : null
  )

  dynamic "protected_settings_from_key_vault" {
    for_each = contains(keys(each.value), "protected_settings_from_key_vault") ? each.value.protected_settings_from_key_vault : {}
    content {
      secret_url = protected_settings_from_key_vault.value.secret_url
      source_vault_id = (
        contains(keys(azurerm_key_vault.this), protected_settings_from_key_vault.value.source_vault_id)
        ? azurerm_key_vault.this[protected_settings_from_key_vault.value.source_vault_id].id
        : protected_settings_from_key_vault.value.source_vault_id
      )
    }
  }

  tags = merge(try(each.value.tags, {}), var.default_tags)
}

resource "azurerm_role_assignment" "azurerm_linux_virtual_machine" {
  for_each = local.linux_virtual_machines_iam

  scope                = each.value.scope
  role_definition_name = each.value.role_definition_name
  principal_id = (
    contains(keys(azurerm_user_assigned_identity.this), each.value.principal_id)
    ? azurerm_user_assigned_identity.this[each.value.principal_id].principal_id
    : (
      contains(keys(azurerm_linux_virtual_machine.this), each.value.principal_id)
      ? azurerm_linux_virtual_machine.this[each.value.principal_id].identity.0.principal_id
      : each.value.principal_id
    )
  )
  condition                              = try(each.value.condition, null)
  condition_version                      = try(each.value.condition_version, null)
  delegated_managed_identity_resource_id = try(each.value.delegated_managed_identity_resource_id, null)
  skip_service_principal_aad_check       = try(each.value.skip_service_principal_aad_check, null)
}
