terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}


provider "aws" {
  shared_config_files      = ["/home/ec2-user/.aws/config"]
  shared_credentials_files = ["/home/ec2-user/.aws/credentials"]
}


resource "aws_instance" "ec2" {
  ami                    = var.ami_value
  instance_type          = var.instance_type_value
  key_name               = aws_key_pair.p1_deployer.key_name
  subnet_id              = aws_subnet.p1_subnet.id
  vpc_security_group_ids = [aws_security_group.p1_sg.id]
  tags = {
    Name = "p1"
  }

  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = file("~/.ssh/id_rsa")
    host        = self.public_ip
  }

  provisioner "file" {
    source      = "~/app.py"
    destination = "/home/ec2-user/app.py"
  }
  provisioner "remote-exec" {
    inline = [
      "echo 'Hello from the remote instance'",
      "sudo yum update all",
      "sudo yum install -y python3",
      "sudo pip3 install flask",
      "cd /home/ec2-user",
      "sudo python3 app.py &"
    ]
  }
}


resource "aws_vpc" "p1_vpc" {
  cidr_block = var.cidr_block_value
}

resource "aws_subnet" "p1_subnet" {
  vpc_id            = aws_vpc.p1_vpc.id
  cidr_block        = var.cidr_block_value
  availability_zone = "us-east-1a"

  map_public_ip_on_launch = true
  tags = {
    Name = "p1-subnet"
  }
}



resource "aws_internet_gateway" "p1_gw" {
  vpc_id = aws_vpc.p1_vpc.id
  tags = {
    Name = "p1-igw"
  }
}


resource "aws_route_table" "p1_rt" {
  vpc_id = aws_vpc.p1_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.p1_gw.id
  }

  tags = {
    Name = "p1-rt"
  }

}

resource "aws_route_table_association" "p1" {
  subnet_id      = aws_subnet.p1_subnet.id
  route_table_id = aws_route_table.p1_rt.id
}


resource "aws_security_group" "p1_sg" {
  name        = "p1"
  description = "Allow inbound traffic"
  vpc_id      = aws_vpc.p1_vpc.id

  ingress {
    description = "SSH from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP from VPC"
    from_port   = 80
        to_port     = 80
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
    Name = "p1-sg"
  }
}

resource "aws_key_pair" "p1_deployer" {
  key_name   = "terraform-key-p1"
  public_key = file("~/.ssh/id_rsa.pub")

}

              
