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

module "eks_blueprints_addons" {
  source  = "aws-ia/eks-blueprints-addons/aws"
  version = "~> 1.16.2"

  cluster_name      = data.terraform_remote_state.eks.outputs.cluster_name
  cluster_endpoint  = data.terraform_remote_state.eks.outputs.cluster_endpoint
  cluster_version   = data.terraform_remote_state.eks.outputs.kubernetes_version
  oidc_provider_arn = data.terraform_remote_state.eks.outputs.oidc_provider_arn

  create_kubernetes_resources = true

  # common addons deployed with EKS Blueprints Addons
  enable_aws_load_balancer_controller = try(var.cluster_config.capabilities.loadbalancing, true)
  aws_load_balancer_controller = {
    values = [yamlencode(local.critical_addons_tolerations)]
  }

  # external-secrets is being used AMG for grafana auth
  enable_external_secrets = try(var.observability_configuration.aws_oss_tooling, false)
  external_secrets = {
    values = [
      yamlencode({
        tolerations = [local.critical_addons_tolerations.tolerations[0]]
        webhook = {
          tolerations = [local.critical_addons_tolerations.tolerations[0]]
        }
        certController = {
          tolerations = [local.critical_addons_tolerations.tolerations[0]]
        }
      })
    ]
  }

  # cert-manager as a dependency for ADOT addon
  enable_cert_manager = try(
    var.observability_configuration.aws_oss_tooling
    && var.observability_configuration.aws_oss_tooling_config.enable_adot_collector,
  false)
  cert_manager = {
    values = [
      yamlencode({
        tolerations = [local.critical_addons_tolerations.tolerations[0]]
        webhook = {
          tolerations = [local.critical_addons_tolerations.tolerations[0]]
        }
        cainjector = {
          tolerations = [local.critical_addons_tolerations.tolerations[0]]
        }
      })
    ]
  }

  # FluentBit 
  enable_aws_for_fluentbit = try(
    var.observability_configuration.aws_oss_tooling
    && !var.observability_configuration.aws_oss_tooling_config.enable_adot_collector
  , false)
  aws_for_fluentbit = {
    values = [
      yamlencode({ "tolerations" : [{ "operator" : "Exists" }] })
    ]
  }
  aws_for_fluentbit_cw_log_group = {
    name            = "/aws/eks/${data.terraform_remote_state.eks.outputs.cluster_name}/aws-fluentbit-logs"
    use_name_prefix = false
    create          = true
  }

  # GitOps 
  enable_argocd = try(var.cluster_config.capabilities.gitops, true)
  argocd = {
    enabled = true
    # The following settings are required to be set to true to ensure the
    # argocd application is deployed
    create_argocd_application   = true
    create_kubernetes_resources = true
    enable_argocd               = true
    argocd_namespace            = "argocd"

  }
}


resource "null_resource" "clean_up_argocd_resources" {
  count = try(var.cluster_config.capabilities.gitops, true) ? 1 : 0
  triggers = {
    argocd           = module.eks_blueprints_addons.argocd.name
    eks_cluster_name = data.terraform_remote_state.eks.outputs.cluster_name
  }
  provisioner "local-exec" {
    command     = <<-EOT
      kubeconfig=/tmp/tf.clean_up_argocd.kubeconfig.yaml
      aws eks update-kubeconfig --name ${self.triggers.eks_cluster_name} --kubeconfig $kubeconfig
      rm -f /tmp/tf.clean_up_argocd_resources.err.log
      kubectl --kubeconfig $kubeconfig get Application -A -o name | xargs -I {} kubectl --kubeconfig $kubeconfig -n argocd patch -p '{"metadata":{"finalizers":null}}' --type=merge {} 2> /tmp/tf.clean_up_argocd_resources.err.log || true
      kubectl --kubeconfig $kubeconfig get appprojects -A -o name | xargs -I {} kubectl --kubeconfig $kubeconfig -n argocd patch -p '{"metadata":{"finalizers":null}}' --type=merge {} 2> /tmp/tf.clean_up_argocd_resources.err.log || true
      rm -f $kubeconfig
    EOT
    interpreter = ["bash", "-c"]
    when        = destroy
  }
}

module "hashicorp-vault-eks-addon" {
  source  = "hashicorp/hashicorp-vault-eks-addon/aws"
  version = "1.0.0-rc2"

  count = try(var.cluster_config.capabilities.vault, true) ? 1 : 0

  helm_config = {
    namespace = try(var.cluster_config.capabilities.vault_namespace, "vault")
    version = "0.29.1"
    values = [file("${path.module}/vault-config.yml")]
    recreate_pods = true
  }
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