provider "aws" {
  region = "eu-west-1"
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = { 
    Name = "vpc-connectivity-demo"
    Environment = var.environment
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
  tags = { 
    Name = "igw-connectivity-demo"
    Environment = var.environment
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, 0)
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[0]
  tags = { 
    Name = "public-subnet"
    Environment = var.environment
  }
}

resource "aws_subnet" "private_bridge" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, 1)
  map_public_ip_on_launch = false
  availability_zone       = data.aws_availability_zones.available.names[0]
  tags = { 
    Name = "private-subnet-1"
    Environment = var.environment
  }
}

resource "aws_subnet" "private_isolated" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, 2)
  map_public_ip_on_launch = false
  availability_zone       = data.aws_availability_zones.available.names[1]
  tags = { 
    Name = "private-subnet-2"
    Environment = var.environment
  }
}

resource "aws_eip" "nat" {
  domain = "vpc"
  tags = { 
    Name = "nat-eip"
    Environment = var.environment
  }
}

resource "aws_nat_gateway" "gw" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id
  tags = { 
    Name = "nat-gateway"
    Environment = var.environment
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
  tags = { 
    Name = "public-rt"
    Environment = var.environment
  }
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private_bridge" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.gw.id
  }
  tags = { 
    Name = "private-rt-1-with-nat"
    Environment = var.environment
  }
}

resource "aws_route_table_association" "private_bridge_assoc" {
  subnet_id      = aws_subnet.private_bridge.id
  route_table_id = aws_route_table.private_bridge.id
}

resource "aws_route_table" "private_isolated" {
  vpc_id = aws_vpc.main.id
  tags = { 
    Name = "private-rt-2-no-internet"
    Environment = var.environment
  }
}

resource "aws_route_table_association" "private_isolated_assoc" {
  subnet_id      = aws_subnet.private_isolated.id
  route_table_id = aws_route_table.private_isolated.id
}

resource "aws_security_group" "icmp" {
  name        = "sg-icmp"
  description = "Allow ICMP"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [var.vpc_cidr, var.ping_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { 
    Name = "sg-icmp"
    Environment = var.environment
  }
}

resource "aws_security_group" "ssh_out_eic" {
  name        = "sg-ssh-eic"
  description = "Security group for EC2 Instance Connect Endpoint with outbound SSH to VPC only"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  tags = { 
    Name = "sg-ssh-eic"
    Environment = var.environment
  }
}

resource "aws_security_group" "ssh_ec2" {
  name        = "sg-ssh-ec2"
  description = "Allow SSH from VPC and EIC endpoint"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = [var.vpc_cidr]
    security_groups  = [aws_security_group.ssh_out_eic.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { 
    Name = "sg-ssh-ec2"
    Environment = var.environment
  }
  depends_on  = [ aws_security_group.ssh_out_eic ]
}

resource "aws_ec2_instance_connect_endpoint" "eic" {
  subnet_id          = aws_subnet.private_isolated.id
  security_group_ids = [aws_security_group.ssh_out_eic.id]
  preserve_client_ip = true
  tags = { 
    Name = "eic-endpoint"
    Environment = var.environment
  }
}

data "aws_availability_zones" "available" {}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "generated_key" {
  key_name   = "${var.environment}-connectivity-demo-key"
  public_key = tls_private_key.ssh_key.public_key_openssh
  
  tags = {
    Name = "connectivity-demo-key"
    Environment = var.environment
  }
}

resource "local_file" "private_key" {
  content         = tls_private_key.ssh_key.private_key_pem
  filename        = "${path.module}/${var.environment}-connectivity-demo-key.pem"
  file_permission = "0600"
}

resource "aws_instance" "public_instance" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.icmp.id, aws_security_group.ssh_ec2.id]
  key_name               = aws_key_pair.generated_key.key_name
  depends_on             = [ 
                            aws_subnet.public, 
                            aws_key_pair.generated_key, 
                            aws_security_group.ssh_ec2, 
                            aws_security_group.icmp 
                          ]
  
  user_data = <<-EOF
    #!/bin/bash
    echo "Public instance with direct internet access" > /home/ec2-user/instance-info.txt
  EOF

  tags = {
    Name = "public-instance"
    Environment = var.environment
  }
}

resource "aws_instance" "private_instance_with_nat" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.private_bridge.id
  vpc_security_group_ids = [aws_security_group.icmp.id, aws_security_group.ssh_ec2.id]
  key_name               = aws_key_pair.generated_key.key_name
  depends_on             = [ 
                            aws_subnet.private_bridge, 
                            aws_key_pair.generated_key, 
                            aws_security_group.ssh_ec2, 
                            aws_security_group.icmp 
                          ]
  
  user_data = <<-EOF
    #!/bin/bash
    echo "Private instance with NAT Gateway internet access" > /home/ec2-user/instance-info.txt
  EOF

  tags = {
    Name = "private-instance-with-nat"
    Environment = var.environment
  }
}

resource "aws_instance" "isolated_private_instance" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.private_isolated.id
  vpc_security_group_ids = [aws_security_group.icmp.id, aws_security_group.ssh_ec2.id]
  key_name               = aws_key_pair.generated_key.key_name
  depends_on             = [ 
                            aws_subnet.private_isolated, 
                            aws_key_pair.generated_key, 
                            aws_security_group.ssh_ec2, 
                            aws_security_group.icmp 
                          ]
  
  user_data = <<-EOF
    #!/bin/bash
    echo "Isolated private instance with no internet access" > /home/ec2-user/instance-info.txt
  EOF

  tags = {
    Name = "isolated-private-instance"
    Environment = var.environment
  }
}