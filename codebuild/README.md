# Codebuild Module

A basic module to setup codebuild, it creates the job and applies prefixing and tagging to make consistent job names

Simple usage example:

```
module "basic_build" {
  source = "git@github.com:intelematics/tf-modules-common.git//codebuild"
  
  bucket_prefix = "ia-basic"
  github_auth_token = local.github_auth_token

  codebuild_project_name = "backend-api"
  buildspec = file("buildspecs/basic.yml")
  project = {
    repo: "basic-backend-api"
  }
  environment = "build"
  environment_variables = {
    SPECIAL_VAR: "Special Build for backend-api",
  }

  tags = local.tags
}
```

This creates a new codebuild job (`build-backend-api`), that pulls from the given git repo, and executes the given
buildspec. Additional sources can be added if required, however it is easier to keep it simple.

It also creates an S3 bucket for cache and artifacts (`ia-basic-build-backend-api`)

It is suggested to use the file based buildspec as shown, as it:
* Keeps the build command in the cicd terraform
* Keeps the project free of build and deployment code
* Centralises the libraries
* Removes the need to have a library project, which then introduces other issues 

This example shows how you can use foreach to build out multiple jobs and environments, while keeping the
same terraform code:

```
module "basic_deploy" {
  source = "git@github.com:intelematics/tf-modules-common.git//codebuild"
  for_each = {for key in setproduct(["backend-api", "frontend-api"], ["sandbox", "prod"]) : "${key[0]}${key[1]}" => key}
  
  bucket_prefix = "ia-basic"
  github_auth_token = local.github_auth_token

  codebuild_project_name = "deploy-${each.value[0]}"
  buildspec = file("buildspecs/basic.yml")
  project = {
    repo: "basic-${each.value[0]}"
  }
  environment = each.value[1]
  environment_variables = {
    SPECIAL_VAR: "Special Deploy for ${each.value[0]}, environment: ${each.value[1]}",
  }

  tags = local.tags
}
```
