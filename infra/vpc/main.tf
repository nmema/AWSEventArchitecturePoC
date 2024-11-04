module "vpc" {
  source = "git::https://github.com/nmema/terraform-baby-modules.git//services/vpc?ref=v0.0.3"

  aws_region = "us-west-2"
}

terraform {
  backend "s3" {
    key            = "vpc/terraform.tfstate"
    bucket         = "terraform-baby-state-dev"
    region         = "us-west-2"
    dynamodb_table = "terraform-baby-locking"
    encrypt        = true
  }
}
