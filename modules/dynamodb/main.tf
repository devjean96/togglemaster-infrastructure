resource "aws_dynamodb_table" "this" {
  name         = var.table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "event_id"
  range_key    = "occurred_at"

  attribute {
    name = "event_id"
    type = "S"
  }

  attribute {
    name = "occurred_at"
    type = "S"
  }

  point_in_time_recovery {
    enabled = var.point_in_time_recovery_enabled
  }

  server_side_encryption {
    enabled = true
  }

  tags = var.tags
}

