resource "aws_apigatewayv2_api" "api" {
  name                       = "api-event-driven"
  protocol_type              = "WEBSOCKET"
  route_selection_expression = "$request.body.action"
}

resource "aws_apigatewayv2_deployment" "deployment" {
  api_id = aws_apigatewayv2_api.api.id
}

resource "aws_apigatewayv2_stage" "stage" {
  api_id      = aws_apigatewayv2_api.api.id
  name        = "dev"
  description = "Development Stage"
}

resource "aws_apigatewayv2_authorizer" "lambda_authorizer" {
  name             = "cognito_auth"
  api_id           = aws_apigatewayv2_api.api.id
  authorizer_type  = "REQUEST"
  authorizer_uri   = "arn:aws:apigateway:${var.aws_region}:lambda:path/2015-03-31/functions/${aws_lambda_function.lambda_authorizer.arn}/invocations"
  identity_sources = ["route.request.header.Authorization"]

  depends_on = [aws_lambda_permission.allow_gw_authorizer]

}

resource "aws_apigatewayv2_route" "connect_route" {
  api_id             = aws_apigatewayv2_api.api.id
  route_key          = "$connect"
  authorization_type = "CUSTOM"
  authorizer_id      = aws_apigatewayv2_authorizer.lambda_authorizer.id
  target             = "integrations/${aws_apigatewayv2_integration.connection_integration.id}"
}

resource "aws_apigatewayv2_route" "disconnect_route" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "$disconnect"
  target    = "integrations/${aws_apigatewayv2_integration.connection_integration.id}"
}

resource "aws_apigatewayv2_integration" "connection_integration" {
  integration_type       = "AWS_PROXY"
  api_id                 = aws_apigatewayv2_api.api.id
  integration_uri        = aws_lambda_function.lambda_connection.invoke_arn
  payload_format_version = "1.0"
}

resource "aws_apigatewayv2_route" "custom_route" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "custom"
  target    = "integrations/${aws_apigatewayv2_integration.custom_integration.id}"
}

resource "aws_apigatewayv2_integration" "custom_integration" {
  integration_type       = "AWS_PROXY"
  api_id                 = aws_apigatewayv2_api.api.id
  integration_uri        = aws_lambda_function.lambda_custom.invoke_arn
  payload_format_version = "1.0"
}
