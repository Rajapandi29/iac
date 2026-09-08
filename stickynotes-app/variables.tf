variable "name" {
  description = "Existing eTicket application name"
  type        = string
}
variable "aws_region" {
  type = string
}

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



variable "container_port" {
  type    = number
  default = 3000
}

variable "image_tag" {
  description = "Sticky Notes Docker image tag"
  type        = string
  default     = "bootstrap"
}

variable "desired_count" {
  type    = number
  default = 1
}

variable "cpu" {
  type    = number
  default = 256
}

variable "memory" {
  type    = number
  default = 512
}



variable "eticket_image_tag" {
  description = "Existing eTicket Docker image tag"
  type        = string
  default     = "latest"
}



variable "alert_email" {
  type = string
}

variable "alert_phone" {
  type = string
}