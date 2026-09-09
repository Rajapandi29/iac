variable "name" {
  description = "Application/environment name"
  type        = string
}
variable "aws_region" {
  description = "Region selection"
  type        = string
}
variable "image_tag" {
  description = "Docker image tag"
  type        = string
  default     = "latest"
}

variable "cidr" {
  description = "VPC CIDR"
  type        = string
}

variable "azs" {
  description = "Availability Zones"
  type        = list(string)
}

variable "public_subnets" {
  description = "Public subnet CIDRs"
  type        = list(string)
}

variable "private_subnets" {
  description = "Private subnet CIDRs"
  type        = list(string)
}



variable "eticket_image_tag" {
  description = "Eticket Docker image tag"
  type        = string
  default     = "latest"
}

variable "eticket_container_port" {
  description = "Eticket container port"
  type        = number
  default     = 3000
}

variable "eticket_cpu" {
  description = "Eticket ECS CPU"
  type        = number
  default     = 256
}

variable "eticket_memory" {
  description = "Eticket ECS memory"
  type        = number
  default     = 512
}

variable "eticket_desired_count" {
  description = "Eticket desired ECS task count"
  type        = number
  default     = 1
}

variable "eticket_health_check_path" {
  description = "Eticket ALB health check path"
  type        = string
  default     = "/"
}



variable "stickynotes_image_tag" {
  description = "Sticky Notes Docker image tag"
  type        = string
  default     = "latest"
}

variable "stickynotes_container_port" {
  description = "Sticky Notes container port"
  type        = number
  default     = 3000
}

variable "stickynotes_cpu" {
  description = "Sticky Notes ECS CPU"
  type        = number
  default     = 256
}

variable "stickynotes_memory" {
  description = "Sticky Notes ECS memory"
  type        = number
  default     = 512
}

variable "stickynotes_desired_count" {
  description = "Sticky Notes desired ECS task count"
  type        = number
  default     = 1
}

variable "stickynotes_health_check_path" {
  description = "Sticky Notes ALB health check path"
  type        = string
  default     = "/"
}



variable "alert_email" {
  description = "Alert email address"
  type        = string
}

variable "alert_phone" {
  description = "Alert phone number"
  type        = string
}