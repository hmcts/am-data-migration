
BEGIN;

DROP TABLE IF EXISTS access_management_migration_errors;
CREATE TABLE access_management_migration_errors (
    case_data_id VARCHAR,
    case_type_id VARCHAR,
    user_id VARCHAR,
    case_role VARCHAR
);

CREATE TEMP TABLE stage (
    case_data_id VARCHAR,
    case_type_id VARCHAR,
    user_id VARCHAR,
    case_role VARCHAR
);

ALTER TABLE access_management DROP CONSTRAINT access_management_unique;
ALTER TABLE access_management DROP CONSTRAINT access_management_resources_fkey;
ALTER TABLE access_management DROP CONSTRAINT relationship_fkey;

\COPY stage FROM 'am-migration.csv' DELIMITER ',' CSV HEADER;

SELECT COUNT(*) AS "rows to migrate" FROM stage;

SELECT COUNT(*) AS "pre-migration access_management count" FROM access_management;

WITH migration_errors AS (
    DELETE FROM stage
    WHERE case_data_id IS NULL
        OR case_type_id IS NULL
        OR user_id IS NULL
        OR case_role IS NULL
        OR case_type_id NOT IN (SELECT resource_name FROM resources)
        OR case_role NOT IN (SELECT role_name FROM roles)
    RETURNING *
)
INSERT INTO access_management_migration_errors SELECT * FROM migration_errors;

INSERT INTO access_management (resource_id, accessor_type, accessor_id,
        "attribute", permissions, service_name, resource_name,
        resource_type, relationship)
    SELECT s.case_data_id AS resource_id, 'USER' AS accessor_type,
        s.user_id AS accessor_id, '' AS "attribute", 0 AS permissions,
        r.service_name AS service_name, s.case_type_id AS resource_name,
        r.resource_type AS resource_type, s.case_role AS relationship
    FROM stage AS s, resources AS r
    WHERE r.resource_name = s.case_type_id
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
