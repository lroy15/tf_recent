locals {

}

data "aws_availability_zones" "available" {
  state = "available"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "3.19.0"

  name                   = "LJvpc"
  cidr                   = var.vpc__cidr_block
  azs                    = data.aws_availability_zones.available.names
  private_subnets        = var.priv_subnets
  public_subnets         = var.pub_subnets
  create_egress_only_igw = false
  enable_dns_hostnames   = true
  enable_nat_gateway     = true
  single_nat_gateway     = false

  # https://docs.aws.amazon.com/eks/latest/userguide/alb-ingress.html
}

