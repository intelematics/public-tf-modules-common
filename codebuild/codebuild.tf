resource "aws_codebuild_project" "project" {
  name          = local.codebuild_project_name
  description   = var.codebuild_project_description
  build_timeout = "300"
  service_role  = aws_iam_role.codebuild_role.arn

  artifacts {
    type           = "S3"
    location       = local.artifact_bucket
    namespace_type = "BUILD_ID"
  }

  dynamic "cache" {
    for_each = local.cache_bucket_list
    content {
      type     = "S3"
      location = "${cache.value}/cache"
    }
  }

  environment {
    compute_type    = "BUILD_GENERAL1_SMALL"
    image           = local.codebuild_docker_image_name
    type            = "LINUX_CONTAINER"
    privileged_mode = true

    dynamic "environment_variable" {
      for_each = local.environment_variables
      content {
          name      = environment_variable.key
          value     = environment_variable.value
      }
    }
  }

  source_version = local.project.branch
  source {
    type      = "GITHUB"
    location  = "https://github.com/${local.project.owner}/${local.project.repo}.git"
    buildspec = var.buildspec

    auth {
      type     = "OAUTH"
      resource = var.github_auth_token
    }
  }
  
  dynamic "secondary_sources" {
    for_each = local.additional_sources
    content {
        source_identifier   = secondary_sources.value.id
        type                = secondary_sources.value.type
        location            = (secondary_sources.value.type == "GITHUB" ? 
                                "https://github.com/${secondary_sources.value.owner}/${secondary_sources.value.repo}.git" : 
                                secondary_sources.value.location)
                                
    }
  }
  
  tags = var.tags
}

resource "aws_codebuild_source_credential" "main" {
  auth_type   = "PERSONAL_ACCESS_TOKEN"
  server_type = "GITHUB"
  token       = var.github_auth_token
}
