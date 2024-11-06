terraform {
  backend "s3" {
    key            = "data-stores/dynamodb/terraform.tfstate"
    bucket         = "terraform-baby-state-dev"
    region         = "us-west-2"
    dynamodb_table = "terraform-baby-locking"
    encrypt        = true
  }
}

resource "aws_dynamodb_table" "connections" {
  name         = "api-connections"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "ConnectionId"

  attribute {
    name = "ConnectionId"
    type = "S"
  }
}
