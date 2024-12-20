
data "terraform_remote_state" "vpc" {
  backend   = "s3"
  workspace = terraform.workspace
  config = {
    bucket = "tfstate-${data.aws_caller_identity.current.account_id}-dev"
    key    = "networking/vpc/terraform.tfstate"
    region = local.tfstate_region
  }
}

data "terraform_remote_state" "iam" {
  backend   = "s3"
  workspace = terraform.workspace
  config = {
    bucket = "tfstate-${data.aws_caller_identity.current.account_id}-dev"
    key    = "iam/roles/terraform.tfstate"
    region = local.tfstate_region
  }
}

data "terraform_remote_state" "eks" {
  backend   = "s3"
  workspace = terraform.workspace
  config = {
    bucket = "tfstate-${data.aws_caller_identity.current.account_id}-dev"
    key    = "eks/terraform.tfstate"
    region = local.tfstate_region
  }
}
