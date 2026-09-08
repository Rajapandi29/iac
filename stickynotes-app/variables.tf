variable "cidr" {
  type = string
}

variable "azs" {
  type = list(string)
}

variable "public_subnets" {
  type = list(string)
}

variable "private_subnets" {
  type = list(string)
}

variable "image_tag" {
  type = string
}

variable "region" {
  type    = string
  default = "ap-south-1"
}
variable "alert_email" {
  type = string
}
variable "alert_phone" {
  type = string
}