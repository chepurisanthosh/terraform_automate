
# Provider configuration

provider "aws" {
  region      = "us-east-2"
  access_key   = "AKIARQ22MT2VR23B5BW7"
  secret_key  = "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"
}

# VPC creation

resource "aws_vpc" "my_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "MyVPC"
  }
}

# Internet Gateway creation

resource "aws_internet_gateway" "my_igw" {
  vpc_id = aws_vpc.my_vpc.id
  tags = {
    Name = "MyInternetGateway"
  }
  
}

# Public subnet creation

resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-2a"
  map_public_ip_on_launch = true
  tags = {
    Name = "PublicSubnet"
  }
}

# Private subnet creation

resource "aws_subnet" "private_subnet" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-2b"
  tags = {
    Name = "PrivateSubnet_1"
  }
}
#private subnet-2 creation

resource "aws_subnet" "private_subnet_2" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = "10.0.3.0/24"
  availability_zone       = "us-east-2c"
  tags = {
    Name = "PrivateSubnet_2"
  }
}

# Public route table creation

resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.my_vpc.id
  tags = {
    Name = "PublicRouteTable"
  }
}

# Public route table association with public subnet

resource "aws_route_table_association" "public_route_table_association" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_route_table.id
}

# Private route table creation

resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.my_vpc.id
  tags = {
    Name = "PrivateRouteTable"
  }
}

# Private route table association with private subnet

resource "aws_route_table_association" "private_route_table_association" {
  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.private_route_table.id
}
# Private route table association with private subnet_2

resource "aws_route_table_association" "private_route_table_association_2" {
  subnet_id      = aws_subnet.private_subnet_2.id
  route_table_id = aws_route_table.private_route_table.id
}

# Public route table default route to Internet Gateway

resource "aws_route" "public_route" {
  route_table_id            = aws_route_table.public_route_table.id
  destination_cidr_block    = "0.0.0.0/0"
  gateway_id                = aws_internet_gateway.my_igw.id
  depends_on                = [aws_internet_gateway.my_igw]
}

# Elastic IP creation for NAT Gateway

resource "aws_eip" "my_eip" {
  domain = "vpc"
}

# NAT Gateway creation

resource "aws_nat_gateway" "my_nat_gateway" {
  allocation_id = aws_eip.my_eip.id
  subnet_id     = aws_subnet.public_subnet.id
}

# Private route table NAT gateway route

resource "aws_route" "private_route" {
  route_table_id            = aws_route_table.private_route_table.id
  destination_cidr_block    = "0.0.0.0/0"
  nat_gateway_id            = aws_nat_gateway.my_nat_gateway.id
  depends_on                = [aws_nat_gateway.my_nat_gateway]
}

#creating security group for ec2

resource "aws_security_group" "web_sg" {
  name   = "HTTP and SSH"
  vpc_id = aws_vpc.my_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#creating ec2 instance in public subnet

resource "aws_instance" "web_instance" {
  ami           = "ami-03f38e546e3dc59e1"
  instance_type = "t2.micro"
  key_name      = "santhosh"

  subnet_id                   = aws_subnet.public_subnet.id
  vpc_security_group_ids      = [aws_security_group.web_sg.id]
  associate_public_ip_address = true
  

  tags = {
    "Name" : "project-2"
  }
}

#security group for rds

resource "aws_security_group" "rds" {
  name        = "database_security_group"
  description = "enable mysql/aurora access on port 3306"
  vpc_id      = aws_vpc.my_vpc.id
  # Keep the instance private by only allowing traffic from the web server.
  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.web_sg.id]
  }
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # Allow all outbound traffic.
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

}

#creating database group

resource "aws_db_subnet_group" "database_subnet_group" {
  name        = "database-subnets"
  description = "subnets for database instance"
  subnet_ids  = [aws_subnet.private_subnet.id,aws_subnet.private_subnet_2.id]

 tags    = {
   Name  = "database-subnets"
 }
}

#rds instance

resource "aws_db_instance" "default" {
  identifier                = "dev-rds-instance"
  allocated_storage         = 10
  engine                    = "mysql"
  engine_version            = "8.0.31"
  multi_az                  = false
  instance_class            = "db.t2.micro"
  db_name                   = "applicationdb"
  username                  = "santhosh"
  password                  = "santhosh123"
  db_subnet_group_name      = aws_db_subnet_group.database_subnet_group.name
  vpc_security_group_ids    = [aws_security_group.rds.id]
  availability_zone         = "us-east-2b"
  skip_final_snapshot       = true
}
     
                                                                                                                                                 220,1         98
