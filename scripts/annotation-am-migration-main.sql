
BEGIN;

DROP TABLE IF EXISTS access_management_migration_errors;
CREATE TABLE access_management_migration_errors (
    document_id	VARCHAR,
    accessor_type ACCESSOR_TYPE,
    user_id VARCHAR,
    annotation_id VARCHAR,
    permissions VARCHAR,
    resource_name VARCHAR
);

CREATE TEMP TABLE stage (
    document_id	VARCHAR,
    accessor_type ACCESSOR_TYPE,
    user_id VARCHAR,
    annotation_id VARCHAR,
    permissions VARCHAR,
    resource_name VARCHAR
);

ALTER TABLE access_management DROP CONSTRAINT access_management_unique;
ALTER TABLE access_management DROP CONSTRAINT access_management_resources_fkey;
ALTER TABLE access_management DROP CONSTRAINT relationship_fkey;

\COPY stage FROM 'am-migration.csv' DELIMITER ',' CSV HEADER;

ALTER TABLE stage ADD COLUMN permissions_int INTEGER DEFAULT 0;
UPDATE stage SET permissions_int = permissions_int + 1
WHERE permissions LIKE '%CREATE%';
UPDATE stage SET permissions_int = permissions_int + 2
WHERE permissions LIKE '%READ%';
UPDATE stage SET permissions_int = permissions_int + 4
WHERE permissions LIKE '%UPDATE%';
UPDATE stage SET permissions_int = permissions_int + 8
WHERE permissions LIKE '%DELETE%';

SELECT COUNT(*) AS "rows to migrate" FROM stage;

WITH file_duplicates AS (
    DELETE FROM stage a USING stage b
    WHERE a.ctid < b.ctid
        AND a.document_id = b.document_id
        AND a.accessor_type = b.accessor_type
        AND a.user_id = b.user_id
        AND a.annotation_id = b.annotation_id
        AND a.permissions = b.permissions
        AND a.resource_name = b.resource_name
    RETURNING *
)
SELECT COUNT(*) AS "duplicate rows in file (skipping)" FROM file_duplicates;

WITH access_management_duplicates AS (
    DELETE FROM stage a USING access_management b
    WHERE a.document_id = b.resource_id
        AND a.accessor_type = b.accessor_type
        AND a.user_id = b.accessor_id
        AND a.annotation_id = b."attribute"
        AND a.permissions_int = b.permissions
        AND a.resource_name = b.resource_name
        AND b.resource_type = 'ANNOTATION'
    RETURNING *
)
SELECT COUNT(*) AS "duplicate rows in access_management table (skipping)" FROM access_management_duplicates;

SELECT COUNT(*) AS "pre-migration access_management count" FROM access_management;

WITH migration_errors AS (
    DELETE FROM stage
    WHERE document_id IS NULL
        OR accessor_type IS NULL
        OR user_id IS NULL
        OR annotation_id IS NULL
        OR permissions IS NULL
        OR resource_name IS NULL
        OR resource_name NOT IN (SELECT resource_name FROM resources)
    RETURNING document_id, accessor_type, user_id, annotation_id, permissions,
        resource_name
)
INSERT INTO access_management_migration_errors SELECT * FROM migration_errors;

INSERT INTO access_management (resource_id, accessor_type, accessor_id,
        "attribute", permissions, service_name, resource_name,
        resource_type, relationship)

    SELECT s.document_id AS resource_id, s.accessor_type AS accessor_type,
        s.user_id AS accessor_id, s.annotation_id AS "attribute",
        s.permissions_int AS permissions, 'Annotations' AS service_name,
        s.resource_name AS resource_name, 'ANNOTATION' AS resource_type,
        null AS relationship
    FROM stage AS s
EXCEPT
    SELECT resource_id, accessor_type, accessor_id, "attribute",
        permissions, service_name, resource_name, resource_type,
        relationship
    FROM access_management;

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
