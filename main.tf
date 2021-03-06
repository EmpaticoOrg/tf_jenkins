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

data "aws_security_group" "core" {
  filter {
    name   = "tag:Name"
    values = ["core-to-${var.environment}-sg"]
  }
}

data "aws_route53_zone" "domain" {
  name = "${var.domain}."
}

data "aws_route53_zone" "environment" {
  name         = "${var.environment}."
  private_zone = true
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
  iam_instance_profile = "${aws_iam_instance_profile.consul.name}"

  vpc_security_group_ids = [
    "${aws_security_group.jenkins_host_sg.id}",
    "${data.aws_security_group.core.id}",
  ]

  connection {
    bastion_host = "bastion.${var.domain}"
    host         = "${self.private_ip}"
    user         = "ubuntu"
    private_key  = "${file(var.key_path)}"
    agent        = true
  }

  provisioner "remote-exec" {
    script = "${path.module}/files/jenkins_bootstrap.sh"
  }

  tags {
    Name        = "${var.environment}-${var.role}-${var.app}"
    Role        = "${var.role}"
    App         = "${var.app}"
    Environment = "${var.environment}"
  }

  lifecycle {
    ignore_changes = ["tags"]
  }
}

resource "aws_route53_record" "jenkins" {
  zone_id = "${data.aws_route53_zone.domain.zone_id}"
  name    = "jenkins.${data.aws_route53_zone.domain.name}"
  type    = "A"
  ttl     = "300"
  records = ["${aws_instance.jenkins.public_ip}"]
}

resource "aws_route53_record" "jenkins_private" {
  zone_id = "${data.aws_route53_zone.environment.zone_id}"
  name    = "jenkins.${data.aws_route53_zone.environment.name}"
  type    = "A"
  ttl     = "300"
  records = ["${aws_instance.jenkins.private_ip}"]
}

resource "aws_security_group" "jenkins_host_sg" {
  name        = "${var.environment}-${var.role}-${var.app}"
  description = "Allow SSH and HTTP to Jenkins"
  vpc_id      = "${data.aws_vpc.environment.id}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${data.aws_vpc.environment.cidr_block}"]
  }

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

  tags {
    Name = "${var.environment}-${var.role}-${var.app}-sg"
  }
}
