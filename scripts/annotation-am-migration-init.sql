
BEGIN;

CREATE TEMP TABLE stage (
    document_id	VARCHAR,
    access_type VARCHAR,
    user_id VARCHAR,
    annotation_id VARCHAR,
    permissions VARCHAR,
    resource_name VARCHAR
)
ON COMMIT DROP;

\COPY stage FROM 'am-migration.csv' DELIMITER ',' CSV HEADER;

WITH ins_services AS (
    INSERT INTO services
        SELECT 'Annotations' AS service_name, 'Service for annotations'
            AS service_description
    EXCEPT
        SELECT * FROM services
    RETURNING service_name
)
SELECT COUNT(*) AS "services inserts" FROM ins_services;

WITH ins_resources AS (
    INSERT INTO resources
        SELECT 'Annotations' AS service_name, 'ANNOTATION' AS resource_type,
            resource_name AS resource_name
        FROM stage
    EXCEPT
        SELECT * FROM resources
    RETURNING resource_name
)
SELECT COUNT(*) AS "resources inserts" FROM ins_resources;

COMMIT;
