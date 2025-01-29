resource "aws_vpc" "terraformvpc" {
  cidr_block = var.cidr
}

resource "aws_subnet" "sub1" {
  vpc_id                  = aws_vpc.terraformvpc.id
  cidr_block              = "10.0.0.0/24"
  availability_zone       = "ap-south-1a"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "sub2" {
  vpc_id                  = aws_vpc.terraformvpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "ap-south-1b"
  map_public_ip_on_launch = true
}

resource "aws_internet_gateway" "Igw" {
  vpc_id = aws_vpc.terraformvpc.id
}

resource "aws_route_table" "AR" {
  vpc_id = aws_vpc.terraformvpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.Igw.id
  }
}

resource "aws_route_table_association" "Artal" {
  subnet_id      = aws_subnet.sub1.id
  route_table_id = aws_route_table.AR.id
}

resource "aws_route_table_association" "Arta" {
  subnet_id      = aws_subnet.sub2.id
  route_table_id = aws_route_table.AR.id
}


resource "aws_security_group" "Mysg" {
  name   = "websg"
  vpc_id = aws_vpc.terraformvpc.id

  ingress {
    description = "HTTP from Vpc"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "web-sg"
  }
}

resource "aws_s3_bucket" "mySS3" {
  bucket = "terraform-project-bucket-s3"
}

resource "aws_s3_bucket_ownership_controls" "examples" {
  bucket = aws_s3_bucket.mySS3.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_instance" "webserver2" {
  ami                    = "ami-053b12d3152c0cc71"
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.Mysg.id]
  subnet_id              = aws_subnet.sub1.id
  user_data              = base64encode(file("userdata.sh"))
}

resource "aws_instance" "webserver3" {
  ami                    = "ami-053b12d3152c0cc71"
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.Mysg.id]
  subnet_id              = aws_subnet.sub2.id
  user_data              = base64encode(file("userdata1.sh"))
}

output "instance_public_ip_1" {
  value = aws_instance.webserver2.public_ip
}

output "instance_public_ip" {
  value = aws_instance.webserver3.public_ip
}

#Alb Creation

resource "aws_lb" "MYALB" {
  name               = "ArAlb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.Mysg.id]
  subnets            = [aws_subnet.sub1.id, aws_subnet.sub2.id]

  tags = {
    name = "web"
  }
}

resource "aws_lb_target_group" "targetgroup" {
  name     = "MyTargetgrp"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.terraformvpc.id

  health_check {
    path = "/"
    port = "traffic-port"
  }
}

resource "aws_lb_target_group_attachment" "Attach1" {
  target_group_arn = aws_lb_target_group.targetgroup.arn
  target_id        = aws_instance.webserver2.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "Attach2" {
  target_group_arn = aws_lb_target_group.targetgroup.arn
  target_id        = aws_instance.webserver3.id
  port             = 80
}

resource "aws_lb_listener" "listenergrp" {
  load_balancer_arn = aws_lb.MYALB.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.targetgroup.arn
    type             = "forward"
  }
}

output "loadbalancerdns" {
  value = aws_lb.MYALB.dns_name
}






    