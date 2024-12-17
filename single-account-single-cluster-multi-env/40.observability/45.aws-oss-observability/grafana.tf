# Data block to fetch the SSO admin instance. Once you enabled SSO admin from console, you need data block to fetch this in your code.
provider "aws" {
  region = local.sso_region
  alias  = "sso"
  default_tags {
    tags = local.tags
  }
}

data "aws_ssoadmin_instances" "current" {
  provider = aws.sso
}

module "managed_grafana" {
  count   = var.observability_configuration.aws_oss_tooling ? 1 : 0
  source  = "terraform-aws-modules/managed-service-grafana/aws"
  version = "2.1.1"

  name                      = local.grafana_workspace_name
  associate_license         = false
  description               = local.grafana_workspace_description
  account_access_type       = "CURRENT_ACCOUNT"
  authentication_providers  = ["AWS_SSO"]
  permission_type           = "SERVICE_MANAGED"
  data_sources              = ["CLOUDWATCH", "PROMETHEUS", "XRAY"]
  notification_destinations = ["SNS"]
  stack_set_name            = local.grafana_workspace_name

  configuration = jsonencode({
    unifiedAlerting = {
      enabled = true
    },
    plugins = {
      pluginAdminEnabled = false
    }
  })

  grafana_version = "10.4"

  # Workspace IAM role
  create_iam_role                = true
  iam_role_name                  = local.grafana_workspace_name
  use_iam_role_name_prefix       = true
  iam_role_description           = local.grafana_workspace_description
  iam_role_path                  = "/grafana/"
  iam_role_force_detach_policies = true
  iam_role_max_session_duration  = 7200
  iam_role_tags                  = local.tags

  # Role associations
  # Ref: https://github.com/aws/aws-sdk/issues/25
  # Ref: https://github.com/hashicorp/terraform-provider-aws/issues/18812
  # WARNING: https://github.com/hashicorp/terraform-provider-aws/issues/24166
  role_associations = {
    "ADMIN" = {
      "user_ids" = [data.aws_identitystore_user.user[count.index].user_id]
    }
  }

  tags = local.tags
}

# ############################## Users,Group,Group's Membership #########################################

data "aws_identitystore_user" "user" {
  provider          = aws.sso
  count             = var.observability_configuration.aws_oss_tooling ? 1 : 0
  identity_store_id = tolist(data.aws_ssoadmin_instances.current.identity_store_ids)[0]

  alternate_identifier {
    unique_attribute {
      attribute_path  = "UserName"
      attribute_value = var.observability_configuration.aws_oss_tooling_config.sso_user
    }
  }
}



