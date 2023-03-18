resource "azurerm_network_interface" "azurerm_windows_virtual_machine" {
  for_each = local.windows_virtual_machines_network_interface

  dns_servers                   = try(each.value.dns_servers, null)
  edge_zone                     = try(each.value.edge_zone, null)
  enable_accelerated_networking = try(each.value.enable_accelerated_networking, null)
  enable_ip_forwarding          = try(each.value.enable_ip_forwarding, null)
  internal_dns_name_label       = try(each.value.internal_dns_name_label, null)
  location = try(each.value.location, (
    contains(keys(azurerm_resource_group.this), each.value.resource_group_name)
    ? azurerm_resource_group.this[each.value.resource_group_name].location
    : var.default_location
  ))
  name                = each.value.name
  resource_group_name = contains(keys(azurerm_resource_group.this), each.value.resource_group_name) ? azurerm_resource_group.this[each.value.resource_group_name].name : each.value.resource_group_name
  tags                = merge(try(each.value.tags, {}), var.default_tags)

  dynamic "ip_configuration" {
    for_each = contains(keys(each.value), "ip_configuration") ? each.value.ip_configuration : {}
    content {
      gateway_load_balancer_frontend_ip_configuration_id = try(ip_configuration.value.gateway_load_balancer_frontend_ip_configuration_id, null)
      name                                               = ip_configuration.key
      primary                                            = try(ip_configuration.value.primary, null)
      private_ip_address                                 = try(ip_configuration.value.private_ip_address, null)
      private_ip_address_allocation                      = ip_configuration.value.private_ip_address_allocation
      private_ip_address_version                         = try(ip_configuration.value.private_ip_address_version, null)
      public_ip_address_id = (contains(keys(azurerm_public_ip.this), ip_configuration.value.public_ip_address_id)
        ? azurerm_public_ip.this[ip_configuration.value.public_ip_address_id].id
        : ip_configuration.value.public_ip_address_id
      )
      subnet_id = (contains(keys(azurerm_subnet.this), ip_configuration.value.subnet_id)
        ? azurerm_subnet.this[ip_configuration.value.subnet_id].id
        : ip_configuration.value.subnet_id
      )
    }
  }

  lifecycle {
    ignore_changes = [ip_configuration.0.name]
  }
}

