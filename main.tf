terraform {
  backend "s3" {
    bucket = "planb-backup-bucket"
    key    = "k8s-lab/terraform.tfstate"
    region = "us-east-1"
  }
}

#################################
# Automatic State Recovery (Fixed)
#################################

# Data source to check if state exists in S3 (updated from deprecated version)
data "aws_s3_object" "terraform_state" {
  bucket = "planb-backup-bucket"
  key    = "k8s-lab/terraform.tfstate"
}

# Local to determine if we need recovery
locals {
  # Only check for local state file existence
  local_state_exists = fileexists("terraform.tfstate")
}

# External data source to find latest backup (runs only when needed)
data "external" "latest_backup" {
  count = local.local_state_exists ? 0 : 1
  
  program = ["bash", "-c", "BACKUP=$(ls -t terraform-backups/terraform.tfstate.* 2>/dev/null | head -1); if [ -n \"$BACKUP\" ]; then echo \"{\\\"backup_file\\\": \\\"$BACKUP\\\"}\"; else echo '{\"backup_file\": \"\"}'; fi"]
}

# Resource to restore from backup if needed
resource "null_resource" "restore_state" {
  count = (!local.local_state_exists && data.external.latest_backup[0].result.backup_file != "") ? 1 : 0
  
  provisioner "local-exec" {
    command = "cp '${data.external.latest_backup[0].result.backup_file}' terraform.tfstate && echo '✅ State restored from backup: ${data.external.latest_backup[0].result.backup_file}'"
  }
}

provider "aws" {
  region = var.aws_region
}


#################################
# Generate SSH Key Pair
#################################

resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "private_key" {
  filename        = "k8s-lab-key.pem"
  content         = tls_private_key.ssh_key.private_key_pem
  file_permission = "0400"
}

resource "aws_key_pair" "generated" {
  key_name   = "k8s-lab-key"
  public_key = tls_private_key.ssh_key.public_key_openssh
}

#################################
# VPC + Networking
#################################

resource "aws_vpc" "k8s_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  tags = { 
    Name = "k8s-lab-vpc"
    Environment = "development"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.k8s_vpc.id
  tags = { Name = "k8s-lab-igw" }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.k8s_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "${var.aws_region}a"
  
  tags = { 
    Name = "k8s-lab-public-subnet"
  }
}

resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.k8s_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  
  tags = { Name = "k8s-lab-route-table" }
}

resource "aws_route_table_association" "assoc" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.rt.id
}

#################################
# Security Group
#################################

resource "aws_security_group" "k8s_sg" {
  name        = "k8s-lab-sg"
  description = "Security group for Kubernetes cluster"
  vpc_id      = aws_vpc.k8s_vpc.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "K8s API"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP (for applications)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS (for applications)"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "NodePort services"
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Internal cluster traffic"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    self        = true
  }

  ingress {
    description = "ICMP for debugging"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = { Name = "k8s-lab-sg" }
}

#################################
# Ubuntu 22.04 LTS AMI
#################################

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

#################################
# EC2 Instances with Resource Optimizations
#################################

resource "aws_instance" "master" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.master_instance_type
  subnet_id              = aws_subnet.public.id
  key_name               = aws_key_pair.generated.key_name
  vpc_security_group_ids = [aws_security_group.k8s_sg.id]
  
  root_block_device {
    volume_size = 30
    volume_type = "gp3"
    encrypted   = true
    tags = { Name = "k8s-master-root" }
  }
  
  user_data = file("master-bootstrap.sh")
  
  tags = { 
    Name        = "k8s-master"
    Environment = "development"
    Role        = "master"
  }
  
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }
}

resource "aws_instance" "workers" {
  count                  = var.worker_count
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.worker_instance_type
  subnet_id              = aws_subnet.public.id
  key_name               = aws_key_pair.generated.key_name
  vpc_security_group_ids = [aws_security_group.k8s_sg.id]
  
  root_block_device {
    volume_size = 40
    volume_type = "gp3"
    encrypted   = true
    tags = { Name = "k8s-worker-${count.index + 1}-root" }
  }
  
  user_data = file("worker-bootstrap.sh")
  
  tags = { 
    Name        = "k8s-worker-${count.index + 1}"
    Environment = "development"
    Role        = "worker"
  }
  
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }
}

