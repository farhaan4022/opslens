output "opslens_results_bucket_name" {
  description = "S3 bucket used for durable OpsLens validation artifacts"
  value       = aws_s3_bucket.opslens_results.bucket
}

output "opslens_results_bucket_arn" {
  description = "ARN of the OpsLens durable validation results bucket"
  value       = aws_s3_bucket.opslens_results.arn
}
