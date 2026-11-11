variable "subscription_id" {
  type = string
}

variable "location" {
  type    = string
  default = "polandcentral"
}

variable "prefix" {
  type    = string
  default = "cloudlab"
}
variable "alert_email" {
  type = string
}