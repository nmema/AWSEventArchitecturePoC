terraform {
  backend "s3" {
    key            = "cognito/terraform.tfstate"
    bucket         = "terraform-baby-state-dev"
    region         = "us-west-2"
    dynamodb_table = "terraform-baby-locking"
    encrypt        = true
  }
}

resource "aws_cognito_user_pool" "pool" {
  name = "apigateway-pool"
}

resource "aws_cognito_user_pool_client" "client" {
  name         = "apigateway-client"
  user_pool_id = aws_cognito_user_pool.pool.id

  allowed_oauth_flows                  = ["implicit"]
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_scopes                 = ["email", "openid", "profile"]

  callback_urls                = ["http://localhost:3000/callback"]
  logout_urls                  = ["http://localhost:3000/logout"]
  supported_identity_providers = ["COGNITO"]
  generate_secret              = false
}

resource "aws_cognito_user_pool_domain" "domain" {
  domain       = "apigateway-domain"
  user_pool_id = aws_cognito_user_pool.pool.id
}

resource "random_password" "user_password" {
  length  = 24
  special = true
  numeric = true
  lower   = true
}

resource "null_resource" "add_user" {
  provisioner "local-exec" {
    command = <<EOT
      aws cognito-idp admin-create-user \
        --user-pool-id ${aws_cognito_user_pool.pool.id} \
        --username "test@cognito.com" \
        --user-attributes Name=email,Value=test@cognito.com Name=email_verified,Value=true \
        --temporary-password "${random_password.user_password.result}" \
        --desired-delivery-mediums EMAIL \
        --region ${var.aws_region}
    EOT
  }
  depends_on = [aws_cognito_user_pool.pool, random_password.user_password]
}
