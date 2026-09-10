terraform {
  backend "s3" {
    bucket = "terraform-state-04-09"
    key    = "/budgets/terraform.tfstate"
    region = "us-east-1"
    use_lockfile = true
    encrypt = true
  }
}