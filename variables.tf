variable "ami_id" {
  description = "AMI ID for EC2 instances"
  default     = "ami-0d1e0f7581275db6a"
}

variable "instance_type" {
  description = "Instance type for EC2 instances"
  default     = "t2.micro"
}

variable "domain_name" {
  description = "Domain name for Route 53"
  default     = "teracloud.lat"
}

variable "zone_id" {
  description = "ID de la zona hospedada en Route 53"
  default     = "Z0450839WXJ12WEIMR50"
}
