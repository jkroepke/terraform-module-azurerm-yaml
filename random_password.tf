locals {
  random_password = merge(local.windows_virtual_machines_passwords)
}

resource "random_password" "this" {
  for_each = local.random_password

  length  = var.generated_password_length
  special = var.generated_password_special

  min_lower   = 1
  min_numeric = 1
  min_special = var.generated_password_special ? 1 : 0
  min_upper   = 1
}
