resource "aws_s3_bucket" "terraform_state" {

  bucket = "opslens-tfstate-${var.aws_account_id}"
  lifecycle {
    prevent_destroy = true
  }
  tags = {
    Project   = "OpsLens"
    ManagedBy = "Terraform"
  }
}


resource "aws_s3_bucket_versioning" "terraform_state" {

  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}


resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {

  bucket = aws_s3_bucket.terraform_state.id

  rule {

    apply_server_side_encryption_by_default {

      sse_algorithm = "AES256"

    }

  }
}


resource "aws_dynamodb_table" "terraform_lock" {

  name = "opslens-tf-locks"

  billing_mode = "PAY_PER_REQUEST"

  hash_key = "LockID"


  attribute {

    name = "LockID"

    type = "S"

  }


  tags = {

    Project   = "OpsLens"
    ManagedBy = "Terraform"

  }

}