resource "azurerm_windows_virtual_machine" "this" {
  for_each = local.windows_virtual_machines

  admin_password = (contains(keys(random_password.this), each.key)
    ? random_password.this[each.key].result
  : each.value.admin_password)
  admin_username                = each.value.admin_username
  allow_extension_operations    = try(each.value.allow_extension_operations, null)
  availability_set_id           = try(each.value.availability_set_id, null)
  capacity_reservation_group_id = try(each.value.capacity_reservation_group_id, null)
  computer_name                 = try(each.value.computer_name, null)
  custom_data                   = try(each.value.custom_data, null)
  dedicated_host_group_id       = try(each.value.dedicated_host_group_id, null)
  dedicated_host_id             = try(each.value.dedicated_host_id, null)
  edge_zone                     = try(each.value.edge_zone, null)
  enable_automatic_updates      = try(each.value.enable_automatic_updates, null)
  encryption_at_host_enabled    = try(each.value.encryption_at_host_enabled, null)
  eviction_policy               = try(each.value.eviction_policy, null)
  extensions_time_budget        = try(each.value.extensions_time_budget, null)
  hotpatching_enabled           = try(each.value.hotpatching_enabled, null)
  license_type                  = try(each.value.license_type, null)
  location = try(each.value.location, (
    contains(keys(azurerm_resource_group.this), each.value.resource_group_name)
    ? azurerm_resource_group.this[each.value.resource_group_name].location
    : var.default_location
  ))
  max_bid_price = try(each.value.max_bid_price, null)
  name          = each.value.name
  network_interface_ids = concat(
    [for nic, _ in local.windows_virtual_machines_network_interface : azurerm_network_interface.azurerm_windows_virtual_machine[nic].id],
    try(each.value.network_interface_ids, [])
  )
  patch_assessment_mode        = try(each.value.patch_assessment_mode, null)
  patch_mode                   = try(each.value.patch_mode, null)
  platform_fault_domain        = try(each.value.platform_fault_domain, null)
  priority                     = try(each.value.priority, null)
  provision_vm_agent           = try(each.value.provision_vm_agent, null)
  proximity_placement_group_id = try(each.value.proximity_placement_group_id, null)
  resource_group_name          = contains(keys(azurerm_resource_group.this), each.value.resource_group_name) ? azurerm_resource_group.this[each.value.resource_group_name].name : each.value.resource_group_name
  secure_boot_enabled          = try(each.value.secure_boot_enabled, null)
  size                         = each.value.size
  source_image_id              = try(each.value.source_image_id, null)
  tags                         = merge(try(each.value.tags, {}), var.default_tags)
  timezone                     = try(each.value.timezone, null)
  user_data                    = try(each.value.user_data, null)
  virtual_machine_scale_set_id = try(each.value.virtual_machine_scale_set_id, null)
  vtpm_enabled                 = try(each.value.vtpm_enabled, null)
  zone                         = try(each.value.zone, null)

  dynamic "additional_capabilities" {
    for_each = contains(keys(each.value), "additional_capabilities") ? { 1 : each.value.additional_capabilities } : {}
    content {
      ultra_ssd_enabled = try(additional_capabilities.value.ultra_ssd_enabled, null)
    }
  }

  dynamic "additional_unattend_content" {
    for_each = contains(keys(each.value), "additional_unattend_content") ? each.value.additional_unattend_content : {}
    content {
      content = additional_unattend_content.value.content
      setting = additional_unattend_content.value.setting
    }
  }

  dynamic "boot_diagnostics" {
    for_each = contains(keys(each.value), "boot_diagnostics") ? { 1 : each.value.boot_diagnostics } : {}
    content {
      storage_account_uri = (contains(keys(boot_diagnostics.value), "storage_account_uri")
        ? (contains(keys(azurerm_storage_account.this), boot_diagnostics.value.storage_account_uri)
          ? azurerm_storage_account.this[boot_diagnostics.value.storage_account_uri].primary_blob_endpoint
          : boot_diagnostics.value.storage_account_uri
        ) : null
      )
    }
  }

  dynamic "gallery_application" {
    for_each = contains(keys(each.value), "gallery_application") ? each.value.gallery_application : {}
    content {
      configuration_blob_uri = try(gallery_application.value.configuration_blob_uri, null)
      order                  = try(gallery_application.value.order, null)
      tag                    = try(gallery_application.value.tag, null)
      version_id             = gallery_application.value.version_id
    }
  }

  dynamic "identity" {
    for_each = contains(keys(each.value), "identity") ? { 1 : each.value.identity } : {}
    content {
      identity_ids = (contains(keys(identity.value), "identity_ids")
        ? [for id in identity.value.identity_ids : (
          contains(keys(azurerm_user_assigned_identity.this), id)
          ? azurerm_user_assigned_identity.this[id].id
          : id
        )]
        : null
      )
      type = identity.value.type
    }
  }

  dynamic "os_disk" {
    for_each = contains(keys(each.value), "os_disk") ? { 1 : each.value.os_disk } : {}
    content {
      caching                          = os_disk.value.caching
      disk_encryption_set_id           = try(os_disk.value.disk_encryption_set_id, null)
      disk_size_gb                     = try(os_disk.value.disk_size_gb, null)
      name                             = try(os_disk.value.name, null)
      secure_vm_disk_encryption_set_id = try(os_disk.value.secure_vm_disk_encryption_set_id, null)
      security_encryption_type         = try(os_disk.value.security_encryption_type, null)
      storage_account_type             = os_disk.value.storage_account_type
      write_accelerator_enabled        = try(os_disk.value.write_accelerator_enabled, null)

      dynamic "diff_disk_settings" {
        for_each = contains(keys(os_disk.value), "diff_disk_settings") ? { 1 : os_disk.value.diff_disk_settings } : {}
        content {
          option    = diff_disk_settings.value.option
          placement = try(diff_disk_settings.value.placement, null)
        }
      }
    }
  }

  dynamic "plan" {
    for_each = contains(keys(each.value), "plan") ? { 1 : each.value.plan } : {}
    content {
      name      = plan.value.name
      product   = plan.value.product
      publisher = plan.value.publisher
    }
  }

  dynamic "secret" {
    for_each = contains(keys(each.value), "secret") ? each.value.secret : {}
    content {
      key_vault_id = secret.value.key_vault_id

      dynamic "certificate" {
        for_each = contains(keys(secret.value), "certificate") ? secret.value.certificate : {}
        content {
          store = certificate.value.store
          url   = certificate.value.url
        }
      }
    }
  }

  dynamic "source_image_reference" {
    for_each = contains(keys(each.value), "source_image_reference") ? { 1 : each.value.source_image_reference } : {}
    content {
      offer     = source_image_reference.value.offer
      publisher = source_image_reference.value.publisher
      sku       = source_image_reference.value.sku
      version   = source_image_reference.value.version
    }
  }

  dynamic "termination_notification" {
    for_each = contains(keys(each.value), "termination_notification") ? { 1 : each.value.termination_notification } : {}
    content {
      enabled = termination_notification.value.enabled
      timeout = try(termination_notification.value.timeout, null)
    }
  }

  dynamic "winrm_listener" {
    for_each = contains(keys(each.value), "winrm_listener") ? each.value.winrm_listener : {}
    content {
      certificate_url = try(winrm_listener.value.certificate_url, null)
      protocol        = winrm_listener.value.protocol
    }
  }

  lifecycle {
    ignore_changes = [os_disk.0.name]
  }
}
