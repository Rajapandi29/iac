terraform {
  backend "s3" {
    bucket       = "terraform-state-04-09"
    key          = "buckets/terraform-state"
    region       = "ap-south-1"
    encrypt      = true
    use_lockfile = true
  }
}