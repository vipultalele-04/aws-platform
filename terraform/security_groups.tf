# ══════════════════════════════════════════════════════════════════
# SECURITY GROUPS — 5 SGs enforcing strict access chain
#
#  Internet → sg-alb-external → sg-public-ec2
#                → sg-alb-internal → sg-private-ec2
#                                       → sg-rds
# ══════════════════════════════════════════════════════════════════

# ── SG 1: External ALB ───────────────────────────────────────────
resource "aws_security_group" "alb_external" {
  name        = "${var.project}-sg-alb-external"
  description = "External ALB: HTTP/HTTPS from internet"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = merge(local.common_tags, { Name = "${var.project}-sg-alb-external" })
}

# ── SG 2: Public EC2 ─────────────────────────────────────────────
resource "aws_security_group" "public_ec2" {
  name        = "${var.project}-sg-public-ec2"
  description = "Public EC2: from external ALB + SSH"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_external.id]
  }
  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_external.id]
  }
  ingress {
    description = "SSH — restrict to your IP in production"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]   # replace with your IP
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = merge(local.common_tags, { Name = "${var.project}-sg-public-ec2" })
}

# ── SG 3: Internal ALB ───────────────────────────────────────────
resource "aws_security_group" "alb_internal" {
  name        = "${var.project}-sg-alb-internal"
  description = "Internal ALB: only from public EC2 SG"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.public_ec2.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = merge(local.common_tags, { Name = "${var.project}-sg-alb-internal" })
}

# ── SG 4: Private EC2 ────────────────────────────────────────────
resource "aws_security_group" "private_ec2" {
  name        = "${var.project}-sg-private-ec2"
  description = "Private EC2: from internal ALB + SSH from public EC2"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_internal.id]
  }
  ingress {
    description     = "SSH via jump from public EC2"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.public_ec2.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = merge(local.common_tags, { Name = "${var.project}-sg-private-ec2" })
}

# ── SG 5: RDS ────────────────────────────────────────────────────
resource "aws_security_group" "rds" {
  name        = "${var.project}-sg-rds"
  description = "RDS: port 3306 only from private EC2 SG"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.private_ec2.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = merge(local.common_tags, { Name = "${var.project}-sg-rds" })
}
