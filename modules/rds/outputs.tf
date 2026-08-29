output "endpoints" {
  value = { for name, database in aws_db_instance.this : name => database.address }
}
output "ports" {
  value = { for name, database in aws_db_instance.this : name => database.port }
}
output "database_names" {
  value = { for name, database in aws_db_instance.this : name => database.db_name }
}
output "security_group_id" { value = aws_security_group.this.id }

