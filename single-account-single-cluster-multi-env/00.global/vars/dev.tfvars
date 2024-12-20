# Dev environment variables 
vpc_cidr = "10.1.0.0/16"

# custom tags to apply to all resources
tags = {
  provisioned-by = "cpieper"
  purpose = "training and dev"
}

shared_config = {
  resources_prefix = "glrunners" // WRE = Workload Ready EKS 
}

cluster_config = {
  kubernetes_version  = "1.30"
  private_eks_cluster = false
  capabilities = {
    gitops = false
    loadbalancing = true
    vault = false
    runners = true
  }

  runners_config = {
    namespace = "gitlab-runner"
    version = "0.71.0"
    cache = true
    bucket = "gitlab-runners-cache"

  }
}

# Observability variables 
observability_configuration = {
  aws_oss_tooling    = true
  aws_native_tooling = true
  aws_oss_tooling_config = {
    enable_managed_collector = true
    enable_adot_collector    = true
    prometheus_name          = "prom"
    enable_grafana_operator  = true
    sso_region = "us-east-1"
    sso_user   = "cpieper"

  }
}
