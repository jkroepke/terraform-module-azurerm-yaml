locals {
  network_security_groups_yaml = [for file in fileset("", "${var.yaml_root}/network_security_group/*.yaml") : yamldecode(file(file))]
  network_security_groups      = { for yaml in local.network_security_groups_yaml : "${yaml.resource_group_name}/${yaml.name}" => yaml }
  network_security_groups_rules = [
    for name, options in local.network_security_groups : [
      for subname, subresource in try(options.rules, {}) : merge({
        name                        = subname
        network_security_group_name = azurerm_network_security_group.this[name].name
        resource_group_name         = azurerm_network_security_group.this[name].resource_group_name
      }, subresource)
    ]
  ]
}

resource "azurerm_network_security_group" "this" {
  for_each = local.network_security_groups

  name = each.value.name

  resource_group_name = contains(keys(azurerm_resource_group.this), each.value.resource_group_name) ? azurerm_resource_group.this[each.value.resource_group_name].name : each.value.resource_group_name
  location            = try(each.value.location, var.default_location)
  tags                = merge(try(each.value.tags, {}), var.default_tags)

  lifecycle {
    ignore_changes = [security_rule]
  }
}

resource "azurerm_network_security_rule" "this" {
  for_each = {
    for rule in flatten(local.network_security_groups_rules) : "${rule.resource_group_name}/${rule.network_security_group_name}/${rule.name}" => rule
  }

  name        = each.value.name
  description = try(each.value.description, null)

  resource_group_name         = each.value.resource_group_name
  network_security_group_name = each.value.network_security_group_name

  access                                     = each.value.access
  direction                                  = each.value.direction
  priority                                   = each.value.priority
  protocol                                   = each.value.protocol
  source_port_range                          = try(each.value.source_port_range, null)
  source_port_ranges                         = try(each.value.source_port_ranges, null)
  destination_port_range                     = try(each.value.destination_port_range, null)
  destination_port_ranges                    = try(each.value.destination_port_ranges, null)
  source_address_prefix                      = try(each.value.source_address_prefix, null)
  source_address_prefixes                    = try(each.value.source_address_prefixes, null)
  destination_address_prefix                 = try(each.value.destination_address_prefix, null)
  destination_address_prefixes               = try(each.value.destination_address_prefixes, null)
  source_application_security_group_ids      = try(each.value.source_application_security_group_ids, null)
  destination_application_security_group_ids = try(each.value.destination_application_security_group_ids, null)
}

output "azurerm_network_security_group" {
  value = azurerm_network_security_group.this
}
