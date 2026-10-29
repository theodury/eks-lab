terraform {
  required_version = ">= 1.10"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.70"
    }
  }
}

provider "aws" {
  region = "eu-west-1"
  default_tags {
    tags = {
      Project   = "eks-lab"
      Owner     = "theo"
      Ephemeral = "true"
    }
  }
}

variable "budget_email" {
  type        = string
  description = "Address that receives the AWS Budget alerts. Pass it with TF_VAR_budget_email, never commit it."
}

data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "tfstate" {
  bucket = "eks-lab-tfstate-${data.aws_caller_identity.current.account_id}"

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket                  = aws_s3_bucket.tfstate.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_budgets_budget" "monthly" {
  name         = "eks-lab-monthly"
  budget_type  = "COST"
  limit_amount = "20"
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 25
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.budget_email]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.budget_email]
  }
}

# Cloudflare delegates eks.technoga.net to this zone's name servers; a recreated zone gets new ones.
resource "aws_route53_zone" "lab" {
  name = "eks.technoga.net"

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_acm_certificate" "lab" {
  domain_name       = "*.${aws_route53_zone.lab.name}"
  validation_method = "DNS"
}

resource "aws_route53_record" "lab_cert_validation" {
  for_each = { for o in aws_acm_certificate.lab.domain_validation_options : o.domain_name => o }

  zone_id = aws_route53_zone.lab.zone_id
  name    = each.value.resource_record_name
  type    = each.value.resource_record_type
  records = [each.value.resource_record_value]
  ttl     = 300
}

output "state_bucket" {
  value = aws_s3_bucket.tfstate.bucket
}

output "lab_name_servers" {
  value = aws_route53_zone.lab.name_servers
}
