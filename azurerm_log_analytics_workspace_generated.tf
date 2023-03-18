resource "azurerm_log_analytics_workspace" "this" {
  for_each = local.log_analytics_workspaces

  allow_resource_only_permissions = try(each.value.allow_resource_only_permissions, null)
  cmk_for_query_forced            = try(each.value.cmk_for_query_forced, null)
  daily_quota_gb                  = try(each.value.daily_quota_gb, null)
  internet_ingestion_enabled      = try(each.value.internet_ingestion_enabled, null)
  internet_query_enabled          = try(each.value.internet_query_enabled, null)
  local_authentication_disabled   = try(each.value.local_authentication_disabled, null)
  location = try(each.value.location, (
    contains(keys(azurerm_resource_group.this), each.value.resource_group_name)
    ? azurerm_resource_group.this[each.value.resource_group_name].location
    : var.default_location
  ))
  name                               = each.value.name
  reservation_capacity_in_gb_per_day = try(each.value.reservation_capacity_in_gb_per_day, null)
  resource_group_name                = contains(keys(azurerm_resource_group.this), each.value.resource_group_name) ? azurerm_resource_group.this[each.value.resource_group_name].name : each.value.resource_group_name
  retention_in_days                  = try(each.value.retention_in_days, null)
  sku                                = try(each.value.sku, null)
  tags                               = merge(try(each.value.tags, {}), var.default_tags)
}

resource "azurerm_log_analytics_solution" "this" {
  for_each = local.log_analytics_workspaces_solutions

  location = try(each.value.location, (
    contains(keys(azurerm_resource_group.this), each.value.resource_group_name)
    ? azurerm_resource_group.this[each.value.resource_group_name].location
    : var.default_location
  ))
  resource_group_name   = contains(keys(azurerm_resource_group.this), each.value.resource_group_name) ? azurerm_resource_group.this[each.value.resource_group_name].name : each.value.resource_group_name
  solution_name         = each.value.solution_name
  tags                  = merge(try(each.value.tags, {}), var.default_tags)
  workspace_name        = each.value.workspace_name
  workspace_resource_id = each.value.workspace_resource_id

  dynamic "plan" {
    for_each = contains(keys(each.value), "plan") ? { 1 : each.value.plan } : {}
    content {
      product        = plan.value.product
      promotion_code = try(plan.value.promotion_code, null)
      publisher      = plan.value.publisher
    }
  }
}
