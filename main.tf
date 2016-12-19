data "aws_vpc" "environment" {
  id = "${var.vpc_id}"
}

data "aws_ami" "base_ami" {
  filter {
    name   = "tag:Role"
    values = ["base"]
  }

  most_recent = true
}

data "aws_security_group" "prometheus" {
  filter {
    name   = "tag:Name"
    values = ["${var.environment}-prometheus-sg"]
  }
}

data "aws_route53_zone" "domain" {
  name = "${var.domain}."
}

resource "aws_iam_instance_profile" "consul" {
  name_prefix = "consul"
  roles       = ["ConsulInit"]
}

resource "aws_instance" "jenkins" {
  ami                  = "${data.aws_ami.base_ami.id}"
  instance_type        = "${var.instance_type}"
  key_name             = "${var.key_name}"
  subnet_id            = "${var.public_subnet_id}"
  user_data            = "${file("${path.module}/files/jenkins_bootstrap.sh")}"
  iam_instance_profile = "${aws_iam_instance_profile.consul.name}"

  vpc_security_group_ids = [
    "${aws_security_group.jenkins_host_sg.id}",
    "${data.aws_security_group.prometheus.id}",
  ]

  tags {
    Name = "${var.environment}-${var.app}-${var.role}"
    Role = "${var.role}"
  }
}

resource "aws_eip" "jenkins" {
  instance = "${aws_instance.jenkins.id}"
  vpc      = true
}

resource "aws_route53_record" "web" {
  zone_id = "${data.aws_route53_zone.domain.zone_id}"
  name    = "jenkins.${data.aws_route53_zone.domain.name}"
  type    = "A"
  ttl     = "300"
  records = ["${aws_eip.jenkins.public_ip}"]
}

resource "aws_security_group" "jenkins_host_sg" {
  name        = "${var.environment}-${var.app}-${var.role}-host"
  description = "Allow SSH and HTTP to Jenkins"
  vpc_id      = "${data.aws_vpc.environment.id}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${data.aws_vpc.environment.cidr_block}"]
  }

  # HTTP access from the VPC
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8
    to_port     = 0
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name = "${var.environment}-${var.app}-${var.role}-host-sg"
  }
}
