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

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}


data "archive_file" "lambda_connection" {
  type        = "zip"
  source_dir  = "${path.module}/../../backend/lambdas/connection"
  output_path = "${path.module}/lambda_connection.zip"
}

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

  source_arn = "${aws_apigatewayv2_api.api.execution_arn}/*"
}


data "archive_file" "lambda_custom" {
  type        = "zip"
  source_dir  = "${path.module}/../../backend/lambdas/custom"
  output_path = "${path.module}/lambda_custom.zip"
}

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

  source_arn = "${aws_apigatewayv2_api.api.execution_arn}/*/custom"
}

resource "aws_iam_role" "iam_for_lambda_cognito" {
  name               = "TerraformLambdaCognitoRole"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution_cognito" {
  role       = aws_iam_role.iam_for_lambda_cognito.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lambda_cognito_api_policy" {
  name = "TerraformCognitoPolicy"
  role = aws_iam_role.iam_for_lambda_cognito.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "cognito-idp:GetUser",
          "cognito-idp:DescribeUserPool"
        ]
        Effect   = "Allow"
        Resource = data.terraform_remote_state.cognito.outputs.cognito_user_pool_arn
      }
    ]
  })
}

resource "null_resource" "package_lambda_layer" {
  provisioner "local-exec" {
    command = <<EOT
      set -e # Exit immediately if a command exits with a non-zero status

      cd ${path.module}/../../backend/lambdas/authorizer

      python3 -m venv venv
      . venv/bin/activate
      mkdir -p python

      pip install -r requirements.txt -t python/
      zip -r ../../../infra/api/auth_layer.zip python/

      deactivate
      rm -rf venv python

    EOT
  }

  triggers = {
    requirements = filesha256("../../backend/lambdas/authorizer/requirements.txt")
  }
}

resource "aws_lambda_layer_version" "dependencies_layer" {
  filename            = "${path.module}/auth_layer.zip"
  layer_name          = "dependencies_layer"
  compatible_runtimes = ["python3.12"] # Adjust to your Lambda runtime
  source_code_hash    = filesha256("${path.module}/auth_layer.zip")

  depends_on = [null_resource.package_lambda_layer]

}

data "archive_file" "lambda_authorizer" {
  type        = "zip"
  source_dir  = "${path.module}/../../backend/lambdas/authorizer"
  output_path = "${path.module}/lambda_authorizer.zip"
}

resource "aws_lambda_function" "lambda_authorizer" {
  function_name = "AuthorizerFunction"
  filename      = data.archive_file.lambda_authorizer.output_path
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.12"
  role          = aws_iam_role.iam_for_lambda.arn

  layers = [aws_lambda_layer_version.dependencies_layer.arn]

  environment {
    variables = {
      COGNITO_USER_POOL_ID = data.terraform_remote_state.cognito.outputs.cognito_user_pool_id
      REGION               = var.aws_region
      CLIENT_ID            = data.terraform_remote_state.cognito.outputs.cognito_user_client_id
    }
  }

  source_code_hash = filebase64sha256(data.archive_file.lambda_authorizer.output_path)

}

resource "aws_lambda_permission" "allow_gw_authorizer" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_authorizer.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.api.execution_arn}/*"
}
