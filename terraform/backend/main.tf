# ══════════════════════════════════════════════════════════════════
# BOOTSTRAP — Run ONCE manually before anything else
#
# Creates:
#   • S3 bucket     → stores terraform.tfstate remotely
#   • DynamoDB table → prevents two people applying at the same time
#
# HOW TO RUN:
#   cd terraform/backend
#   terraform init
#   terraform apply
# ══════════════════════════════════════════════════════════════════

provider "aws" {
  region = "us-east-1"
}

# ── S3 Bucket for Terraform state ─────────────────────────────────
resource "aws_s3_bucket" "tf_state" {
  bucket = "aws-platform-terraform-state-${random_id.suffix.hex}"

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name      = "terraform-state"
    ManagedBy = "bootstrap"
  }
}

resource "random_id" "suffix" {
  byte_length = 4
}

resource "aws_s3_bucket_versioning" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "tf_state" {
  bucket                  = aws_s3_bucket.tf_state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ── DynamoDB table for state locking ──────────────────────────────
resource "aws_dynamodb_table" "tf_lock" {
  name         = "terraform-state-lock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name      = "terraform-state-lock"
    ManagedBy = "bootstrap"
  }
}

# ── Outputs — copy these into terraform/backend.tf ────────────────
output "state_bucket_name" {
  value       = aws_s3_bucket.tf_state.bucket
  description = "Copy this into terraform/backend.tf → bucket ="
}

output "dynamodb_table_name" {
  value       = aws_dynamodb_table.tf_lock.name
  description = "Copy this into terraform/backend.tf → dynamodb_table ="
}
