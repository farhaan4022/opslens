terraform {
  required_version = ">= 1.6"

  backend "s3" {
    bucket         = "opslens-tfstate-743502211832"
    key            = "infrastructure/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "opslens-tf-locks"
    encrypt        = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  profile = "opslens"
  region  = var.aws_region
}
