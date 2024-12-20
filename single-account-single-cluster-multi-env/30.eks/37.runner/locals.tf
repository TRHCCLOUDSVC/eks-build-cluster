locals {
  region         = data.aws_region.current.id
  tfstate_region = try(var.tfstate_region, local.region)
  critical_addons_tolerations = {
    tolerations = [
      {
        key      = "CriticalAddonsOnly",
        operator = "Exists",
        effect   = "NoSchedule"
      }
    ]
  }

  capabilities = {
    runners= try(var.cluster_config.capabilities.runners, true)
  }

  cache_create = try(var.cluster_config.runners_config.cache, true)
   = try(var.cluster_config.runners_config.cache_bucket, "gitlab-runner-cache-bucket")


  


  tags = merge(
    var.tags,
    {
      "Environment" : terraform.workspace
      "provisioned-by" : "aws-samples/terraform-workloads-ready-eks-accelerator"
    }
  )
}
