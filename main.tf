data "aws_vpc" "internship_vpc" {
  id = "vpc-01fc1ec68a8b03eb9"
}

data "aws_subnet" "public_subnet_1" {
  id = "subnet-0d4b3436fdda9803f"
}

data "aws_subnet" "public_subnet_2" {
  id = "subnet-09d1848907ea68bca"
}

data "aws_subnet" "private_subnet_1" {
  id = "subnet-0d5a03c63e1d24a17"
}

data "aws_subnet" "private_subnet_2" {
  id = "subnet-00ec5ce7c1e376323"
}

data "aws_nat_gateway" "NG2" {
  subnet_id = data.aws_subnet.public_subnet_2.id
}

data "aws_nat_gateway" "NG1" {
  subnet_id = data.aws_subnet.public_subnet_1.id
}

data "aws_internet_gateway" "default" {
  filter {
    name   = "attachment.vpc-id"
    values = [data.aws_vpc.internship_vpc.id]
  }
}

resource "aws_security_group" "alb_sg-nc" {
  name   = "alb-sg-nc"
  vpc_id = data.aws_vpc.internship_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ec2_sg-nc" {
  name   = "ec2-sg-nc"
  vpc_id = data.aws_vpc.internship_vpc.id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg-nc.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb" "alb-nc" {
  name               = "internship-alb-nc"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg-nc.id]
  subnets            = [data.aws_subnet.public_subnet_1.id, data.aws_subnet.public_subnet_2.id]
}

resource "aws_lb_target_group" "tg-nc" {
  name     = "internship-tg-nc"
  port     = 80
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.internship_vpc.id
}

resource "aws_lb_listener" "listener-http-nc" {
  load_balancer_arn = aws_lb.alb-nc.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "listener-https-nc" {
  load_balancer_arn = aws_lb.alb-nc.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"

  certificate_arn = "arn:aws:acm:us-east-2:253490770873:certificate/35306af0-a6fb-45fa-beec-bf298666882a" 

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg-nc.arn
  }
}


resource "aws_launch_template" "web_template-nc" {
  name          = "web-template-nc"
  image_id      = var.ami_id
  instance_type = var.instance_type

  user_data = base64encode(<<EOF
              #!/bin/bash
              yum update -y
              yum install -y httpd
              INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
              echo "<h1>web server INSTANCE_ID_PLACEHOLDER</h1>" > /var/www/html/index.html
              sed -i "s/INSTANCE_ID_PLACEHOLDER/$INSTANCE_ID/" /var/www/html/index.html
              systemctl start httpd
              systemctl enable httpd
              EOF
              )

  vpc_security_group_ids = [aws_security_group.ec2_sg-nc.id]
}

resource "aws_autoscaling_group" "asg-nc" {
  launch_template {
    id      = aws_launch_template.web_template-nc.id
    version = "$Latest"
  }

  min_size             = 2
  max_size             = 3
  desired_capacity     = 2
  vpc_zone_identifier  = [data.aws_subnet.private_subnet_1.id, data.aws_subnet.private_subnet_2.id]
  target_group_arns    = [aws_lb_target_group.tg-nc.arn]
  health_check_type    = "ELB"
  health_check_grace_period = 300
}

resource "aws_route53_record" "alb_record" {
  zone_id = var.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_lb.alb-nc.dns_name
    zone_id                = aws_lb.alb-nc.zone_id
    evaluate_target_health = true
  }
}
