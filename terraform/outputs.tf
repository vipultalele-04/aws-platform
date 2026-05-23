# ══════════════════════════════════════════════════════════════════
# OUTPUTS — used by GitHub Actions to build Ansible inventory
# ══════════════════════════════════════════════════════════════════

output "vpc_id" {
  value = aws_vpc.main.id
}

output "external_alb_dns" {
  description = "Public entry point — paste into browser to test"
  value       = aws_lb.external.dns_name
}

output "internal_alb_dns" {
  description = "Internal ALB — used by nginx on public EC2s"
  value       = aws_lb.internal.dns_name
}

output "public_ec2_public_ips" {
  description = "Public IPs of public EC2s (for Ansible + SSH)"
  value       = aws_instance.public[*].public_ip
}

output "public_ec2_private_ips" {
  value = aws_instance.public[*].private_ip
}

output "private_ec2_private_ips" {
  description = "Private IPs of private EC2s (for Ansible via jump)"
  value       = aws_instance.private[*].private_ip
}

output "rds_primary_endpoint" {
  description = "RDS primary endpoint (injected into Ansible app config)"
  value       = aws_db_instance.primary.address
}

output "rds_primary_port" {
  value = aws_db_instance.primary.port
}

output "rds_replica_endpoint" {
  value = var.enable_read_replica ? aws_db_instance.replica[0].address : "disabled"
}

output "nat_gateway_ip" {
  value = aws_eip.nat.public_ip
}
