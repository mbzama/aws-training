# AWS DMS Learning Lab

A Terraform-based lab environment for learning AWS Database Migration Service (DMS). This project provisions two PostgreSQL RDS instances (source and destination), configures a DMS replication instance, and runs a full-load migration — all as code.

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                     AWS (us-east-1)                     │
│                                                         │
│  ┌──────────────┐    ┌─────────────────┐    ┌────────────────────┐  │
│  │  source-rds  │───▶│ DMS Replication │───▶│ destination-rds  │  │
│  │  (postgres)  │    │    Instance     │    │   (postgres)     │  │
│  │  db.t3.micro │    │  dms.t3.medium  │    │  db.t3.micro     │  │
│  └──────────────┘    └─────────────────┘    └────────────────────┘  │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

**Source database contains:**
- `public.customers` — 8,500 rows of synthetic customer data
- `hrms.users_test` — 10 employee records for DMS testing

---

## Prerequisites

| Tool | Version |
|------|---------|
| Terraform | >= 1.5 |
| AWS CLI | >= 2.x (configured with credentials) |
| Python | >= 3.9 |
| psycopg2-binary | `pip install psycopg2-binary` |

**AWS permissions required:** RDS, DMS, IAM, VPC, CloudWatch

---

## Project Structure

```
aws-dms/
├── main.tf              # VPC, security groups, RDS instances, parameter group
├── dms.tf               # DMS replication instance, endpoints, migration task
├── variables.tf         # Input variables
├── outputs.tf           # Endpoint URLs, ARNs
└── populate_source.py   # Script to seed source RDS with test data
```

---

## Step-by-Step Setup

### 1. Clone and initialise Terraform

```bash
git clone <repo-url>
cd aws-dms
terraform init
```

### 2. Provision infrastructure

```bash
terraform apply -var="db_password=<YOUR_DB_PASSWORD>"
```

This creates:
- `source-rds` — PostgreSQL 16, `db.t3.micro`, logical replication enabled
- `destination-rds` — PostgreSQL 16, `db.t3.micro`
- DMS replication instance (`dms.t3.medium`)
- DMS source and destination endpoints (SSL enabled)
- DMS migration task (full-load, both `public` and `hrms` schemas)

> RDS instances take ~8 minutes to provision. The DMS replication instance takes a further ~8 minutes.

### 3. Set up the DMS migration user on source RDS

Connect to source RDS and run:

```sql
-- Create dedicated DMS user
CREATE USER dms_migration_user WITH PASSWORD '<YOUR_DMS_PASSWORD>';

-- Required for CDC replication slot creation on RDS PostgreSQL
GRANT rds_replication TO dms_migration_user;

-- Database access
GRANT CONNECT ON DATABASE dmsdb TO dms_migration_user;

-- Schema and table access
GRANT USAGE ON SCHEMA public TO dms_migration_user;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO dms_migration_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO dms_migration_user;

GRANT USAGE ON SCHEMA hrms TO dms_migration_user;
GRANT SELECT ON ALL TABLES IN SCHEMA hrms TO dms_migration_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA hrms GRANT SELECT ON TABLES TO dms_migration_user;
```

### 4. Create source schema and seed data

```bash
# Install Python dependency
python3 -m venv .venv && .venv/bin/pip install psycopg2-binary

# Populate public.customers with 5,000 records
.venv/bin/python3 populate_source.py \
  --host $(terraform output -raw source_rds_endpoint) \
  --password <YOUR_DB_PASSWORD>
```

Create the `hrms` schema and `users_test` table:

```sql
CREATE SCHEMA IF NOT EXISTS hrms;

CREATE TABLE hrms.users_test (
    id            SERIAL PRIMARY KEY,
    first_name    VARCHAR(50)   NOT NULL,
    last_name     VARCHAR(50)   NOT NULL,
    email         VARCHAR(150)  NOT NULL UNIQUE,
    department    VARCHAR(100),
    job_title     VARCHAR(100),
    salary        NUMERIC(10,2),
    hire_date     DATE,
    is_active     BOOLEAN       DEFAULT TRUE,
    created_at    TIMESTAMP     DEFAULT CURRENT_TIMESTAMP
);
```

### 5. Test endpoint connections

```bash
# Get endpoint ARNs
SOURCE_ENDPOINT=$(aws dms describe-endpoints \
  --filters Name=endpoint-id,Values=source-postgres \
  --query 'Endpoints[0].EndpointArn' --output text)

DEST_ENDPOINT=$(aws dms describe-endpoints \
  --filters Name=endpoint-id,Values=destination-postgres \
  --query 'Endpoints[0].EndpointArn' --output text)

REP_INSTANCE=$(terraform output -raw dms_replication_instance_arn)

# Trigger connection tests
aws dms test-connection --replication-instance-arn $REP_INSTANCE --endpoint-arn $SOURCE_ENDPOINT
aws dms test-connection --replication-instance-arn $REP_INSTANCE --endpoint-arn $DEST_ENDPOINT

# Poll until both show 'successful'
aws dms describe-connections \
  --filters Name=replication-instance-arn,Values=$REP_INSTANCE \
  --query 'Connections[].{Endpoint:EndpointIdentifier,Status:Status}' \
  --output table
```

