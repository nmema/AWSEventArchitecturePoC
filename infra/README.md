# Infrastructure Setup Guide

This guide provides the step-by-step process for setting up the infrastructure using Terraform.

### Steps

You need to execute `terraform init` && `terraform apply` in the folders following this order.

1. `state/` (Please ensure to comment the code marked in the `main.tf`)
2. `data-stores/dynamodb/`
3. `cognito/`
4. `api/`

Grab `oauth_url` & `cognito_user_password` outputs as they are used to authenticate in Cognito.
