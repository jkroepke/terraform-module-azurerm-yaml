resource "azurerm_key_vault" "this" {
  for_each = local.key_vaults

  access_policy                   = try(each.value.access_policy, null)
  enable_rbac_authorization       = try(each.value.enable_rbac_authorization, null)
  enabled_for_deployment          = try(each.value.enabled_for_deployment, null)
  enabled_for_disk_encryption     = try(each.value.enabled_for_disk_encryption, null)
  enabled_for_template_deployment = try(each.value.enabled_for_template_deployment, null)
  location = try(each.value.location, (
    contains(keys(azurerm_resource_group.this), each.value.resource_group_name)
    ? azurerm_resource_group.this[each.value.resource_group_name].location
    : var.default_location
  ))
  name                          = each.value.name
  public_network_access_enabled = try(each.value.public_network_access_enabled, null)
  purge_protection_enabled      = try(each.value.purge_protection_enabled, null)
  resource_group_name           = contains(keys(azurerm_resource_group.this), each.value.resource_group_name) ? azurerm_resource_group.this[each.value.resource_group_name].name : each.value.resource_group_name
  sku_name                      = each.value.sku_name
  soft_delete_retention_days    = try(each.value.soft_delete_retention_days, null)
  tags                          = merge(try(each.value.tags, {}), var.default_tags)
  tenant_id                     = each.value.tenant_id

  dynamic "contact" {
    for_each = contains(keys(each.value), "contact") ? each.value.contact : {}
    content {
      email = contact.value.email
      name  = contact.key
      phone = try(contact.value.phone, null)
    }
  }

  dynamic "network_acls" {
    for_each = contains(keys(each.value), "network_acls") ? { 1 : each.value.network_acls } : {}
    content {
      bypass         = network_acls.value.bypass
      default_action = network_acls.value.default_action
      ip_rules       = try(network_acls.value.ip_rules, null)
      virtual_network_subnet_ids = (contains(keys(network_acls.value), "virtual_network_subnet_ids")
        ? [for id in network_acls.value.virtual_network_subnet_ids : (
          contains(keys(azurerm_subnet.this), id)
          ? azurerm_subnet.this[id].id
          : id
        )]
        : null
      )
    }
  }
}

resource "azurerm_key_vault_access_policy" "this" {
  for_each = local.key_vaults_access_policies

  application_id          = try(each.value.application_id, null)
  certificate_permissions = try(each.value.certificate_permissions, null)
  key_permissions         = try(each.value.key_permissions, null)
  key_vault_id            = each.value.key_vault_id
  object_id               = each.value.object_id
  secret_permissions      = try(each.value.secret_permissions, null)
  storage_permissions     = try(each.value.storage_permissions, null)
  tenant_id               = each.value.tenant_id
}
