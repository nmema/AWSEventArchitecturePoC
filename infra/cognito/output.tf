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
