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



resource "aws_instance" "Web-server" {
  ami               = "ami-0e86e20dae9224db8"
  availability_zone = "us-east-1a"
  subnet_id         = aws_subnet.Public-subnet-A.id
  instance_type     = "t2.micro"
  security_groups   = [aws_security_group.Webserversg.id]

  tags = {
    Name = "TF-Web-Server"
  }
}


resource "aws_security_group" "Webserversg" {
  vpc_id      = aws_vpc.vpc.id
  description = "to allow internet to connect to bastion host on public subnet A"

  ingress {

    from_port   = 22
    to_port     = 22
    description = "ssh"
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
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
    Name = "Terraform Webserver-sg"
  }
}

resource "aws_instance" "Bhost" {
  ami               = "ami-0e86e20dae9224db8"
  availability_zone = "us-east-1a"
  subnet_id         = aws_subnet.Public-subnet-A.id
  instance_type     = "t2.micro"
  security_groups   = [aws_security_group.Bastionhostsg.id]

  tags = {
    Name = "TFBastionHost"
  }
}

resource "aws_security_group" "Bastionhostsg" {
  vpc_id      = aws_vpc.vpc.id
  description = "to allow internet to connect to bastion host on public subnet A"

  ingress {

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
    Name = "Terraform Bhost-sg"
  }
}

resource "aws_instance" "TF_privateInstance" {
  ami               = "ami-0e86e20dae9224db8"
  availability_zone = "us-east-1a"
  subnet_id         = aws_subnet.Private-subnet-A.id
  instance_type     = "t2.micro"
  security_groups   = [aws_security_group.TF_privateinstance_sg.id]
  key_name          = "PrivateInstancekey"
  tags = {
    Name = "TF-PrivateInstance"
  }
}

resource "aws_security_group" "TF_privateinstance_sg" {
  vpc_id      = aws_vpc.vpc.id
  description = "to connect to bastion host sg"

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.Bastionhostsg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "Terraform Priv-Instance-sg"
  }

}
