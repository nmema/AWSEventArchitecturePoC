data "terraform_remote_state" "db" {
  backend = "s3"

  config = {
    bucket = "terraform-baby-state-dev"
    key    = "data-stores/dynamodb/terraform.tfstate"
    region = "us-west-2"
  }
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "iam_for_lambda" {
  name               = "TerraformLambdaRole"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}


# Attach DynamoDB and API Gateway permissions to the Lambda function's role
resource "aws_iam_role_policy" "lambda_dynamodb_api_policy" {
  name = "TerraformLambdaPolicy"
  role = aws_iam_role.iam_for_lambda.id
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ],
        "Resource" : "${data.terraform_remote_state.db.outputs.dynamodb_table_connections}"
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "execute-api:ManageConnections"
        ],
        "Resource" : "${aws_apigatewayv2_api.api.execution_arn}/*/@connections/*"
      }
    ]
  })
}

# Attach the basic Lambda execution policy
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}


data "archive_file" "lambda_connection" {
  type        = "zip"
  source_dir  = "${path.module}/../../backend/lambdas/connection"
  output_path = "${path.module}/lambda_connection.zip"
}

# Define the Lambda function using the created IAM role
resource "aws_lambda_function" "lambda_connection" {
  function_name = "ConnectionFunction"
  filename      = data.archive_file.lambda_connection.output_path
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.12"
  role          = aws_iam_role.iam_for_lambda.arn

  source_code_hash = filebase64sha256(data.archive_file.lambda_connection.output_path)

}

resource "aws_lambda_permission" "allow_gw_connection" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_connection.function_name
  principal     = "apigateway.amazonaws.com"

  # Specify the source ARN for the API Gateway
  source_arn = "${aws_apigatewayv2_api.api.execution_arn}/*"
}


data "archive_file" "lambda_custom" {
  type        = "zip"
  source_dir  = "${path.module}/../../backend/lambdas/custom"
  output_path = "${path.module}/lambda_custom.zip"
}

# Define the Lambda function using the created IAM role
resource "aws_lambda_function" "lambda_custom" {
  function_name = "CustomFunction"
  filename      = data.archive_file.lambda_custom.output_path
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.12"
  role          = aws_iam_role.iam_for_lambda.arn

  environment {
    variables = {
      API_GATEWAY_ID = aws_apigatewayv2_api.api.id
      REGION         = var.aws_region
      STAGE          = aws_apigatewayv2_stage.stage.name
    }
  }

  source_code_hash = filebase64sha256(data.archive_file.lambda_custom.output_path)

}

resource "aws_lambda_permission" "allow_gw_custom" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_custom.function_name
  principal     = "apigateway.amazonaws.com"

  # Specify the source ARN for the API Gateway
  source_arn = "${aws_apigatewayv2_api.api.execution_arn}/*/custom"
}
