variable "account_name" {
  type     = string
  nullable = false
}

variable "server_dns" {
  type     = string
  nullable = false
}

# ec2 key pair name
variable "aws_key_name" {
  default = "calori-web-ec2"
}

variable "aws_region" {
  description = "The AWS region to use"
  default     = "sa-east-1"
}
