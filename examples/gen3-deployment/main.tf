provider "aws" {

  region = local.aws_region

  default_tags {
    tags = local.default_tags
  }
}

data "aws_caller_identity" "current" {}

terraform {
  backend "s3" {
    # The bucket to store the Terraform state file in.
    bucket = "gen3hep" # Update to represent your environment
    # The location of the Terraform state file within the bucket. Notice the bucket has to exist beforehand.
    key = "gen3-commons/terraform.tfstate" # Update to represent your environment    
    encrypt = "true"
    # The region where the S3 bucket is located.
    region = "us-east-1"
  }
}

locals {
  # This will be the name of the VPC, and will be used to identify most resources created within the module
  vpc_name                      = "hep1"
  # The account number where the resources will be created in. This should be populated automatically through the AWS user/role you are using to run this module.
  account_number                = data.aws_caller_identity.current.account_id
  # The AWS region where the resources will be created in
  aws_region                    = "us-east-1"  
  # The namespace your gen3 deployment will use. Default is good for first time deployments.
  ## If you want another deployment in the same cluster, copy paste the gen3 module block, create a new namespace local variable or manually update the namespace within the second instance of the module.
  kubernetes_namespace          = "default"
  # The availability zones where the resources will be created in. There should be 3 availability zones
  ## You can run aws ec2 describe-availability-zones --region <region> to get the list of availability zones in your region.
  availability_zones            = ["us-east-1a", "us-east-1c", "us-east-1d"] # ex. ["us-east-1a", "us-east-1c", "us-east-1d"]
  # The hostname for your gen3 deployment. If you are creating another instance of the gen3 module set the hostname in it accordingly
  hostname                      = "www.gen3hep.org"
  # Service linked roles can only be created once per account. If you see an error that it is already created, set this to false.
  es_linked_role                = true
  # The arn of the certificate in ACM
  revproxy_arn                  = "arn:aws:acm:us-east-1:789051085613:certificate/f0e702cc-31b0-466e-8d94-bbb223594064"
  # Whether or not to create users/buckets needed for useryaml gitops management.
  create_gitops_infra           = true
  # The name of the S3 bucket where the user.yaml file will be stored. Notice this will be created by terraform, so you don't need to create it beforehand.
  user_yaml_bucket_name = "gen3hep-users"
  # Set any tags you want to apply to all resources created by this module.
  default_tags = {
    Environment = local.vpc_name
  }


  ### Cognito setup
  deploy_cognito = true
  user_pool_name  = "${local.vpc_name}-pool"
  app_client_name = "${local.vpc_name}-client"
  domain_prefix = "${local.vpc_name}-auth"
  callback_urls = [
    "https://${local.hostname}/",
    "https://${local.hostname}/login/",
    "https://${local.hostname}/login/cognito/login/",
    "https://${local.hostname}/user/",
    "https://${local.hostname}/user/login/cognito/",
    "https://${local.hostname}/user/login/cognito/login/",
  ]
  logout_urls = [
    "https://${local.hostname}/",
  ]
  allowed_oauth_flows  = ["code"]
  allowed_oauth_scopes = ["email", "openid", "phone", "profile"]
  supported_identity_providers = ["COGNITO"]
}

module "commons" {
  source = "git::github.com/uc-cdis/gen3-terraform.git//tf_files/aws/commons?ref=583279e2dcb403058a7dee239119e8a8fce0b43f"

