############################################################
##   Policies for the codebuild to run
############################################################

data "aws_iam_policy_document" "codebuild_assume_role_policy" {
  statement {
    sid    = ""
    effect = "Allow"

    actions = [
      "sts:AssumeRole",
    ]

    principals {
      identifiers = [
        "codebuild.amazonaws.com",
      ]

      type = "Service"
    }
  }
}

resource "aws_iam_role" "codebuild_role" {
  name                 = local.codebuild_role_name
  permissions_boundary = local.permissions_boundary
  assume_role_policy   = data.aws_iam_policy_document.codebuild_assume_role_policy.json
  force_detach_policies = true
  tags = var.tags
}

data "aws_iam_policy_document" "codebuild_policy" {
  statement {
    sid    = "AccessCodePipelineArtifacts"
    effect = "Allow"

    actions = [ 
      "s3:PutObject",
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:GetBucketVersioning",
      "s3:ListBucket",
    ]

    resources = [
      local.artifact_bucket,
      "${local.artifact_bucket}/*",
      "arn:aws:s3:::*-codepipeline-*"
      
    ]
  }

  statement {
    sid    = "logStream"
    effect = "Allow"

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:DeleteLogGroup",
      "logs:DescribeLogGroups",
      "logs:ListTagsLogGroup",
      "logs:PutLogEvents",
    ]

    resources = [
      "arn:aws:logs:${data.aws_region.current.name}:*:*",
    ]
  }

  statement {
    effect = "Allow"

    actions = [
      "iam:GetRole",
      "iam:PassRole",
    ]

    resources = [
      aws_iam_role.codebuild_role.arn,
    ]
  }
}

resource "aws_iam_role_policy" "codebuild_policy" {
  name   = "codebuild-policy"
  role   = aws_iam_role.codebuild_role.id
  # Build a policy from out template and the policy variable, so we don't need to attach one
  policy = jsonencode(merge(jsondecode(data.aws_iam_policy_document.codebuild_policy.json), {
                    Statement: concat(
                          jsondecode(data.aws_iam_policy_document.codebuild_policy.json).Statement, 
                          jsondecode(var.policy).Statement
                          )
                    }))
}
