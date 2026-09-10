terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }

    neon = {
      source  = "kislerdm/neon"
      version = "0.15.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

provider "neon" {
  api_key = var.neon_api_key
}