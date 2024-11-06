output "cognito_user_password" {
  value     = random_password.user_password.result
  sensitive = true
}

output "cognito_user_pool_arn" {
  value       = aws_cognito_user_pool.pool.arn
  description = "Cognito User Pool ARN"
}

output "cognito_user_pool_id" {
  value       = aws_cognito_user_pool.pool.id
  description = "Cognito User Pool ID"
}

output "cognito_user_client_id" {
  value       = aws_cognito_user_pool_client.client.id
  description = "Cognito Client ID"
}

output "oauth_url" {
  value       = "${aws_cognito_user_pool_domain.domain.domain}.auth.${var.aws_region}.amazoncognito.com/oauth2/authorize?client_id=${aws_cognito_user_pool_client.client.id}&response_type=token&scope=${join("+", aws_cognito_user_pool_client.client.allowed_oauth_scopes)}&redirect_uri=${urlencode(tolist(aws_cognito_user_pool_client.client.callback_urls)[0])}"
  description = "Cognito Client Hosted UI"
}
