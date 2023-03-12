locals {
  resource_groups_yaml = [for file in fileset("", "${var.yaml_root}/resource_group/*.yaml") : yamldecode(file(file))]
  resource_groups      = { for yaml in local.resource_groups_yaml : yaml.name => yaml }
}

resource "azurerm_resource_group" "this" {
  for_each = local.resource_groups

  name     = each.value.name
  location = try(each.value.location, var.default_location)
  tags     = merge(try(each.value.tags, {}), var.default_tags)
}

output "azurerm_resource_groups" {
  value = azurerm_resource_group.this
}
