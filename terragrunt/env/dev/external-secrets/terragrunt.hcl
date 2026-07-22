include "root" {
  path = find_in_parent_folders("terragrunt.hcl")
}

include "env" {
  path = find_in_parent_folders("env.hcl")
}

terraform {
  source = "../../../../terraform/modules/external-secrets"
}

dependency "eks" {
  config_path = "../eks"

  mock_outputs = {
    oidc_provider_arn = "arn:aws:iam::123456789012:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/EXAMPLE"
    oidc_provider_url = "https://oidc.eks.us-east-1.amazonaws.com/id/EXAMPLE"
    cluster_name      = "kube-sre-stack-dev"
  }

  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

inputs = {
  project           = "kube-sre-stack"
  environment       = "dev"
  region            = "us-east-1"
  chart_version     = "0.9.11"
  oidc_provider_arn = dependency.eks.outputs.oidc_provider_arn
  oidc_provider_url = dependency.eks.outputs.oidc_provider_url
  kms_key_arn       = "arn:aws:kms:us-east-1:123456789012:key/example-key-id"
}
