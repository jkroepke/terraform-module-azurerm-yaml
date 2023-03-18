locals {
  log_analytics_workspaces_yaml = [for file in fileset("", "${var.yaml_root}/log_analytics_workspace/*.yaml") : yamldecode(file(file))]
  log_analytics_workspaces      = { for yaml in local.log_analytics_workspaces_yaml : "${yaml.resource_group_name}/${yaml.name}" => yaml }
  log_analytics_workspaces_solutions = { for solution in flatten([
    for name, options in local.log_analytics_workspaces : [
      for subname, subresource in try(options.solutions, {}) : merge({
        _                     = name
        solution_name         = subname
        resource_group_name   = options.resource_group_name
        workspace_resource_id = azurerm_log_analytics_workspace.this[name].id
        workspace_name        = azurerm_log_analytics_workspace.this[name].name
      }, subresource)
    ]
  ]) : "${solution._}/${solution.solution_name}" => solution }
  log_analytics_workspaces_iam = { for role_assignment in flatten([
    for name, options in local.log_analytics_workspaces : [
      for role, role_assignments in try(options.iam, {}) : [
        for role_assignment_name, role_assignment in role_assignments : merge({
          _                    = name
          scope                = azurerm_user_assigned_identity.this[name].id
          role_definition_name = role
        }, role_assignment)
      ]
    ]
  ]) : "${role_assignment._}|${role_assignment.role_definition_name}|${role_assignment.principal_id}" => role_assignment }
}
