variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "app_name" {
  type    = string
  default = "rag-app"
}

variable "environment" {
  type    = string
  default = "production"
}



variable "vpc_cidr" {
  type    = string
  default = "10.50.0.0/16"
}

variable "azs" {
  type = list(string)

  default = [
    "us-east-1a",
    "us-east-1b"
  ]
}

variable "public_subnets" {
  type = list(string)

  default = [
    "10.50.1.0/24",
    "10.50.2.0/24"
  ]
}

variable "private_subnets" {
  type = list(string)

  default = [
    "10.50.11.0/24",
    "10.50.12.0/24"
  ]
}



variable "streamlit_port" {
  type    = number
  default = 8501
}

variable "fastapi_port" {
  type    = number
  default = 8000
}



variable "streamlit_image_tag" {
  type    = string
  default = "v1"
}

variable "fastapi_image_tag" {
  type    = string
  default = "v1"
}


variable "neon_api_key" {
  type      = string
  sensitive = true
}

variable "neon_database_url" {
  type      = string
  sensitive = true
}

variable "neon_database_name" {
  type      = string
  default   = "neondb"
}

variable "neon_database_user" {
  type      = string
  sensitive = true
}

variable "neon_database_password" {
  type      = string
  sensitive = true
}


variable "alert_email" {
  type    = string
  default = ""
}