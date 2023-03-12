module "yaml" {
  source = "../"

  yaml_root = "${path.module}/files/"

  default_location = "westeurope"
  default_tags = {
    provisioner = "Terraform"
  }
}
