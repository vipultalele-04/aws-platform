# ══════════════════════════════════════════════════════════════════
# TERRAFORM MAIN — Provider + Remote State Backend
# ══════════════════════════════════════════════════════════════════

terraform {
  required_version = ">= 1.3.0"

  # Remote state — S3 bucket created by terraform/backend/main.tf
  # Update bucket = with the output from bootstrap step
  backend "s3" {
    bucket         = "aws-platform-terraform-state-03874487"   # ← from bootstrap output
    key            = "aws-platform/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
  # Credentials come from GitHub Secrets via environment variables:
  # AWS_ACCESS_KEY_ID + AWS_SECRET_ACCESS_KEY — never hardcode here
}
