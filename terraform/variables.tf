variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "ping_cidr" {
  description = "CIDR block to allow inbound ICMP (ping)"
  type        = string
  default     = "0.0.0.0/0"
}

variable "environment" {
  description = "Environment tag value"
  type        = string
  default     = "demo"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}