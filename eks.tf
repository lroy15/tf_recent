locals {
  myarn   = var.myuser_arn
  arnname = "root"
}

variable "eks__version" {
  type        = string
  description = "The version of Kubernetes to use for the EKS cluster."
  default     = "1.27"
}

/*resource "aws_kms_key" "LJkey" {


}
resource "aws_kms_alias" "a" {

  target_key_id = "arn:aws:kms:us-east-2:142037495766:key/fb545c67-c0f6-48da-b9d8-23163aef33ab"
}
resource "aws_kms_key" "ekskey" {

}
resource "aws_kms_alias" "b" {
  target_key_id = "arn:aws:kms:us-east-2:142037495766:key/0da2917e-a380-4484-a787-76c5fd370a90"
}*/
module "eks" {
  source                      = "terraform-aws-modules/eks/aws"
  version                     = "19.10.1"
  kms_key_administrators      = [local.myarn]
  cluster_name                = "LJ-eks"
  cluster_version             = var.eks__version
  subnet_ids                  = module.vpc.private_subnets #aws_subnet.private[*].id
  vpc_id                      = module.vpc.vpc_id
  create_cloudwatch_log_group = false
  //kms_key_aliases             = ["alias/LJkey"]
  aws_auth_roles = [
    {
      rolearn  = aws_iam_role.eks_worker_nodes.arn
      username = "newRole"
      groups   = ["system:masters"]
    }
  ]

  aws_auth_users = [

    {
      userarn  = local.myarn
      username = local.arnname
      groups   = ["system:masters"]
    }
  ]

  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent    = true
      before_compute = true
    }

  }

  cluster_endpoint_private_access = false
  cluster_endpoint_public_access  = true
  cluster_service_ipv4_cidr       = "172.16.0.0/16"
  #create_aws_auth_configmap       = true



  manage_aws_auth_configmap = true


  eks_managed_node_group_defaults = {
    instance_types             = ["t2.medium"]
    ami_type                   = "AL2_x86_64"
    iam_role_attach_cni_policy = true
    aws_iam_role               = aws_iam_role.eks_worker_nodes.arn
  }

  eks_managed_node_groups = {
    blue = {
      min_size                   = 2
      max_size                   = 3
      desired_size               = 2
      instance_types             = ["t2.medium"]
      disk_size                  = 20
      use_custom_launch_template = false
    }
  }

  /* node_security_group_additional_rules = {
    dns_all = {
      description      = "DNS All"
      protocol         = "-1"
      from_port        = 53
      to_port          = 53
      type             = "egress"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }
  }*/

  /*cluster_security_group_additional_rules = {
    ingress_ingress_controllers_to_cluster_api_443 = {
      description              = "Ingress controllers to cluster API 443"
      type                     = "ingress"
      protocol                 = "tcp"
      from_port                = 443
      to_port                  = 443
      source_security_group_id = aws_security_group.eks_ingress_base_sg.id
    }
  }
*/
}

module "vpc_cni_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name_prefix      = "VPC-CNI-IRSA"
  attach_vpc_cni_policy = true
  vpc_cni_enable_ipv6   = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-node"]
    }
  }
}


# Cert Manager IRSA
module "cert_manager_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.2.0" # Latest as of July 2022

  role_name                     = "cert-manager"
  attach_cert_manager_policy    = true
  cert_manager_hosted_zone_arns = [aws_route53_zone.myZone.arn] #["arn:aws:route53:::hostedzone/Z03404421ONYWPDTF48HI"] # Lab HostedZone

  oidc_providers = {
    eks = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:cert-manager"]
    }
  }
}

# External DNS IRSA
# IAM Role for editing route53
module "external_dns_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.2.0" # Latest as of July 2022

  role_name                     = "external-dns"
  attach_external_dns_policy    = true
  external_dns_hosted_zone_arns = [aws_route53_zone.myZone.arn] #["arn:aws:route53:::hostedzone/Z03404421ONYWPDTF48HI"] # Lab HostedZone

  oidc_providers = {
    ex = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:external-dns"]
    }
  }

}


