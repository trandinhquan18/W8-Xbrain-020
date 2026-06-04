data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_route53_zone" "app" {
  count = local.route53_enabled ? 1 : 0

  name         = "${local.route53_zone_name}."
  private_zone = false
}

resource "random_pet" "suffix" {
  length = 2
}

resource "tls_private_key" "ssh" {
  algorithm = "ED25519"
}

resource "local_sensitive_file" "ssh_private_key" {
  filename        = local.ssh_key_path
  content         = tls_private_key.ssh.private_key_openssh
  file_permission = "0600"
}

data "cloudinit_config" "minikube_bootstrap" {
  gzip          = true
  base64_encode = true

  part {
    content_type = "text/cloud-config"
    content = templatefile("${path.module}/cloud-init/minikube.yaml.tftpl", {
      app_name     = local.app_name
      cluster_name = local.cluster_name
      host_port    = var.app_host_port
    })
  }
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${random_pet.suffix.id}"
  })
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${random_pet.suffix.id}"
  })
}

resource "aws_subnet" "public" {
  count = 2

  vpc_id                  = aws_vpc.this.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-public-${count.index + 1}-${random_pet.suffix.id}"
  })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-public-${random_pet.suffix.id}"
  })
}

resource "aws_route" "internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-${random_pet.suffix.id}"
  description = "Allow HTTP traffic from the Internet to the ALB."
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "Public HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.allowed_http_cidr]
  }

  egress {
    description = "Forward traffic to EC2 targets"
    from_port   = var.app_host_port
    to_port     = var.app_host_port
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-alb-${random_pet.suffix.id}"
  })
}

resource "aws_security_group" "minikube_host" {
  name        = "${var.project_name}-minikube-host-${random_pet.suffix.id}"
  description = "Allow only ALB traffic to the minikube forwarded app port."
  vpc_id      = aws_vpc.this.id

  ingress {
    description     = "ALB to minikube app forwarder"
    from_port       = var.app_host_port
    to_port         = var.app_host_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    description = "Direct SSH access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  egress {
    description = "Allow outbound package and image downloads"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-minikube-host-${random_pet.suffix.id}"
  })
}

resource "aws_key_pair" "ssh" {
  key_name   = "${var.project_name}-ssh-${random_pet.suffix.id}"
  public_key = tls_private_key.ssh.public_key_openssh

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-ssh-${random_pet.suffix.id}"
  })
}

resource "aws_instance" "minikube_host" {
  ami                         = data.aws_ami.amazon_linux_2023.id
  instance_type               = var.instance_type
  key_name                    = aws_key_pair.ssh.key_name
  subnet_id                   = aws_subnet.public[0].id
  vpc_security_group_ids      = [aws_security_group.minikube_host.id]
  associate_public_ip_address = true
  user_data_base64            = data.cloudinit_config.minikube_bootstrap.rendered
  user_data_replace_on_change = true

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-minikube-host-${random_pet.suffix.id}"
  })
}

resource "aws_lb" "app" {
  name               = substr(replace("${var.project_name}-${random_pet.suffix.id}", "_", "-"), 0, 32)
  load_balancer_type = "application"
  internal           = false
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${random_pet.suffix.id}"
  })
}

resource "aws_lb_target_group" "app" {
  name        = substr(replace("${var.project_name}-tg-${random_pet.suffix.id}", "_", "-"), 0, 32)
  port        = var.app_host_port
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = aws_vpc.this.id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 15
    matcher             = "200"
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 3
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-tg-${random_pet.suffix.id}"
  })
}

resource "aws_lb_target_group_attachment" "minikube_host" {
  target_group_arn = aws_lb_target_group.app.arn
  target_id        = aws_instance.minikube_host.id
  port             = var.app_host_port
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

resource "aws_route53_record" "app" {
  count = local.route53_enabled ? 1 : 0

  zone_id = data.aws_route53_zone.app[0].zone_id
  name    = local.domain_name
  type    = "A"

  alias {
    name                   = aws_lb.app.dns_name
    zone_id                = aws_lb.app.zone_id
    evaluate_target_health = true
  }
}
