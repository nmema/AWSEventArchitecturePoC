output "dynamodb_table_connections" {
  value       = aws_dynamodb_table.connections.arn
  description = "DynamoDB api-connections table ARN"
}
