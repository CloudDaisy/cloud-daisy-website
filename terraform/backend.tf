terraform {
  backend "s3" {
    bucket       = "cloud-daisy-terraform-state"
    key          = "cloud-daisy-website/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
  }
}
