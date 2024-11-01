terraform {
  backend "s3" {
    bucket  = "up-devops-terraform-backend"
    key     = "terraform/state.tfstate"
    region  = "us-east-1"
    encrypt = true
  }
}