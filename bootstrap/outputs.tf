output "s3_bucket_name" {
  value       = aws_s3_bucket.terraform_state.bucket
  description = "Name of the S3 bucket for Terraform state"
}

output "dynamodb_table_name" {
  value       = aws_dynamodb_table.terraform_locks.name
  description = "Name of the DynamoDB table for Terraform state locking"
}

output "backend_config" {
  value = <<EOT
bucket         = "${aws_s3_bucket.terraform_state.bucket}"
key            = "terraform.tfstate"
region         = "${var.aws_region}"
dynamodb_table = "${aws_dynamodb_table.terraform_locks.name}"
encrypt        = true
EOT
  description = "Backend configuration for main Terraform project"
}
