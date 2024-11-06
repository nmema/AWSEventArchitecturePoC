data "terraform_remote_state" "db" {
  backend = "s3"

  config = {
    bucket = "terraform-baby-state-dev"
    key    = "data-stores/dynamodb/terraform.tfstate"
    region = "us-west-2"
  }
}

data "terraform_remote_state" "cognito" {
  backend = "s3"

  config = {
    bucket = "terraform-baby-state-dev"
    key    = "cognito/terraform.tfstate"
    region = "us-west-2"
  }
}
