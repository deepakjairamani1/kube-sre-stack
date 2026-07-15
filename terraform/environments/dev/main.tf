terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.25"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
  }

  backend "s3" {
    bucket         = "kube-sre-stack-tfstate"
    key            = "environments/dev/terraform.tfstate"
    region         = "us-west-2"
    dynamodb_table = "kube-sre-stack-tfstate-lock"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    }
  }
}

locals {
  environment = "dev"
  project     = "kube-sre-stack"
  owner       = "platform-team"

  common_tags = {
    Environment = local.environment
    Project     = local.project
    Owner       = local.owner
    ManagedBy   = "terraform"
    Repository  = "kube-sre-stack"
  }

  # Dev uses smaller instances and single NAT to reduce costs
  vpc_config = {
    cidr               = var.vpc_cidr
    azs                = slice(data.aws_availability_zones.available.names, 0, 2)
    enable_nat_gateway = true
    single_nat_gateway = true # Cost optimization for dev
  }
}

data "aws_availability_zones" "available" {
  state = "available"

  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

# --- VPC Module ---
module "vpc" {
  source = "../../modules/vpc"

  environment        = local.environment
  project            = local.project
  vpc_cidr           = local.vpc_config.cidr
  availability_zones = local.vpc_config.azs
  single_nat_gateway = local.vpc_config.single_nat_gateway

  tags = local.common_tags
}

# --- EKS Module ---
module "eks" {
  source = "../../modules/eks"

  environment        = local.environment
  project            = local.project
  cluster_version    = var.cluster_version
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids

  # Dev uses smaller node groups
  node_groups = {
    system = {
      instance_types = ["t3.medium"]
      min_size       = 1
      max_size       = 3
      desired_size   = 2
      labels = {
        role = "system"
      }
    }
  }

  # Karpenter config
  enable_karpenter = var.enable_karpenter

  tags = local.common_tags
}

# --- Observability Module ---
module "observability" {
  source = "../../modules/observability"

  environment  = local.environment
  cluster_name = module.eks.cluster_name

  # Dev uses reduced retention and resources
  prometheus_retention_days = 7
  grafana_admin_password    = var.grafana_admin_password

  enable_kubecost = false # Disabled in dev to save costs

  tags = local.common_tags

  depends_on = [module.eks]
}
