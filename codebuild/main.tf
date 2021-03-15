locals {
  # https://docs.aws.amazon.com/codebuild/latest/userguide/build-env-ref-available.html
  codebuild_docker_image_name = "aws/codebuild/standard:4.0"
}

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

terraform {
  experiments = [module_variable_optional_attrs]
}