  vpc_name                       = local.vpc_name
  vpc_cidr_block                 = "10.10.0.0/20"
  aws_region                     = local.aws_region
  hostname                       = local.hostname
  kube_ssh_key                   = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC+FdLFzMG63Won1MSTJ8BZEpfSef3fMwWEd9iLsCYnNejB/dCkEjdNR2oClVRdgOf1vFKJ0WgAceNYdBHwG2VScY3IYj44uOB3fFByNlWFGydYyym8HkQ6uwdMHa0YkYLD28oy0bWhxTVVGZwCKJ13/3pc3zw79vzaW645W7wLU2rwu6WdtPnEBF16UeUtF3eyHbMD5BgQTTa7eNLZF0WITcig0w3cTQR2+cYoSOG5tiF6pO9CI+L19KiJIddnfTxmVx6Xf0JY8Gcvv+8A2K0pyQoWQv1ZDFbO62Jeax60+8EB3pctlW35FMlZmrZZ3UaiKTW+nIvFod7dnnp0/kX8ZAtr7hlYTYFRXbueb9cjQUR6LfEylF2t3pZ+kbejEY8iwD5qZcdaoZD5JeU2wFEd8/nhddQTeeMrVH86WTC3YkVpxk4ovM0kGjhDFFOsHyghL+cHVz6eGI+qlIEKalvepZ1OapIhOBfgSB+TP39zsAC1uf+Gc9YVhSKDkpg/wbE5XpF2PmzDePQTvOASie1IzB//VtjsRLAXtapyCffTPj347pFr8LxLQT7CWCwSDVFtyHqMmSKAeiZ3JthST5wnafnXubmjUagssGQ7W+hsJEc2ZhlWDUOog+PND2KYAMe1b3IOsK32NQk/qxW/xS6ktr6Y9ITV3WVzX9PSyBmUBw== ao@aomatrix.com"
  ami_account_id                 = "143731057154"
  squid_image_search_criteria    = "1-31-EKS-FIPS*"
  ha_squid_single_instance       = true
  ha-squid_instance_drive_size   = 35
  deploy_ha_squid                = true
  deploy_sheepdog_db             = false
  deploy_fence_db                = false
  deploy_indexd_db               = false
  network_expansion              = true
  users_policy                   = "dev"
  availability_zones             = local.availability_zones
  es_version                     = "7.10"
  es_linked_role                 = local.es_linked_role
  deploy_aurora                  = true
  deploy_rds                     = false
  use_asg                        = false
  use_karpenter                  = true
  deploy_karpenter_in_k8s        = true
  send_logs_to_csoc              = false
  secrets_manager_enabled        = true
  force_delete_bucket            = true
  enable_vpc_endpoints           = false
  cluster_engine_version         = "13"

  providers = {
    aws      = aws
    aws.csoc = aws
  }
}

module "gen3" {
  source = "git::github.com/uc-cdis/gen3-terraform.git//tf_files/gen3?ref=583279e2dcb403058a7dee239119e8a8fce0b43f"
  vpc_name                 = local.vpc_name
  aurora_username          = module.commons.aurora_cluster_master_username
  aurora_password          = module.commons.aurora_cluster_master_password
  aurora_hostname          = module.commons.aurora_cluster_writer_endpoint
  dictionary_url           = "https://s3.amazonaws.com/dictionary-artifacts/datadictionary/develop/schema.json"
  es_endpoint              = module.commons.es_endpoint
  hostname                 = local.hostname
  cluster_endpoint         = module.commons.eks_cluster_endpoint
  cluster_ca_cert          = module.commons.eks_cluster_ca_cert
  cluster_name             = module.commons.eks_cluster_name
  oidc_provider_arn        = module.commons.eks_oidc_arn
  fence_access_key         = module.commons.fence-bot_user_id
  fence_secret_key         = module.commons.fence-bot_user_secret
  upload_bucket            = module.commons.data-bucket_name
  revproxy_arn             = local.revproxy_arn
  useryaml_s3_path         = "s3://${local.user_yaml_bucket_name}/dev/user.yaml"
  deploy_external_secrets  = true
  deploy_gen3              = false
  create_dbs               = false
  cognito_discovery_url    = "https://${aws_cognito_user_pool.cognito_pool[0].endpoint}/.well-known/openid-configuration"
  cognito_client_id        = aws_cognito_user_pool_client.cognito_client[0].id
  cognito_client_secret    = aws_cognito_user_pool_client.cognito_client[0].client_secret

  providers = {
    helm       = helm
    kubernetes = kubernetes
  }

  depends_on = [
    module.commons,
  ]
}


resource "aws_iam_user" "gitops_user" {
  count = local.create_gitops_infra ? 1 : 0
  name  = "gitops-user"
}

resource "aws_iam_user_policy" "gitops_s3_policy" {
  count = local.create_gitops_infra ? 1 : 0
  name  = "gitops-user-s3-access"
  user  = aws_iam_user.gitops_user[0].name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = "arn:aws:s3:::${local.user_yaml_bucket_name}"
      },
      {
        Effect   = "Allow"
        Action   = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = [
          "arn:aws:s3:::${local.user_yaml_bucket_name}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_access_key" "gitops_key" {
  count = local.create_gitops_infra ? 1 : 0
  user  = aws_iam_user.gitops_user[0].name
}

resource "aws_s3_bucket" "users_bucket" {
  count  = local.create_gitops_infra ? 1 : 0
  bucket = local.user_yaml_bucket_name
  force_destroy = true
  tags = {
    Name        = "user-yaml-bucket"
    Environment = local.vpc_name
  }
}
