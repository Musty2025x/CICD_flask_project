output "eip_public_ip" {
    description = "The EIP"
    value = aws_eip.app_ip.public_ip
  
}