# ══════════════════════════════════════════════════════════════════
# EC2 INSTANCES — 2 public + 2 private
# ══════════════════════════════════════════════════════════════════

# ── Public EC2 (nginx reverse proxy → internal ALB) ───────────────
resource "aws_instance" "public" {
  count                       = 2
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public[count.index].id
  vpc_security_group_ids      = [aws_security_group.public_ec2.id]
  key_name                    = var.key_name
  associate_public_ip_address = true

  # Minimal bootstrap — Ansible handles full config
  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y python3
    # Tag instance so Ansible can identify it
    echo "public-ec2-${count.index + 1}" > /etc/instance-role
  EOF

  tags = merge(local.common_tags, {
    Name = "${var.project}-public-ec2-${count.index + 1}"
    Role = "public"
  })

  depends_on = [aws_lb.internal]
}

# ── Private EC2 (app server :8080 → RDS) ─────────────────────────
resource "aws_instance" "private" {
  count                       = 2
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.private[count.index].id
  vpc_security_group_ids      = [aws_security_group.private_ec2.id]
  key_name                    = var.key_name
  associate_public_ip_address = false

  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y python3
    echo "private-ec2-${count.index + 1}" > /etc/instance-role
  EOF

  tags = merge(local.common_tags, {
    Name = "${var.project}-private-ec2-${count.index + 1}"
    Role = "private"
  })
}
