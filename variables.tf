variable "yaml_root" {
  type        = string
  description = "Path to YAML files"
}

variable "generated_password_length" {
  type        = number
  description = "password length for automatic generated virtual machine passwords"
  default     = 32
}

variable "generated_password_special" {
  type        = bool
  description = "include special characters for automatic generated virtual machine passwords"
  default     = true
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
