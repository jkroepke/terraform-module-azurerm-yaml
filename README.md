[![CI](https://github.com/jkroepke/terraform-modoule-azurerm-yaml/workflows/CI/badge.svg)](https://github.com/jkroepke/terraform-modoule-azurerm-yaml/)
[![License](https://img.shields.io/github/license/jkroepke/terraform-modoule-azurerm-yaml.svg)](https://github.com/jkroepke/terraform-modoule-azurerm-yaml/blob/main/LICENSE)
[![Current Release](https://img.shields.io/github/release/jkroepke/terraform-modoule-azurerm-yaml.svg)](https://github.com/jkroepke/terraform-modoule-azurerm-yaml/releases/latest)
[![GitHub all releases](https://img.shields.io/github/downloads/jkroepke/terraform-modoule-azurerm-yaml/total?logo=github)](https://github.com/jkroepke/terraform-modoule-azurerm-yaml/releases/latest)
[![GitHub issues](https://img.shields.io/github/issues/jkroepke/terraform-modoule-azurerm-yaml.svg)](https://github.com/jkroepke/terraform-modoule-azurerm-yaml/issues)
[![GitHub pull requests](https://img.shields.io/github/issues-pr/jkroepke/terraform-modoule-azurerm-yaml.svg)](https://github.com/jkroepke/terraform-modoule-azurerm-yaml/pulls)

# terraform-module-azurerm-yaml

Terraform module for describing resources as YAML file.

Take a look at the [example](./example) folder to see this module in action.

## Support Matrix

* Resource Groups
* Virtual Network
  * Subnet
  * Peerings
* Private DNS Zone
  * Virtual Network links
* Route Tables
* Storage Account
* Network Security Groups
* Windows Virtual Machines
* User Assigned Identity 

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | ~> 3.47 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) | ~> 3.47 |
| <a name="provider_random"></a> [random](#provider\_random) | n/a |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_default_location"></a> [default\_location](#input\_default\_location) | Default location | `string` | `null` | no |
| <a name="input_default_tags"></a> [default\_tags](#input\_default\_tags) | Default Tags | `map(string)` | `{}` | no |
| <a name="input_generated_password_length"></a> [generated\_password\_length](#input\_generated\_password\_length) | password length for automatic generated virtual machine passwords | `number` | `32` | no |
| <a name="input_generated_password_special"></a> [generated\_password\_special](#input\_generated\_password\_special) | include special characters for automatic generated virtual machine passwords | `bool` | `true` | no |
| <a name="input_yaml_root"></a> [yaml\_root](#input\_yaml\_root) | Path to YAML files | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_azurerm_network_security_group"></a> [azurerm\_network\_security\_group](#output\_azurerm\_network\_security\_group) | n/a |
| <a name="output_azurerm_private_dns_zones"></a> [azurerm\_private\_dns\_zones](#output\_azurerm\_private\_dns\_zones) | n/a |
| <a name="output_azurerm_resource_groups"></a> [azurerm\_resource\_groups](#output\_azurerm\_resource\_groups) | n/a |
| <a name="output_azurerm_route_table"></a> [azurerm\_route\_table](#output\_azurerm\_route\_table) | n/a |
| <a name="output_azurerm_storage_account"></a> [azurerm\_storage\_account](#output\_azurerm\_storage\_account) | n/a |
| <a name="output_azurerm_subnet"></a> [azurerm\_subnet](#output\_azurerm\_subnet) | n/a |
| <a name="output_azurerm_virtual_network"></a> [azurerm\_virtual\_network](#output\_azurerm\_virtual\_network) | n/a |
| <a name="output_azurerm_windows_virtual_machine"></a> [azurerm\_windows\_virtual\_machine](#output\_azurerm\_windows\_virtual\_machine) | n/a |
<!-- END_TF_DOCS -->
