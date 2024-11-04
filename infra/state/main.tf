module "s3_backend" {
  source = "git::https://github.com/nmema/terraform-baby-modules.git//services/s3_backend?ref=v0.0.3"

  aws_region  = "us-west-2"
  bucket_name = "terraform-baby-state-dev"
  table_name  = "terraform-baby-locking"
}

terraform {
  backend "s3" {
    key            = "s3_state_backend/terraform.tfstate"
    bucket         = "terraform-baby-state-dev"
    region         = "us-west-2"
    dynamodb_table = "terraform-baby-locking"
    encrypt        = true
  }
}
