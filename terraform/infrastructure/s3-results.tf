data "aws_caller_identity" "opslens_results" {}

resource "aws_s3_bucket" "opslens_results" {
  bucket        = "opslens-results-${data.aws_caller_identity.opslens_results.account_id}"
  force_destroy = true

  tags = {
    Name      = "opslens-results"
    Project   = "OpsLens"
    Purpose   = "durable-request-validation"
    ManagedBy = "Terraform"
  }
}

resource "aws_s3_bucket_public_access_block" "opslens_results" {
  bucket = aws_s3_bucket.opslens_results.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "opslens_results" {
  bucket = aws_s3_bucket.opslens_results.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "opslens_results" {
  bucket = aws_s3_bucket.opslens_results.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "opslens_results" {
  bucket = aws_s3_bucket.opslens_results.id

  depends_on = [
    aws_s3_bucket_versioning.opslens_results
  ]

  rule {
    id     = "expire-validation-artifacts"
    status = "Enabled"

    filter {}

    expiration {
      days = 7
    }

    noncurrent_version_expiration {
      noncurrent_days = 7
    }
  }
}
