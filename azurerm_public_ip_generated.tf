resource "azurerm_public_ip" "this" {
  for_each = local.public_ips

  allocation_method       = each.value.allocation_method
  ddos_protection_mode    = try(each.value.ddos_protection_mode, null)
  ddos_protection_plan_id = try(each.value.ddos_protection_plan_id, null)
  domain_name_label       = try(each.value.domain_name_label, null)
  edge_zone               = try(each.value.edge_zone, null)
  idle_timeout_in_minutes = try(each.value.idle_timeout_in_minutes, null)
  ip_tags                 = try(each.value.ip_tags, null)
  ip_version              = try(each.value.ip_version, null)
  location = try(each.value.location, (
    contains(keys(azurerm_resource_group.this), each.value.resource_group_name)
    ? azurerm_resource_group.this[each.value.resource_group_name].location
    : var.default_location
  ))
  name                = each.value.name
  public_ip_prefix_id = try(each.value.public_ip_prefix_id, null)
  resource_group_name = contains(keys(azurerm_resource_group.this), each.value.resource_group_name) ? azurerm_resource_group.this[each.value.resource_group_name].name : each.value.resource_group_name
  reverse_fqdn        = try(each.value.reverse_fqdn, null)
  sku                 = try(each.value.sku, null)
  sku_tier            = try(each.value.sku_tier, null)
  tags                = merge(try(each.value.tags, {}), var.default_tags)
  zones               = try(each.value.zones, null)
}
