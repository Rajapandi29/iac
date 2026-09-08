variable "name" {
  description = "Application name"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "cidr" {
  description = "VPC CIDR"
  type        = string
}

variable "azs" {
  description = "Availability zones"
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

variable "container_port" {
  description = "Application container port"
  type        = number
}

variable "image_tag" {
  description = "Docker image tag"
  type        = string
}

variable "desired_count" {
  description = "Number of ECS tasks"
  type        = number
  default     = 1
}

variable "cpu" {
  description = "ECS task CPU"
  type        = number
  default     = 256
}

variable "memory" {
  description = "ECS task memory"
  type        = number
  default     = 512
}

variable "alert_email" {
  description = "Email address for SNS alerts"
  type        = string
}

variable "alert_phone" {
  description = "Phone number for SNS SMS alerts"
  type        = string
}