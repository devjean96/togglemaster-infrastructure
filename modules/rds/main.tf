resource "aws_db_subnet_group" "this" {
  name       = "${var.name_prefix}-db-subnets"
  subnet_ids = var.subnet_ids
  tags       = merge(var.tags, { Name = "${var.name_prefix}-db-subnets" })
}

resource "aws_security_group" "this" {
  name_prefix = "${var.name_prefix}-postgres-"
  description = "PostgreSQL access from the ToggleMaster VPC"
  vpc_id      = var.vpc_id

  ingress {
    description = "PostgreSQL from VPC"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "Outbound traffic restricted to the ToggleMaster VPC"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-postgres-sg" })
}

resource "aws_db_instance" "this" {
  for_each = nonsensitive(toset(keys(var.databases)))

  identifier                          = "${var.name_prefix}-${each.value}"
  engine                              = "postgres"
  engine_version                      = var.engine_version
  instance_class                      = var.instance_class
  allocated_storage                   = var.allocated_storage
  max_allocated_storage               = var.max_allocated_storage
  storage_type                        = "gp3"
  storage_encrypted                   = true
  db_name                             = var.databases[each.value].database_name
  username                            = var.databases[each.value].username
  password                            = var.databases[each.value].password
  port                                = 5432
  db_subnet_group_name                = aws_db_subnet_group.this.name
  vpc_security_group_ids              = [aws_security_group.this.id]
  publicly_accessible                 = false
  backup_retention_period             = var.backup_retention_period
  multi_az                            = var.multi_az
  deletion_protection                 = var.deletion_protection
  skip_final_snapshot                 = var.skip_final_snapshot
  final_snapshot_identifier           = var.skip_final_snapshot ? null : "${var.name_prefix}-${each.value}-final"
  auto_minor_version_upgrade          = true
  iam_database_authentication_enabled = true
  performance_insights_enabled        = var.performance_insights_enabled
  apply_immediately                   = var.apply_immediately

  tags = merge(var.tags, { Name = "${var.name_prefix}-${each.value}" })
}
