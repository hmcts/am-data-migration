
BEGIN;

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
)
ON COMMIT DROP;

\COPY stage FROM 'am-migration.csv' DELIMITER ',' CSV HEADER;

WITH ins_services AS (
    INSERT INTO services
        SELECT service_name, 'Service for annotations' AS service_description
        FROM stage
    EXCEPT
        SELECT * FROM services
    RETURNING service_name
)
SELECT COUNT(*) AS "services inserts" FROM ins_services;

WITH ins_resources AS (
    INSERT INTO resources
        SELECT service_name, resource_type, resource_name
        FROM stage
    EXCEPT
        SELECT * FROM resources
    RETURNING resource_name
)
SELECT COUNT(*) AS "resources inserts" FROM ins_resources;

WITH ins_roles AS (
    INSERT INTO roles
        SELECT relationship AS role_name, CAST('IDAM' AS ROLE_TYPE) AS role_type,
            CAST('PUBLIC' AS SECURITY_CLASSIFICATION) AS security_classification,
            CAST('EXPLICIT' AS ACCESS_TYPE) AS access_type
        FROM stage
        WHERE relationship IS NOT NULL
    EXCEPT
        SELECT * FROM roles
    RETURNING role_name
)
SELECT COUNT(*) AS "roles inserts" FROM ins_roles;

COMMIT;
