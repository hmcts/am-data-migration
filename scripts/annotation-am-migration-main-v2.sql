
BEGIN;

DROP TABLE IF EXISTS access_management_migration_errors;
CREATE TABLE access_management_migration_errors (
    resource_id VARCHAR,
    accessor_type ACCESSOR_TYPE,
    accessor_id VARCHAR,
    attribute VARCHAR,
    permissions INTEGER,
    service_name VARCHAR,
    resource_name VARCHAR,
    resource_type VARCHAR,
    relationship VARCHAR
);

CREATE TEMP TABLE stage (
    resource_id VARCHAR,
    accessor_type ACCESSOR_TYPE,
    accessor_id VARCHAR,
    attribute VARCHAR,
    permissions INTEGER,
    service_name VARCHAR,
    resource_name VARCHAR,
    resource_type VARCHAR,
    relationship VARCHAR
);

ALTER TABLE access_management DROP CONSTRAINT access_management_unique;
ALTER TABLE access_management DROP CONSTRAINT access_management_resources_fkey;
ALTER TABLE access_management DROP CONSTRAINT relationship_fkey;

\COPY stage FROM 'am-migration.csv' DELIMITER ',' CSV HEADER;

SELECT COUNT(*) AS "rows to migrate" FROM stage;

UPDATE stage
SET resource_id = BTRIM(resource_id),
    accessor_id = BTRIM(accessor_id),
    attribute = BTRIM(attribute),
    service_name = BTRIM(service_name),
    resource_name = BTRIM(resource_name),
    resource_type = BTRIM(resource_type),
    relationship = BTRIM(relationship);

WITH file_duplicates AS (
    DELETE FROM stage a USING stage b
    WHERE a.ctid < b.ctid
        AND a.resource_id = b.resource_id
        AND a.accessor_type = b.accessor_type
        AND a.accessor_id = b.accessor_id
        AND a."attribute" = b."attribute"
        AND a.permissions = b.permissions
        AND a.service_name = b.service_name
        AND a.resource_name = b.resource_name
        AND a.resource_type = b.resource_type
        AND (a.relationship = b.relationship OR (a.relationship IS NULL AND b.relationship IS NULL))
    RETURNING *
)
SELECT COUNT(*) AS "duplicate rows in file (skipping)" FROM file_duplicates;

WITH access_management_duplicates AS (
    DELETE FROM stage a USING access_management b
    WHERE a.resource_id = b.resource_id
        AND a.accessor_type = b.accessor_type
        AND a.accessor_id = b.accessor_id
        AND a."attribute" = b."attribute"
        AND a.permissions = b.permissions
        AND a.service_name = b.service_name
        AND a.resource_name = b.resource_name
        AND a.resource_type = b.resource_type
        AND (a.relationship = b.relationship OR (a.relationship IS NULL AND b.relationship IS NULL))
    RETURNING *
)
SELECT COUNT(*) AS "duplicate rows in access_management table (skipping)" FROM access_management_duplicates;

SELECT COUNT(*) AS "pre-migration access_management count" FROM access_management;

WITH migration_errors AS (
    DELETE FROM stage
    WHERE resource_id IS NULL
        OR accessor_type IS NULL
        OR accessor_id IS NULL
        OR "attribute" IS NULL
        OR permissions IS NULL
        OR service_name IS NULL
        OR resource_name IS NULL
        OR resource_type IS NULL
        OR NOT EXISTS (SELECT service_name, resource_name, resource_type FROM resources AS r
            WHERE stage.service_name = r.service_name AND stage.resource_name = r.resource_name AND
            stage.resource_type = r.resource_type)
        OR (relationship IS NOT NULL AND relationship NOT IN (SELECT role_name FROM roles))
    RETURNING resource_id, accessor_type, accessor_id, "attribute", permissions, service_name, resource_name,
        resource_type, relationship
)
INSERT INTO access_management_migration_errors SELECT * FROM migration_errors;

INSERT INTO access_management (resource_id, accessor_type, accessor_id,
        "attribute", permissions, service_name, resource_name,
        resource_type, relationship)
    SELECT resource_id, accessor_type, accessor_id, "attribute", permissions, service_name, resource_name,
        resource_type, relationship
    FROM stage;

ALTER TABLE access_management ADD CONSTRAINT access_management_unique
    UNIQUE (resource_id, accessor_id, accessor_type, "attribute", resource_type,
        service_name, resource_name, relationship);
ALTER TABLE access_management ADD CONSTRAINT access_management_resources_fkey
    FOREIGN KEY (service_name, resource_type, resource_name)
    REFERENCES resources(service_name, resource_type, resource_name);
ALTER TABLE access_management ADD CONSTRAINT relationship_fkey
    FOREIGN KEY (relationship)
    REFERENCES roles(role_name);

COMMIT;

SELECT COUNT(*) AS "post-migration access_management count" FROM access_management;

SELECT COUNT(*) AS "migration errors" FROM access_management_migration_errors;

SELECT * FROM access_management_migration_errors LIMIT 100;

COMMIT;
