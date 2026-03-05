variable "aws_region" {
    default = "us-east-1"
  
}
variable "instance_type" {
    default = "t3.micro"
  
}
variable "key_name" {
    description = "Your EC2 key pair name"
    type = string
  
}
variable "ami_id" {
    description = "Amazon linux 2023 AMI"
    type = string
  
}