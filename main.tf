data "aws_availability_zones" "available" {}

locals {
  name   = "${basename(path.cwd)}"
  region = "us-east-1"

  vpc_cidr = "10.0.0.0/16"
  azs      = slice(data.aws_availability_zones.available.names, 0, 3)

  tags = {
    Example    = local.name
    GithubRepo = "terraform-aws-vpc"
    GithubOrg  = "terraform-aws-modules"
  }
}

################################################################################
# VPC Module
################################################################################

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.12.1"

  name = local.name
  cidr = local.vpc_cidr

  azs                 = local.azs
  private_subnets     = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k)]
  public_subnets      = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 4)]


  private_subnet_names = []
  # public_subnet_names omitted to show default name generation for all three subnets
  database_subnet_names    = []
  elasticache_subnet_names = []
  redshift_subnet_names    = []
  intra_subnet_names       = []

  create_database_subnet_group  = false
  manage_default_network_acl    = false
  manage_default_route_table    = false
  manage_default_security_group = false

  enable_dns_hostnames = true
  enable_dns_support   = true

  enable_nat_gateway = true
  single_nat_gateway = false

  customer_gateways = {}

  enable_vpn_gateway = false

  enable_dhcp_options              = false
  dhcp_options_domain_name         = ""
  dhcp_options_domain_name_servers = []

  # VPC Flow Logs (Cloudwatch log group and IAM role will be created)
  vpc_flow_log_iam_role_name            = "vpc-complete-example-role"
  vpc_flow_log_iam_role_use_name_prefix = false
  enable_flow_log                       = false
  create_flow_log_cloudwatch_log_group  = false
  create_flow_log_cloudwatch_iam_role   = false
  flow_log_max_aggregation_interval     = 60

  tags = local.tags
}
