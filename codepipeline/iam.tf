resource "aws_iam_role" "codepipeline_role" {
  name                  = "codepipeline-${var.pipeline_name}-role"
  permissions_boundary  = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/managed-permission-boundary"
  assume_role_policy    = data.aws_iam_policy_document.codepipeline_assume_role_policy.json
  force_detach_policies = true

  tags = var.tags
}


data "aws_iam_policy_document" "codepipeline_assume_role_policy" {
  statement {
    sid    = ""
    effect = "Allow"

    actions = [
      "sts:AssumeRole",
    ]

    principals {
      identifiers = [
        "codepipeline.amazonaws.com",
      ]

      type = "Service"
    }
  }
}

data "aws_iam_policy_document" "codepipeline_policy" {
  statement {
    effect = "Allow"

    actions = [
      "s3:*",
    ]

    resources = [
      aws_s3_bucket.codepipeline_bucket.arn,
      "${aws_s3_bucket.codepipeline_bucket.arn}/*",
    ]
  }

  statement {
    effect = "Allow"

    actions = [
      "codebuild:BatchGetBuilds",
      "codebuild:StartBuild",
    ]

    resources = [
      "*"
    ]
  }
}

resource "aws_iam_role_policy" "codepipeline_policy" {
  name   = aws_iam_role.codepipeline_role.name
  role   = aws_iam_role.codepipeline_role.id
  policy = data.aws_iam_policy_document.codepipeline_policy.json
}
