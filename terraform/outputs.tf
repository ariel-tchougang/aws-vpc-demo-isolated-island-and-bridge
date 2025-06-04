output "vpc_id" {
  value       = aws_vpc.main.id
  description = "VPC ID"
}

output "public_subnet_id" {
  value       = aws_subnet.public.id
  description = "Public Subnet ID"
}

output "private_bridge_subnet_id" {
  value       = aws_subnet.private_bridge.id
  description = "Private Subnet 1"
}

output "private_isolated_subnet_id" {
  value       = aws_subnet.private_isolated.id
  description = "Private Subnet 2"
}

output "nat_gateway_id" {
  value       = aws_nat_gateway.gw.id
  description = "NAT Gateway ID"
}

output "eic_endpoint_id" {
  value       = aws_ec2_instance_connect_endpoint.eic.id
  description = "EC2 Instance Connect Endpoint ID"
}

output "public_instance_id" {
  value       = aws_instance.public_instance.id
  description = "Public Instance ID"
}

output "private_instance_with_nat_id" {
  value       = aws_instance.private_instance_with_nat.id
  description = "Private Instance with NAT ID"
}

output "isolated_private_instance_id" {
  value       = aws_instance.isolated_private_instance.id
  description = "Isolated Private Instance ID"
}

output "key_pair_id" {
  value       = aws_key_pair.generated_key.id
  description = "Key Pair ID"
}

output "key_pair_name" {
  value       = aws_key_pair.generated_key.key_name
  description = "Key Pair Name"
}

output "private_key_file" {
  value       = local_file.private_key.filename
  description = "Path to the private key file"
}