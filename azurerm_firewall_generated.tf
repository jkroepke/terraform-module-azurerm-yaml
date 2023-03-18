resource "azurerm_firewall" "this" {
  for_each = local.firewalls

  dns_servers = try(each.value.dns_servers, null)
  firewall_policy_id = (contains(keys(each.value), "firewall_policy_id")
    ? (contains(keys(azurerm_firewall_policy.this), each.value.firewall_policy_id)
      ? azurerm_firewall_policy.this[each.value.firewall_policy_id]
      : each.value.firewall_policy_id
    )
    : (contains(keys(each.value), "policy")
      ? azurerm_firewall_policy.this["${each.key}/${each.value.policy.name}"].id
      : null
    )
  )
  location = try(each.value.location, (
    contains(keys(azurerm_resource_group.this), each.value.resource_group_name)
    ? azurerm_resource_group.this[each.value.resource_group_name].location
    : var.default_location
  ))
  name                = each.value.name
  private_ip_ranges   = try(each.value.private_ip_ranges, null)
  resource_group_name = contains(keys(azurerm_resource_group.this), each.value.resource_group_name) ? azurerm_resource_group.this[each.value.resource_group_name].name : each.value.resource_group_name
  sku_name            = each.value.sku_name
  sku_tier            = each.value.sku_tier
  tags                = merge(try(each.value.tags, {}), var.default_tags)
  threat_intel_mode   = try(each.value.threat_intel_mode, null)
  zones               = try(each.value.zones, null)

  dynamic "ip_configuration" {
    for_each = contains(keys(each.value), "ip_configuration") ? each.value.ip_configuration : {}
    content {
      name = ip_configuration.key
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

  dynamic "management_ip_configuration" {
    for_each = contains(keys(each.value), "management_ip_configuration") ? { 1 : each.value.management_ip_configuration } : {}
    content {
      name = management_ip_configuration.value.name
      public_ip_address_id = (contains(keys(azurerm_public_ip.this), management_ip_configuration.value.public_ip_address_id)
        ? azurerm_public_ip.this[management_ip_configuration.value.public_ip_address_id].id
        : management_ip_configuration.value.public_ip_address_id
      )
      subnet_id = (contains(keys(azurerm_subnet.this), management_ip_configuration.value.subnet_id)
        ? azurerm_subnet.this[management_ip_configuration.value.subnet_id].id
        : management_ip_configuration.value.subnet_id
      )
    }
  }

  dynamic "virtual_hub" {
    for_each = contains(keys(each.value), "virtual_hub") ? { 1 : each.value.virtual_hub } : {}
    content {
      public_ip_count = try(virtual_hub.value.public_ip_count, null)
      virtual_hub_id  = virtual_hub.value.virtual_hub_id
    }
  }
}

resource "azurerm_firewall_policy" "this" {
  for_each = local.firewalls_policies

  auto_learn_private_ranges_enabled = try(each.value.auto_learn_private_ranges_enabled, null)
  base_policy_id                    = try(each.value.base_policy_id, null)
  location = try(each.value.location, (
    contains(keys(azurerm_resource_group.this), each.value.resource_group_name)
    ? azurerm_resource_group.this[each.value.resource_group_name].location
    : var.default_location
  ))
  name                     = each.value.name
  private_ip_ranges        = try(each.value.private_ip_ranges, null)
  resource_group_name      = contains(keys(azurerm_resource_group.this), each.value.resource_group_name) ? azurerm_resource_group.this[each.value.resource_group_name].name : each.value.resource_group_name
  sku                      = try(each.value.sku, null)
  sql_redirect_allowed     = try(each.value.sql_redirect_allowed, null)
  tags                     = merge(try(each.value.tags, {}), var.default_tags)
  threat_intelligence_mode = try(each.value.threat_intelligence_mode, null)

  dynamic "dns" {
    for_each = contains(keys(each.value), "dns") ? { 1 : each.value.dns } : {}
    content {
      proxy_enabled = try(dns.value.proxy_enabled, null)
      servers       = try(dns.value.servers, null)
    }
  }

  dynamic "explicit_proxy" {
    for_each = contains(keys(each.value), "explicit_proxy") ? { 1 : each.value.explicit_proxy } : {}
    content {
      enable_pac_file = try(explicit_proxy.value.enable_pac_file, null)
      enabled         = try(explicit_proxy.value.enabled, null)
      http_port       = try(explicit_proxy.value.http_port, null)
      https_port      = try(explicit_proxy.value.https_port, null)
      pac_file        = try(explicit_proxy.value.pac_file, null)
      pac_file_port   = try(explicit_proxy.value.pac_file_port, null)
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

  dynamic "insights" {
    for_each = contains(keys(each.value), "insights") ? { 1 : each.value.insights } : {}
    content {
      default_log_analytics_workspace_id = insights.value.default_log_analytics_workspace_id
      enabled                            = insights.value.enabled
      retention_in_days                  = try(insights.value.retention_in_days, null)

      dynamic "log_analytics_workspace" {
        for_each = contains(keys(insights.value), "log_analytics_workspace") ? insights.value.log_analytics_workspace : {}
        content {
          firewall_location = log_analytics_workspace.value.firewall_location
          id                = log_analytics_workspace.value.id
        }
      }
    }
  }

  dynamic "intrusion_detection" {
    for_each = contains(keys(each.value), "intrusion_detection") ? { 1 : each.value.intrusion_detection } : {}
    content {
      mode           = try(intrusion_detection.value.mode, null)
      private_ranges = try(intrusion_detection.value.private_ranges, null)

      dynamic "signature_overrides" {
        for_each = contains(keys(intrusion_detection.value), "signature_overrides") ? intrusion_detection.value.signature_overrides : {}
        content {
          id    = try(signature_overrides.value.id, null)
          state = try(signature_overrides.value.state, null)
        }
      }

      dynamic "traffic_bypass" {
        for_each = contains(keys(intrusion_detection.value), "traffic_bypass") ? intrusion_detection.value.traffic_bypass : {}
        content {
          description           = try(traffic_bypass.value.description, null)
          destination_addresses = try(traffic_bypass.value.destination_addresses, null)
          destination_ip_groups = try(traffic_bypass.value.destination_ip_groups, null)
          destination_ports     = try(traffic_bypass.value.destination_ports, null)
          name                  = traffic_bypass.key
          protocol              = traffic_bypass.value.protocol
          source_addresses      = try(traffic_bypass.value.source_addresses, null)
          source_ip_groups      = try(traffic_bypass.value.source_ip_groups, null)
        }
      }
    }
  }

  dynamic "threat_intelligence_allowlist" {
    for_each = contains(keys(each.value), "threat_intelligence_allowlist") ? { 1 : each.value.threat_intelligence_allowlist } : {}
    content {
      fqdns        = try(threat_intelligence_allowlist.value.fqdns, null)
      ip_addresses = try(threat_intelligence_allowlist.value.ip_addresses, null)
    }
  }

  dynamic "tls_certificate" {
    for_each = contains(keys(each.value), "tls_certificate") ? { 1 : each.value.tls_certificate } : {}
    content {
      key_vault_secret_id = tls_certificate.value.key_vault_secret_id
      name                = tls_certificate.value.name
    }
  }
}

resource "azurerm_firewall_policy_rule_collection_group" "this" {
  for_each = local.firewalls_policy_rule_collection_groups

  firewall_policy_id = each.value.firewall_policy_id
  name               = each.value.name
  priority           = each.value.priority

  dynamic "application_rule_collection" {
    for_each = contains(keys(each.value), "application_rule_collection") ? each.value.application_rule_collection : {}
    content {
      action   = application_rule_collection.value.action
      name     = application_rule_collection.key
      priority = application_rule_collection.value.priority

      dynamic "rule" {
        for_each = contains(keys(application_rule_collection.value), "rule") ? application_rule_collection.value.rule : {}
        content {
          description           = try(rule.value.description, null)
          destination_addresses = try(rule.value.destination_addresses, null)
          destination_fqdn_tags = try(rule.value.destination_fqdn_tags, null)
          destination_fqdns     = try(rule.value.destination_fqdns, null)
          destination_urls      = try(rule.value.destination_urls, null)
          name                  = rule.key
          source_addresses      = try(rule.value.source_addresses, null)
          source_ip_groups      = try(rule.value.source_ip_groups, null)
          terminate_tls         = try(rule.value.terminate_tls, null)
          web_categories        = try(rule.value.web_categories, null)

          dynamic "protocols" {
            for_each = contains(keys(rule.value), "protocols") ? rule.value.protocols : {}
            content {
              port = protocols.value.port
              type = protocols.value.type
            }
          }
        }
      }
    }
  }

  dynamic "nat_rule_collection" {
    for_each = contains(keys(each.value), "nat_rule_collection") ? each.value.nat_rule_collection : {}
    content {
      action   = nat_rule_collection.value.action
      name     = nat_rule_collection.key
      priority = nat_rule_collection.value.priority

      dynamic "rule" {
        for_each = contains(keys(nat_rule_collection.value), "rule") ? nat_rule_collection.value.rule : {}
        content {
          destination_address = try(rule.value.destination_address, null)
          destination_ports   = try(rule.value.destination_ports, null)
          name                = rule.key
          protocols           = rule.value.protocols
          source_addresses    = try(rule.value.source_addresses, null)
          source_ip_groups    = try(rule.value.source_ip_groups, null)
          translated_address  = try(rule.value.translated_address, null)
          translated_fqdn     = try(rule.value.translated_fqdn, null)
          translated_port     = rule.value.translated_port
        }
      }
    }
  }

  dynamic "network_rule_collection" {
    for_each = contains(keys(each.value), "network_rule_collection") ? each.value.network_rule_collection : {}
    content {
      action   = network_rule_collection.value.action
      name     = network_rule_collection.key
      priority = network_rule_collection.value.priority

      dynamic "rule" {
        for_each = contains(keys(network_rule_collection.value), "rule") ? network_rule_collection.value.rule : {}
        content {
          destination_addresses = try(rule.value.destination_addresses, null)
          destination_fqdns     = try(rule.value.destination_fqdns, null)
          destination_ip_groups = try(rule.value.destination_ip_groups, null)
          destination_ports     = rule.value.destination_ports
          name                  = rule.key
          protocols             = rule.value.protocols
          source_addresses      = try(rule.value.source_addresses, null)
          source_ip_groups      = try(rule.value.source_ip_groups, null)
        }
      }
    }
  }
}