### 6. Start the migration task

```bash
TASK_ARN=$(terraform output -raw dms_task_arn)

aws dms start-replication-task \
  --replication-task-arn $TASK_ARN \
  --start-replication-task-type start-replication
```

### 7. Monitor progress

```bash
aws dms describe-replication-tasks \
  --filters Name=replication-task-arn,Values=$TASK_ARN \
  --query 'ReplicationTasks[0].{Status:Status,TablesLoaded:ReplicationTaskStats.TablesLoaded,TablesErrored:ReplicationTaskStats.TablesErrored,Progress:ReplicationTaskStats.FullLoadProgressPercent}' \
  --output table
```

Expected output when complete:

```
-------------------------------------
|    DescribeReplicationTasks       |
+------------------+----------------+
|  Progress        |  100           |
|  Status          |  stopped       |
|  TablesErrored   |  0             |
|  TablesLoaded    |  2             |
+------------------+----------------+
```

### 8. Verify row counts on destination

```python
import psycopg2
conn = psycopg2.connect(host="<destination_endpoint>", port=5432,
                        user="dmsuser", password="<YOUR_DB_PASSWORD>", dbname="dmsdb")
cur = conn.cursor()
for schema, table in [("public", "customers"), ("hrms", "users_test")]:
    cur.execute(f"SELECT COUNT(*) FROM {schema}.{table}")
    print(f"{schema}.{table}: {cur.fetchone()[0]} rows")
```

---

## Configuration Reference

### variables.tf

| Variable | Default | Description |
|----------|---------|-------------|
| `aws_region` | `us-east-1` | AWS region |
| `db_name` | `dmsdb` | Database name on both RDS instances |
| `db_username` | `dmsuser` | Master RDS username |
| `db_password` | *(required)* | Master RDS password |
| `dms_username` | `dms_migration_user` | DMS source endpoint user |
| `dms_password` | *(required)* | DMS source endpoint password |
| `migration_type` | `full-load` | `full-load`, `cdc`, or `full-load-and-cdc` |

### Table Mappings

The DMS task migrates all tables from two schemas:

```json
{
  "rules": [
    {
      "rule-type": "selection",
      "rule-action": "include",
      "object-locator": { "schema-name": "public", "table-name": "%" }
    },
    {
      "rule-type": "selection",
      "rule-action": "include",
      "object-locator": { "schema-name": "hrms", "table-name": "%" }
    }
  ]
}
```

---

## Enabling CDC (Change Data Capture)

To migrate ongoing changes in addition to the initial full load:

1. Change `migration_type` variable to `full-load-and-cdc`:
   ```bash
   terraform apply -var="db_password=<YOUR_DB_PASSWORD>" -var="migration_type=full-load-and-cdc"
   ```

2. The source RDS parameter group already has `rds.logical_replication=1` and `wal_level=logical` enabled.

3. The `dms_migration_user` already has `rds_replication` role — DMS will automatically create a replication slot on the source.

4. Restart the task with `resume-processing` instead of `start-replication` for subsequent runs.

---

## Common Issues

| Symptom | Cause | Fix |
|---------|-------|-----|
| Stuck at "Preparing metadata" | Missing `rds_replication` role | `GRANT rds_replication TO dms_migration_user` |
| Connection test fails — `no pg_hba.conf entry` | DMS connecting without SSL | Set `ssl_mode = "require"` on endpoints (already configured) |
| `InvalidParameterValueException: Invalid ReplicationInstance class` | `dms.t3.micro` is not supported | Use `dms.t3.medium` or larger |
| `EntityAlreadyExists` for IAM roles | `dms-vpc-role` pre-exists in account | Import: `terraform import aws_iam_role.dms_vpc_role dms-vpc-role` |
| 0 rows migrated | Schema names in table mappings are case-sensitive | Ensure schema names match exactly (lowercase in PostgreSQL) |
| CDC not working | `wal_level` not set to `logical` | Confirm parameter group applied and instance rebooted |

---

## Teardown

```bash
terraform destroy -var="db_password=<YOUR_DB_PASSWORD>"
```

> This deletes both RDS instances, the DMS replication instance, endpoints, and task. Data is not recoverable (no final snapshots).

---

## Cost Estimate

| Resource | Type | Approx. cost |
|----------|------|-------------|
| source-rds | db.t3.micro | ~$0.016/hr |
| destination-rds | db.t3.micro | ~$0.016/hr |
| DMS replication instance | dms.t3.medium | ~$0.073/hr |
| **Total** | | **~$0.105/hr** |

Run `terraform destroy` when done to avoid ongoing charges.
