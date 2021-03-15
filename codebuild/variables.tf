variable "github_auth_token" {
  description = "The personal access token that is used to connect to the git repos"
}

variable "project" {
  description = "The main git repo name to use for building (eg. intelematics/my-awesome-repo)"
  type = object({
      owner = optional(string)
      branch = optional(string)
      repo = string
    })
  default = {
      owner = "intelematics"
      branch = "develop"
      repo = null
    }
}

variable "codebuild_project_name" {
  description = "Used to name the codebuild project and its resources"
}

variable "policy" {
  description = "The policy in JSON to apply to the codebuild job"
  default = "{\"Statement\": []}"
}

variable "codebuild_project_description" {
  default = ""
}
variable "environment" {
  description = "Describes the environment this should be created for.  This should be used to differentiate between environments, and is especially useful with multiple environments in one account"
}

variable "environment_variables" {
  type        = map(string)
  default = {}
}

variable additional_sources {
  description = "Any additional sources required as inputs to the project.  Gets added to the secondary sources of the build project."
  type = list(object({
    id = string
    type = string
    owner = string
    repo = string
  }))
  default = []
}

variable "buildspec" {
  description = "Pass either the buildspec or the path to the buildspec"
}

variable permissions-boundary {
  description = "Set this flag to null if the account does need a permission boundary set"
  default     = ""
}

variable "tags" {
  type = map(string)
}

variable "bucket_prefix" {
  description = "The prefix used to ensure global uniqueness of an s3 bucket"
  default = "ia"
}

locals {
  project = defaults(var.project, {
      owner = "intelematics"
      branch = "develop"
      repo = null
    })
    
  additional_sources = [for source in var.additional_sources : defaults(source, {
      owner = "intelematics"
      type = "GITHUB"
      repo = null
    })]
  codebuild_role_name = "${var.environment}-${var.codebuild_project_name}"
  codebuild_project_name = "${var.environment}-${var.codebuild_project_name}"
  environment_variables = merge(var.environment_variables, {
        AWS_DEFAULT_REGION: data.aws_region.current.name,
        AWS_ACCOUNT_ID: data.aws_caller_identity.current.account_id,
      }
  )
  permissions_boundary = var.permissions-boundary == "" ? "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/managed-permission-boundary" : var.permissions-boundary
}
