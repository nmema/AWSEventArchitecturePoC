terraform {
  backend "s3" {
    key            = "api/terraform.tfstate"
    bucket         = "terraform-baby-state-dev"
    region         = "us-west-2"
    dynamodb_table = "terraform-baby-locking"
    encrypt        = true
  }
}
