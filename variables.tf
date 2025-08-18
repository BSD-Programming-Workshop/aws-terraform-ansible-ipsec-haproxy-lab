variable "aws_region" {
  default = "us-west-2"
}

variable "named_cidrs" {
  type = map(string)
  default = {
    vpc         = "172.60.0.0/16"
    workstation = "142.197.198.122/32"
  }
}

