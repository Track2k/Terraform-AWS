provider "aws" {
  access_key = var.access_key
  secret_key = var.secret_key
  region     = "us-east-1"
}

resource "aws_vpc" "vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "Terraform-VPC"

  }
}

resource "aws_subnet" "Public-subnet-A" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "10.0.0.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "TF Public Subnet A"
  }


}
resource "aws_subnet" "Public-subnet-B" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true
  tags = {
    Name = "TF Public Subnet B"
  }


}

resource "aws_subnet" "Private-subnet-A" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "10.0.16.0/20"
  availability_zone = "us-east-1a"
  tags = {
    Name = "TF Private Subnet A"
  }
}

resource "aws_subnet" "Private-subnet-B" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "10.0.32.0/20"
  availability_zone = "us-east-1b"
  tags = {
    Name = "TF Private Subnet B"
  }
}

resource "aws_internet_gateway" "Internet-Gateway" {

  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "TF-IGW"
  }

}

resource "aws_route_table" "public-routes" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.Internet-Gateway.id
  }
  route {
    cidr_block = "10.0.0.0/16"
    gateway_id = "local"
  }
  tags = {
    Name = "Public-Routes"
  }
}


resource "aws_route_table_association" "PublicAssociationA" {
  subnet_id      = aws_subnet.Public-subnet-A.id
  route_table_id = aws_route_table.public-routes.id

}

resource "aws_route_table_association" "PublicAssociationB" {
  subnet_id      = aws_subnet.Public-subnet-B.id
  route_table_id = aws_route_table.public-routes.id

}

resource "aws_route_table" "Private-routes" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block = "10.0.0.0/16"
    gateway_id = "local"

  }
  tags = {
    Name = "Private-Routes"
  }


}

resource "aws_route_table_association" "PrivateRouteAssociationA" {
  subnet_id      = aws_subnet.Private-subnet-A.id
  route_table_id = aws_route_table.Private-routes.id

}

resource "aws_route_table_association" "PrivateRouteAssociationB" {
  subnet_id      = aws_subnet.Private-subnet-B.id
  route_table_id = aws_route_table.Private-routes.id

}


# private instance on AZ-1a"
resource "aws_instance" "Private-server-a" {
  ami               = "ami-0e86e20dae9224db8"
  availability_zone = "us-east-1a"
  subnet_id         = aws_subnet.Private-subnet-A.id
  instance_type     = "t2.micro"
  security_groups   = []

  tags = {
    Name = "TF-Web-Server-A"
  }
}

# Private instance on AZ-1b"
resource "aws_instance" "Private-server-b" {
  ami               = "ami-0e86e20dae9224db8"
  availability_zone = "us-east-1b"
  subnet_id         = aws_subnet.Private-subnet-A.id
  instance_type     = "t2.micro"
  security_groups   = []

  tags = {
    Name = "TF-Web-Server-B"
  }
}

# EC2 security group to allow inbound http and https from internet facing ALB
resource "aws_security_group" "private-server-sg" {
  vpc_id      = aws_vpc.vpc.id
  description = "to allow internet to connect to private webservers through ALB"

  ingress {

    from_port   = 22
    to_port     = 22
    description = "ssh"
    protocol    = "tcp"
    security_groups = [aws_security_group.internetfacingALB-sg]
  }
  ingress {

    from_port   = 80
    to_port     = 80
    description = "http"
    protocol    = "tcp"
    security_groups = [aws_security_group.internetfacingALB-sg]
  }
  ingress {

    from_port   = 443
    to_port     = 443
    description = "https"
    protocol    = "tcp"
    security_groups = [aws_security_group.internetfacingALB-sg]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "Terraform Webserver-sg"
  }
}

resource "aws_lb" "internetfacingALB" {
  internal = false
  load_balancer_type = "application"
  security_groups = [aws_security_group.internetfacingALB-sg.id]
  subnets = [ aws_subnet.Public-subnet-A.id, aws_subnet.Public-subnet-B.id ]
  
}

resource "aws_security_group" "internetfacingALB-sg" {
  vpc_id      = aws_vpc.vpc.id
  description = "to allow internet to connect to private webservers through ALB"

  ingress {

    from_port   = 80
    to_port     = 80
    description = "http"
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
    ingress {

    from_port   = 443
    to_port     = 443
    description = "https"
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
    Name = "Terraform-ALB-Sg"
  }
}


resource "aws_security_group" "Db-sg" {
  vpc_id      = aws_vpc.vpc.id
  description = "db sg"

  ingress {

    from_port       = "3306"
    to_port         = "3306"
    protocol        = "tcp"
    description     = "Mysql access"
    security_groups = [aws_security_group.private-server-sg.id]
  }

}

resource "aws_db_subnet_group" "db_subnetgrp" {
  name       = "dbsubnetgrp"
  subnet_ids = [aws_subnet.Private-subnet-A.id, aws_subnet.Private-subnet-B.id]

}

resource "aws_db_instance" "TF" {
  allocated_storage      = 10
  db_name                = "mydb"
  engine                 = "mysql"
  engine_version         = "8.0.35"
  instance_class         = "db.t3.micro"
  username               = "admin"
  password               = "admin123"
  parameter_group_name   = "default.mysql8.0"
  skip_final_snapshot    = true
  storage_encrypted      = false
  vpc_security_group_ids = [aws_security_group.Db-sg.id]
  db_subnet_group_name   = aws_db_subnet_group.db_subnetgrp.name
}





