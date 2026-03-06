data "aws_vpc" "default" {
    default = true
  
}
data "aws_subnets" "default" {
    filter {
      name = "vpc-id"
      values = [data.aws_vpc.default.id]
    }
  
}
resource "aws_security_group" "ec2_sg" {
    name = "network-monitoring-sg"
    description = "Security group for EC2 in default VPC"
    vpc_id = data.aws_vpc.default.id

    ingress {
        description = "SSH"
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        description = "Flask App"
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
        
    }
  
}

resource "aws_instance" "app_server" {

  ami = var.ami_id
  instance_type = var.instance_type
  key_name = var.key_name
  subnet_id = data.aws_subnets.default.ids[0]
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name
  associate_public_ip_address = true

  user_data = file("${path.module}/user_data.sh")

  tags= {
    Name = "CICD-App-Server"
  }



}