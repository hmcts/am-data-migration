
BEGIN;

CREATE TEMP TABLE stage
(
    case_data_id VARCHAR, case_type_id VARCHAR,
    user_id VARCHAR, case_role VARCHAR
)
ON COMMIT DROP;

\COPY stage FROM 'am-migration.csv' DELIMITER ',' CSV HEADER;

WITH ins_services AS
(
    INSERT INTO services
        SELECT case_type_id AS service_name,
            concat(case_type_id, ' sample description') AS service_description
        FROM stage
        GROUP BY service_name
    EXCEPT
        SELECT * FROM services
    RETURNING service_name
)
SELECT COUNT(*) AS "services inserts" FROM ins_services;

WITH ins_resources AS
(
    INSERT INTO resources
        SELECT case_type_id AS service_name, 'CASE' AS resource_type,
            case_type_id AS resource_name
        FROM stage
        GROUP BY resource_name
    EXCEPT
        SELECT * FROM resources
    RETURNING resource_name
)
SELECT COUNT(*) AS "resources inserts" FROM ins_resources;

WITH ins_resource_attributes AS
(
    INSERT INTO resource_attributes
        SELECT service_name, resource_type, resource_name, '' AS "attribute",
            'PUBLIC' as default_security_classification
        FROM resources
    EXCEPT
        SELECT * FROM resource_attributes
    RETURNING resource_name
)
SELECT COUNT(*) AS "resource_attributes inserts" FROM ins_resource_attributes;

WITH ins_roles AS
(
    INSERT INTO roles
        SELECT case_role AS role_name, 'RESOURCE' AS role_type,
            'PUBLIC' AS security_classification, 'ROLE_BASED' AS access_type
        FROM stage
        GROUP BY role_name
    EXCEPT
        SELECT * FROM roles
    RETURNING role_name
)
SELECT COUNT(*) AS "roles inserts" FROM ins_roles;

WITH ins_default_permissions_for_roles AS
(
    INSERT INTO default_permissions_for_roles
        SELECT re.service_name AS service_name, re.resource_type AS resource_type,
            re.resource_name AS resource_name, '' AS "attribute",
            ro.role_name AS role_name, '2' AS permissions
        FROM resources AS re, roles AS ro
    EXCEPT
        SELECT * FROM default_permissions_for_roles
    RETURNING resource_name
)
SELECT COUNT(*) AS "default_permissions_for_roles inserts" FROM ins_default_permissions_for_roles;

COMMIT;
