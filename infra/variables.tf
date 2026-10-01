variable "env" {
  description = "Environment name: dev or prod"
  type        = string
}

variable "location" {
  type    = string
  default = "northeurope"
}

variable "sku" {
  description = "App Service plan SKU. F1 = free, B1 = basic"
  type        = string
  default     = "F1"
}
