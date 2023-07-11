variable "aws_region" {
  description = "Region of AWS"
  type        = string
}

variable "myuser_arn" {
  description = "ARN of my IAM user for CLI access"
  type        = string
}

variable "priv_subnets" {
  description = "list of private subnets to create"
  type        = list(string)
}

variable "pub_subnets" {
  description = "list of public subnets to create"
  type        = list(string)
}

variable "vpc__cidr_block" {
  description = "VPC CIDR for personal"
  type        = string
}
