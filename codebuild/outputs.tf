output "codebuild_project_name" {
  value = aws_codebuild_project.project.name
}

output "codebuild_project" {
  value = aws_codebuild_project.project
}

output "role" {
  value = aws_iam_role.codebuild_role.arn
}

output "role_name" {
  value = aws_iam_role.codebuild_role.name
}
