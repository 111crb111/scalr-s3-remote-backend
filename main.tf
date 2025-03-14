variable "region" {
    description = "The AWS region to deploy resources into"
    default     = "us-east-1"
}

variable "bucket_name" {
    description = "The name of the S3 bucket to create"
    default     = "crb-s3"
}

resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false      
  lower   = true           
}

locals {
  bucket_name = "${var.bucket_name}-${random_string.bucket_suffix.result}"
}

provider "aws" {
    region = var.region
}

# Create the S3 bucket to store the Terraform state file
resource "aws_s3_bucket" "terraform_state" {
  bucket = local.bucket_name
  acl    = "private"

  versioning {
    enabled = true
  }

  tags = {
    test-env-owner = "crb"
  }
}

# Create a DynamoDB table for state locking
resource "aws_dynamodb_table" "terraform_locks" {
  name         = "${var.bucket_name}-locks"
  billing_mode = "PAY_PER_REQUEST" # This uses on-demand pricing for DynamoDB

  attribute {
    name = "LockID"
    type = "S"
  }

  hash_key = "LockID"

  # Enable point-in-time recovery (optional)
  point_in_time_recovery {
    enabled = true
  }

  # Add a TTL to reduce storage costs for expired locks (optional)
  ttl {
    attribute_name = "TTL"
    enabled        = true
  }

  tags = {
    Name           = "TerraformLockTable"
    Environment    = "dev"
    test-env-owner = "crb"
  }
}

output "remote_config" {
    value = {
        bucket = aws_s3_bucket.terraform_state.bucket
        key    = "global/${local.bucket_name}/terraform.tfstate"
        region = var.region
        encrypt = true
        dynamodb_table = aws_dynamodb_table.terraform_locks.name
    }
}
