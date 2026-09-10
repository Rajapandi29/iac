terraform {
  backend "s3" {
    bucket = "terraform-state-10-09"
    key    = "buckets/terraform.tfstate"
    region = "us-east-1"
    use_lockfile = true
    encrypt = true
  }
}