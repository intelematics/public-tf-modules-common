resource "aws_s3_bucket" "codepipeline_bucket" {
  bucket = "${var.bucket_prefix}-codepipeline-${var.pipeline_name}"
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
