resource "azurerm_storage_account" "this" {
  for_each = local.storage_accounts

  access_tier                       = try(each.value.access_tier, null)
  account_kind                      = try(each.value.account_kind, null)
  account_replication_type          = each.value.account_replication_type
  account_tier                      = each.value.account_tier
  allow_nested_items_to_be_public   = try(each.value.allow_nested_items_to_be_public, null)
  allowed_copy_scope                = try(each.value.allowed_copy_scope, null)
  cross_tenant_replication_enabled  = try(each.value.cross_tenant_replication_enabled, null)
  default_to_oauth_authentication   = try(each.value.default_to_oauth_authentication, null)
  edge_zone                         = try(each.value.edge_zone, null)
  enable_https_traffic_only         = try(each.value.enable_https_traffic_only, null)
  infrastructure_encryption_enabled = try(each.value.infrastructure_encryption_enabled, null)
  is_hns_enabled                    = try(each.value.is_hns_enabled, null)
  large_file_share_enabled          = try(each.value.large_file_share_enabled, null)
  location = try(each.value.location, (
    contains(keys(azurerm_resource_group.this), each.value.resource_group_name)
    ? azurerm_resource_group.this[each.value.resource_group_name].location
    : var.default_location
  ))
  min_tls_version               = try(each.value.min_tls_version, null)
  name                          = each.value.name
  nfsv3_enabled                 = try(each.value.nfsv3_enabled, null)
  public_network_access_enabled = try(each.value.public_network_access_enabled, null)
  queue_encryption_key_type     = try(each.value.queue_encryption_key_type, null)
  resource_group_name           = contains(keys(azurerm_resource_group.this), each.value.resource_group_name) ? azurerm_resource_group.this[each.value.resource_group_name].name : each.value.resource_group_name
  sftp_enabled                  = try(each.value.sftp_enabled, null)
  shared_access_key_enabled     = try(each.value.shared_access_key_enabled, null)
  table_encryption_key_type     = try(each.value.table_encryption_key_type, null)
  tags                          = merge(try(each.value.tags, {}), var.default_tags)

  dynamic "azure_files_authentication" {
    for_each = contains(keys(each.value), "azure_files_authentication") ? { 1 : each.value.azure_files_authentication } : {}
    content {
      directory_type = azure_files_authentication.value.directory_type

      dynamic "active_directory" {
        for_each = contains(keys(azure_files_authentication.value), "active_directory") ? { 1 : azure_files_authentication.value.active_directory } : {}
        content {
          domain_guid         = active_directory.value.domain_guid
          domain_name         = active_directory.value.domain_name
          domain_sid          = active_directory.value.domain_sid
          forest_name         = active_directory.value.forest_name
          netbios_domain_name = active_directory.value.netbios_domain_name
          storage_sid         = active_directory.value.storage_sid
        }
      }
    }
  }

  dynamic "blob_properties" {
    for_each = contains(keys(each.value), "blob_properties") ? { 1 : each.value.blob_properties } : {}
    content {
      change_feed_enabled           = try(blob_properties.value.change_feed_enabled, null)
      change_feed_retention_in_days = try(blob_properties.value.change_feed_retention_in_days, null)
      default_service_version       = try(blob_properties.value.default_service_version, null)
      last_access_time_enabled      = try(blob_properties.value.last_access_time_enabled, null)
      versioning_enabled            = try(blob_properties.value.versioning_enabled, null)

      dynamic "container_delete_retention_policy" {
        for_each = contains(keys(blob_properties.value), "container_delete_retention_policy") ? { 1 : blob_properties.value.container_delete_retention_policy } : {}
        content {
          days = try(container_delete_retention_policy.value.days, null)
        }
      }

      dynamic "cors_rule" {
        for_each = contains(keys(blob_properties.value), "cors_rule") ? blob_properties.value.cors_rule : {}
        content {
          allowed_headers    = cors_rule.value.allowed_headers
          allowed_methods    = cors_rule.value.allowed_methods
          allowed_origins    = cors_rule.value.allowed_origins
          exposed_headers    = cors_rule.value.exposed_headers
          max_age_in_seconds = cors_rule.value.max_age_in_seconds
        }
      }

      dynamic "delete_retention_policy" {
        for_each = contains(keys(blob_properties.value), "delete_retention_policy") ? { 1 : blob_properties.value.delete_retention_policy } : {}
        content {
          days = try(delete_retention_policy.value.days, null)
        }
      }

      dynamic "restore_policy" {
        for_each = contains(keys(blob_properties.value), "restore_policy") ? { 1 : blob_properties.value.restore_policy } : {}
        content {
          days = restore_policy.value.days
        }
      }
    }
  }

  dynamic "custom_domain" {
    for_each = contains(keys(each.value), "custom_domain") ? { 1 : each.value.custom_domain } : {}
    content {
      name          = custom_domain.value.name
      use_subdomain = try(custom_domain.value.use_subdomain, null)
    }
  }

  dynamic "customer_managed_key" {
    for_each = contains(keys(each.value), "customer_managed_key") ? { 1 : each.value.customer_managed_key } : {}
    content {
      key_vault_key_id          = customer_managed_key.value.key_vault_key_id
      user_assigned_identity_id = customer_managed_key.value.user_assigned_identity_id
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

  dynamic "immutability_policy" {
    for_each = contains(keys(each.value), "immutability_policy") ? { 1 : each.value.immutability_policy } : {}
    content {
      allow_protected_append_writes = immutability_policy.value.allow_protected_append_writes
      period_since_creation_in_days = immutability_policy.value.period_since_creation_in_days
      state                         = immutability_policy.value.state
    }
  }

  dynamic "network_rules" {
    for_each = contains(keys(each.value), "network_rules") ? { 1 : each.value.network_rules } : {}
    content {
      bypass         = try(network_rules.value.bypass, null)
      default_action = network_rules.value.default_action
      ip_rules       = try(network_rules.value.ip_rules, null)
      virtual_network_subnet_ids = (contains(keys(network_rules.value), "virtual_network_subnet_ids")
        ? [for id in network_rules.value.virtual_network_subnet_ids : (
          contains(keys(azurerm_subnet.this), id)
          ? azurerm_subnet.this[id].id
          : id
        )]
        : null
      )

      dynamic "private_link_access" {
        for_each = contains(keys(network_rules.value), "private_link_access") ? network_rules.value.private_link_access : {}
        content {
          endpoint_resource_id = private_link_access.value.endpoint_resource_id
          endpoint_tenant_id   = try(private_link_access.value.endpoint_tenant_id, null)
        }
      }
    }
  }

  dynamic "queue_properties" {
    for_each = contains(keys(each.value), "queue_properties") ? { 1 : each.value.queue_properties } : {}
    content {

      dynamic "cors_rule" {
        for_each = contains(keys(queue_properties.value), "cors_rule") ? queue_properties.value.cors_rule : {}
        content {
          allowed_headers    = cors_rule.value.allowed_headers
          allowed_methods    = cors_rule.value.allowed_methods
          allowed_origins    = cors_rule.value.allowed_origins
          exposed_headers    = cors_rule.value.exposed_headers
          max_age_in_seconds = cors_rule.value.max_age_in_seconds
        }
      }

      dynamic "hour_metrics" {
        for_each = contains(keys(queue_properties.value), "hour_metrics") ? { 1 : queue_properties.value.hour_metrics } : {}
        content {
          enabled               = hour_metrics.value.enabled
          include_apis          = try(hour_metrics.value.include_apis, null)
          retention_policy_days = try(hour_metrics.value.retention_policy_days, null)
          version               = hour_metrics.value.version
        }
      }

      dynamic "logging" {
        for_each = contains(keys(queue_properties.value), "logging") ? { 1 : queue_properties.value.logging } : {}
        content {
          delete                = logging.value.delete
          read                  = logging.value.read
          retention_policy_days = try(logging.value.retention_policy_days, null)
          version               = logging.value.version
          write                 = logging.value.write
        }
      }

      dynamic "minute_metrics" {
        for_each = contains(keys(queue_properties.value), "minute_metrics") ? { 1 : queue_properties.value.minute_metrics } : {}
        content {
          enabled               = minute_metrics.value.enabled
          include_apis          = try(minute_metrics.value.include_apis, null)
          retention_policy_days = try(minute_metrics.value.retention_policy_days, null)
          version               = minute_metrics.value.version
        }
      }
    }
  }

  dynamic "routing" {
    for_each = contains(keys(each.value), "routing") ? { 1 : each.value.routing } : {}
    content {
      choice                      = try(routing.value.choice, null)
      publish_internet_endpoints  = try(routing.value.publish_internet_endpoints, null)
      publish_microsoft_endpoints = try(routing.value.publish_microsoft_endpoints, null)
    }
  }

  dynamic "sas_policy" {
    for_each = contains(keys(each.value), "sas_policy") ? { 1 : each.value.sas_policy } : {}
    content {
      expiration_action = try(sas_policy.value.expiration_action, null)
      expiration_period = sas_policy.value.expiration_period
    }
  }

  dynamic "share_properties" {
    for_each = contains(keys(each.value), "share_properties") ? { 1 : each.value.share_properties } : {}
    content {

      dynamic "cors_rule" {
        for_each = contains(keys(share_properties.value), "cors_rule") ? share_properties.value.cors_rule : {}
        content {
          allowed_headers    = cors_rule.value.allowed_headers
          allowed_methods    = cors_rule.value.allowed_methods
          allowed_origins    = cors_rule.value.allowed_origins
          exposed_headers    = cors_rule.value.exposed_headers
          max_age_in_seconds = cors_rule.value.max_age_in_seconds
        }
      }

      dynamic "retention_policy" {
        for_each = contains(keys(share_properties.value), "retention_policy") ? { 1 : share_properties.value.retention_policy } : {}
        content {
          days = try(retention_policy.value.days, null)
        }
      }

      dynamic "smb" {
        for_each = contains(keys(share_properties.value), "smb") ? { 1 : share_properties.value.smb } : {}
        content {
          authentication_types            = try(smb.value.authentication_types, null)
          channel_encryption_type         = try(smb.value.channel_encryption_type, null)
          kerberos_ticket_encryption_type = try(smb.value.kerberos_ticket_encryption_type, null)
          multichannel_enabled            = try(smb.value.multichannel_enabled, null)
          versions                        = try(smb.value.versions, null)
        }
      }
    }
  }

  dynamic "static_website" {
    for_each = contains(keys(each.value), "static_website") ? { 1 : each.value.static_website } : {}
    content {
      error_404_document = try(static_website.value.error_404_document, null)
      index_document     = try(static_website.value.index_document, null)
    }
  }
}
