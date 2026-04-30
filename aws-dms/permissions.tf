# -------------------------------------------------------
# DMS migration user — created and granted on source DB
# -------------------------------------------------------

resource "postgresql_role" "dms_migration_user" {
  name     = var.dms_username
  password = var.dms_password
  login    = true

  depends_on = [aws_rds_cluster_instance.source]
}

# Grant rds_replication role — required for DMS to create replication slots
resource "postgresql_grant_role" "dms_replication" {
  role              = postgresql_role.dms_migration_user.name
  grant_role        = "rds_replication"

  depends_on = [postgresql_role.dms_migration_user]
}

# Grant CONNECT on the database
resource "postgresql_grant" "dms_connect" {
  role        = postgresql_role.dms_migration_user.name
  database    = var.db_name
  object_type = "database"
  privileges  = ["CONNECT"]

  depends_on = [postgresql_role.dms_migration_user]
}

# Grant USAGE + SELECT on public schema
resource "postgresql_grant" "dms_public_schema_usage" {
  role        = postgresql_role.dms_migration_user.name
  database    = var.db_name
  schema      = "public"
  object_type = "schema"
  privileges  = ["USAGE"]

  depends_on = [postgresql_role.dms_migration_user]
}

resource "postgresql_grant" "dms_public_tables" {
  role        = postgresql_role.dms_migration_user.name
  database    = var.db_name
  schema      = "public"
  object_type = "table"
  privileges  = ["SELECT"]

  depends_on = [postgresql_role.dms_migration_user]
}

# Grant USAGE + SELECT on hrms schema
resource "postgresql_grant" "dms_hrms_schema_usage" {
  role        = postgresql_role.dms_migration_user.name
  database    = var.db_name
  schema      = "hrms"
  object_type = "schema"
  privileges  = ["USAGE"]

  depends_on = [postgresql_role.dms_migration_user]
}

resource "postgresql_grant" "dms_hrms_tables" {
  role        = postgresql_role.dms_migration_user.name
  database    = var.db_name
  schema      = "hrms"
  object_type = "table"
  privileges  = ["SELECT"]

  depends_on = [postgresql_role.dms_migration_user]
}
