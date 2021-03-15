variable "github_auth_token" {}
variable "pipeline_name" {}

variable "environments" {
  type = list(object({
    name = string
    gate = optional(object({
      type = string
    }))
    after_deploy = optional(list(object({
      codebuild = string
      projects = optional(list(string))
      environment_variables = optional(map(string))
    })))
  }))
}

variable "projects" {
  type = map(object({
    repo = string
    owner = optional(string)
    branch = optional(string)
    build = bool
    deploy = bool
  }))
  
  default = {}
}

variable "bucket_prefix" {
  default = "ia"
}

variable "build_project_template" {
  description = "Used to template the build project name for codebuild"
  default = "build-<PROJECT>"
}

variable "deploy_project_template" {
  description = "Used to template the deploy project name for codebuild"
  default = "<ENVIRONMENT>-deploy-<PROJECT>"
}

variable "build_library" {
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

variable "tags" {
  type = map(string)
}

locals {
  # Push in the library source defaults
  build_library = var.build_library.repo == null ? [] : [
    defaults(var.build_library, {
      owner = "intelematics"
      branch = "develop"
    })]
  build_lib_artifacts = var.build_library.repo == null ? [] : ["build_library"]
  
  #Setup the default values for projects
  projects_defaulted = {for project, properties in var.projects : project => defaults(properties, {
      owner = "intelematics"
      branch = "develop"
  })}
  
  #Add in additional fields into the project to make our terraform simpler to read
  projects = {for project, properties in local.projects_defaulted : project => merge(properties,{
                project_artifact_source: replace("source-${project}","-","_")
                project_artifact_build: replace("build-${project}","-","_")
                project_codebuild_build: replace(var.build_project_template, "<PROJECT>",project)
                project_codebuild_deploy: replace(var.deploy_project_template, "<PROJECT>",project)
              })}
  build_jobs = {for project, value in local.projects : project => value if value.build}
  deploy_jobs = {for project, value in local.projects : project => value if value.deploy}

  #make sure we have the array  
  environments_step1 = {for environment, properties in var.environments : environment =>
     merge(properties, {after_deploy: properties.after_deploy == null ? [] : properties.after_deploy})
  }
  
  #add run order as an attribute, for later processing.
  environments_step2 = {for environment, properties in local.environments_step1 : environment => 
    merge(properties, 
      { after_deploy: [for ad_properties in properties.after_deploy : 
        merge(ad_properties, 
          { run_order: index(properties.after_deploy, ad_properties),
            environment_variables: ad_properties.environment_variables == null ? {} : ad_properties.environment_variables}
        ) 
      ]}
    )
  }

  #Make an array with all the jobs, turning [{codebuild: "tag", run_order:0}] into 
  # [{codebuild: "tag", run_order:0, library: "proj1_build", project: "proj1", name: "tag@proj1"},
  #  {codebuild: "tag", run_order:0, library: "proj2_build", project: "proj2", name: "tag@proj2"}]
  environments_step3 = {for environment, properties in local.environments_step2 : environment =>
     merge(properties, 
        {after_deploy: flatten([for ad_properties in properties.after_deploy : 
          ad_properties.projects != null ? 
            [for project, value in (
                contains(ad_properties.projects, "BUILD") ? local.build_jobs : 
                   contains(ad_properties.projects, "DEPLOY") ? local.deploy_jobs : 
                      {for project, value in local.projects : project => value if contains(ad_properties.projects, project)}) :
              merge(ad_properties, 
                        { library: value.build ? [value.project_artifact_build] : [value.project_artifact_source],
                          project: project,
                          name: length(regexall("<PROJECT>", ad_properties.codebuild)) > 0 ? replace(ad_properties.codebuild, "<PROJECT>",project) : "${ad_properties.codebuild}@${project}",
                          source_owner: value.owner,
                          source_repo: value.repo,
                          source_branch: value.branch,
                          codebuild: replace(ad_properties.codebuild, "<PROJECT>",project),
                        })
            ]
          : [merge(ad_properties, 
                        { library: [],
                          project: ""
                          name: ad_properties.codebuild
                          source_owner: "",
                          source_repo: "",
                          source_branch: "",
                        })]
        ])}
     )
  }
  
  #Default the environment after deploy steps
  environments = local.environments_step3
}
