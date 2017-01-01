variable "environment" {
  description = "The name of our environment, i.e. development."
}

variable "key_name" {
  description = "The AWS key pair to use for resources."
}

variable "key_path" {
  description = "The path to the AWS key."
}

variable "public_subnet_id" {
  description = "The public subnet to populate."
}

variable "instance_type" {
  default     = "t2.micro"
  description = "The instance type to launch "
}

variable "vpc_id" {
  description = "The VPC ID to launch in"
}

variable "domain" {
  description = "The domain of the site"
}

variable "app" {
  description = "Name of application"
}

variable "role" {
  description = "Role of servers"
}

output "jenkins_host_address" {
  value = ["${aws_instance.jenkins.public_ip}"]
}

output "jenkins_private_address" {
  value = ["${aws_instance.jenkins.private_ip}"]
}
