resource "aws_cloudwatch_log_group" "cloudwatch_log_group" {
  name = "/aws/codebuild/${local.codebuild_project_name}"

  tags = var.tags
}
