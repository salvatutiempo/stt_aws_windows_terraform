####################################################
# DATA
####################################################
# Get latest Windows Server 2012R2 AMI
data "aws_ami" "windows-2012-r2" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    #values = ["Windows_Server-2012-R2_RTM-Spanish-64Bit-Base-*"]
  }
}

####################################################
# RESOURCES
####################################################

# Security Groups
####################################################

# Define the security group for the Windows server
resource "aws_security_group" "sg-windows" {
  name        = "windows-sg"
  description = "Allow incoming connections"  
  ingress {
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow incoming RDP connections"
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "windows-sg"
  }
}

# Private Key for Credentials
####################################################

resource "tls_private_key" "instance_key" {
  algorithm = "RSA"
}

resource "aws_key_pair" "instance_key_pair" {
  key_name   = "windows-instance-key"
  public_key = tls_private_key.instance_key.public_key_openssh
}

# Instances
####################################################

# Create EC2 Instance
resource "aws_instance" "windows-server" {
  # Instance info
  ami = data.aws_ami.windows-2012-r2.id
  instance_type = "t2.micro"

  # Public IP 
  associate_public_ip_address = true

  # Instance Credentials
  key_name                = aws_key_pair.instance_key_pair.key_name
  get_password_data = true

  # Security Group
  vpc_security_group_ids = [aws_security_group.sg-windows.id]

}

# Store Password
####################################################
resource "aws_ssm_parameter" "windows_ec2" {
  depends_on = [aws_instance.windows-server]
  name       = "/Instances/windows/windows-password"
  type       = "SecureString"
  value = rsadecrypt(aws_instance.windows-server.password_data, nonsensitive(tls_private_key.instance_key.private_key_pem))
}

####################################################
# OUTPUT
####################################################

# Windows Public IP 
output "windows_public_ip" {
  value = aws_instance.windows-server.public_ip
}

# Export Credentials to File
resource "local_file" "RDP_key" {
  filename = "windows_key.txt"
  content  = aws_ssm_parameter.windows_ec2.value
}
