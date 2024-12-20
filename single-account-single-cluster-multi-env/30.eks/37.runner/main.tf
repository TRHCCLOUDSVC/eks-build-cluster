data "aws_region" "current" {}
data "aws_caller_identity" "current" {}
# data "aws_availability_zones" "available" {}
data "aws_iam_session_context" "current" {
  # This data source provides information on the IAM source role of an STS assumed role
  # For non-role ARNs, this data source simply passes the ARN through issuer ARN
  # Ref https://github.com/terraform-aws-modules/terraform-aws-eks/issues/2327#issuecomment-1355581682
  # Ref https://github.com/hashicorp/terraform-provider-aws/issues/28381
  arn = data.aws_caller_identity.current.arn
}


module "gitlab-runners" {
  source  = "aws-ia/eks-blueprints-addon/aws"
  version = "1.1.1"#ensure to update this to the latest/desired version

  count = try(var.cluster_config.capabilities.runners, true) ? 1 : 0

  chart         = "gitlab-runner"
  chart_version = "0.71.0"
  repository    = "http://charts.gitlab.io/"
  description   = "Gitlab Runners"
  namespace     = "gitlab-runner"
  create_namespace = true
  
  values = [file("${path.module}/values/gitlab-runner.yaml")]

  set = [
    {
      name  = "replicas"
      value = 1
    }
  ]
}