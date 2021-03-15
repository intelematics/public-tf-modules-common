resource "aws_codepipeline" "project" {
  name     = var.pipeline_name
  role_arn = aws_iam_role.codepipeline_role.arn

  artifact_store {
    location = aws_s3_bucket.codepipeline_bucket.id
    type     = "S3"
  }
  
  tags = var.tags


  stage {
    #### SOURCE SECTION ####
    name = "source"

    ## Build Library
    dynamic "action" {
      for_each = local.build_library
      iterator = project

      content {
        name             = "build-library"
        category         = "Source"
        owner            = "ThirdParty"
        provider         = "GitHub"
        version          = "1"
        output_artifacts = local.build_lib_artifacts
  
        configuration = {
          Owner                = project.value.owner
          Repo                 = project.value.repo
          Branch               = project.value.branch
          PollForSourceChanges = "true"
          OAuthToken           = var.github_auth_token
        }
      }
    }

    ## Project Sources
    dynamic "action" {
      for_each = local.projects
      iterator = project
      
      content {
        name             = project.key
        namespace        = "Source_${project.key}"
        category         = "Source"
        owner            = "ThirdParty"
        provider         = "GitHub"
        version          = "1"
        output_artifacts = [project.value.project_artifact_source]
  
        configuration = {
          Owner                = project.value.owner
          Repo                 = project.value.repo
          Branch               = project.value.branch
          PollForSourceChanges = "true"
          OAuthToken           = var.github_auth_token
        }
      }
    }
  }
  
  dynamic "stage" {
    #### BUILD SECTION ####
    for_each = length(local.build_jobs) == 0 ? [] : ["has_builds"]
    
    content {
      name = "build"
  
      ## Project Build
      dynamic "action" {
        for_each = local.build_jobs
        iterator = project
        
        content {
          name            = project.key
          namespace       = "Build_${project.key}"
          category        = "Build"
          owner           = "AWS"
          provider        = "CodeBuild"
          input_artifacts = concat(local.build_lib_artifacts, [project.value.project_artifact_source])
          output_artifacts = [project.value.project_artifact_build]
          
          version         = "1"
    
          configuration = {
            PrimarySource = project.value.project_artifact_source
            ProjectName = project.value.project_codebuild_build
            EnvironmentVariables = jsonencode([
                                    {name: "PIPELINE_PROJECT_NAME", value: project.key},
                                    {name: "SOURCE_GITHUB_SHA", value: "#{Source_${project.key}.CommitId}"},
                                    {name: "PIPELINE_EXEC_ID", value: "#{codepipeline.PipelineExecutionId}"},
                                    ])
          }
        }
      }
    }
  }
  
  dynamic "stage" {
    #### DEPLOY SECTION ####
    for_each = local.environments
    iterator = environment
    
    content {
      name = "deploy-${environment.value.name}"

      ## Environment Gate - Manual
      dynamic "action" {
        for_each = environment.value.gate != null ? (environment.value.gate.type == "manual" ? ["gate"] : []) : []
        
        
        content {
          name            = "${environment.value.name}-manual-gate"
          category        = "Approval"
          owner           = "AWS"
          provider        = "Manual"
          version         = "1"
          run_order       = 1
    
          configuration = {
            CustomData = "Has the build been tested?"
          }
        }
      }

      ## Environment Project Deployment
      dynamic "action" {
        for_each = local.deploy_jobs
        iterator = project
        
        content {
          name            = project.key
          category        = "Build"
          owner           = "AWS"
          provider        = "CodeBuild"
          input_artifacts = project.value.build ? [project.value.project_artifact_build] : [project.value.project_artifact_source]
          output_artifacts = []
          version         = "1"
          run_order       = 2
    
          configuration = {
            ProjectName = replace(project.value.project_codebuild_deploy, "<ENVIRONMENT>", environment.value.name)
            EnvironmentVariables = jsonencode([{name: "PIPELINE_PROJECT_NAME", value: project.key},
                                    {name: "PIPELINE_ENVIRONMENT", value: environment.value.name},
                                    {name: "SOURCE_GITHUB_SHA", value: "#{Source_${project.key}.CommitId}"},
                                    {name: "PIPELINE_EXEC_ID", value: "#{codepipeline.PipelineExecutionId}"},
                                    ])
          }
        }
      }
      
      dynamic "action" {
        for_each = environment.value.after_deploy == null ? [] : environment.value.after_deploy
        iterator = after_deploy
        
        content {
          name            = after_deploy.value.name
          category        = "Build"
          owner           = "AWS"
          provider        = "CodeBuild"
          input_artifacts = concat(after_deploy.value.library, local.build_lib_artifacts)
          output_artifacts = []
          version         = "1"
          run_order       = after_deploy.value.run_order + 3
    
          configuration = {
            ProjectName = after_deploy.value.codebuild
            PrimarySource = coalesce(concat(after_deploy.value.library, local.build_lib_artifacts)...)
            EnvironmentVariables = jsonencode(concat(
                                    [for name, value in after_deploy.value.environment_variables : {name: name, value: value}],
                                    [ {name: "PIPELINE_PROJECT_NAME", value: after_deploy.value.project},
                                      {name: "PIPELINE_ENVIRONMENT", value: environment.value.name},
                                      {name: "PIPELINE_SOURCE_OWNER", value: after_deploy.value.source_owner},
                                      {name: "PIPELINE_SOURCE_REPO", value: after_deploy.value.source_repo},
                                      {name: "PIPELINE_SOURCE_BRANCH", value: after_deploy.value.source_branch},
                                      {name: "SOURCE_GITHUB_SHA", value: after_deploy.value.project == "" ? "" : "#{Source_${after_deploy.value.project}.CommitId}"},
                                      {name: "PIPELINE_EXEC_ID", value: "#{codepipeline.PipelineExecutionId}"},
                                    ]
                                    ))
          }
        }
      }
    }
  }
}
