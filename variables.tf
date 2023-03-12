variable "yaml_root" {
  type        = string
  description = "Path to YAML files"
}

variable "default_location" {
  type        = string
  description = "Default location"
  default     = null
}

variable "default_tags" {
  type        = map(string)
  description = "Default Tags"
  default     = {}
}
