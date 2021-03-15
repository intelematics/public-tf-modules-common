locals {
  cache_bucket_list = [aws_s3_bucket.codebuild.bucket]
  artifact_bucket = aws_s3_bucket.codebuild.arn
}

resource "aws_s3_bucket" "codebuild" {
  bucket = "${var.bucket_prefix}-codebuild-${local.codebuild_project_name}"
  acl    = "private"

  lifecycle_rule {
    enabled = true
    expiration {
      days = 90
    }
  }
  
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
  
  tags = var.tags
}
