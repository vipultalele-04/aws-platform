# ══════════════════════════════════════════════════════════════════
# RDS — Primary instance + Read Replica
# ══════════════════════════════════════════════════════════════════

resource "aws_db_subnet_group" "main" {
  name       = "${var.project}-db-subnet-group"
  subnet_ids = aws_subnet.db[*].id
  tags       = merge(local.common_tags, { Name = "${var.project}-db-subnet-group" })
}

resource "aws_db_parameter_group" "main" {
  name   = "${var.project}-db-params"
  family = "mysql8.0"

  parameter {
    name  = "character_set_server"
    value = "utf8mb4"
  }
  parameter {
    name  = "max_connections"
    value = "200"
  }
  tags = merge(local.common_tags, { Name = "${var.project}-db-params" })
}

# ── Primary RDS ───────────────────────────────────────────────────
resource "aws_db_instance" "primary" {
  identifier              = "${var.project}-rds-primary"
  engine                  = var.db_engine
  engine_version          = var.db_engine_version
  instance_class          = var.db_instance_class
  allocated_storage       = var.db_allocated_storage
  max_allocated_storage   = 100
  storage_type            = "gp3"
  storage_encrypted       = true
  db_name                 = var.db_name
  username                = var.db_username
  password                = var.db_password
  parameter_group_name    = aws_db_parameter_group.main.name
  db_subnet_group_name    = aws_db_subnet_group.main.name
  vpc_security_group_ids  = [aws_security_group.rds.id]
  multi_az                = false
  publicly_accessible     = false
  deletion_protection     = false
  skip_final_snapshot     = true
  backup_retention_period = 7
  backup_window           = "03:00-04:00"
  maintenance_window      = "sun:04:30-sun:05:30"
  copy_tags_to_snapshot   = true
  tags = merge(local.common_tags, { Name = "${var.project}-rds-primary", Role = "primary" })
}

# ── Read Replica ──────────────────────────────────────────────────
resource "aws_db_instance" "replica" {
  count                  = var.enable_read_replica ? 1 : 0
  identifier             = "${var.project}-rds-replica"
  instance_class         = var.db_instance_class
  storage_encrypted      = true
  replicate_source_db    = aws_db_instance.primary.identifier
  availability_zone      = var.availability_zones[1]
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false
  skip_final_snapshot    = true
  deletion_protection    = false
  backup_retention_period = 0
  tags = merge(local.common_tags, { Name = "${var.project}-rds-replica", Role = "replica" })
  depends_on = [aws_db_instance.primary]
}
