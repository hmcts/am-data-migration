# Access Management Data Migration Service

## Purpose

The Access Management Data Migration Service provides a Jenkins pipeline for automated data migration to the Access Management database.

The pipeline:
 - reads the migration data file from Azure Blob Storage
 - reads the migration script from this repository
 - carries out the data migration to the Access Management database in the specified environment (eg. `aat`, `prod`)

## Uploading the migration data file

The pipeline will download the migration data file from the following location in Azure Storage Accounts:
 - Storage account: `ammigrationdata`
 - Container: `data`

Upload the migration data file to this location using the [Azure dashboard](https://portal.azure.com/#blade/HubsExtension/BrowseResourceBlade/resourceType/Microsoft.Storage%2FStorageAccounts). Note that the migration data file MUST be in CSV format.

The naming convention for the uploaded file should be as follows:
 - `am-migration-{DDMMYY}.csv`
 - eg. `am-migration-301193.csv`

## Uploading the migration scripts

The pipeline will take the migration scripts from the `scripts` directory in this repository. The Access Management databases are PostgreSQL databases, so the scripts MUST be written in PostgreSQL format.

## Running the data migration

The migration can be triggered through the [Jenkins dashboard](https://build.platform.hmcts.net/job/HMCTS_AM/job/am-data-migration/). Navigate to the `master` branch and select `Build with Parameters`.

The following build parameters can be set:
 - `ENVIRONMENT`: the target environment for the migration (eg. `aat`, `prod`)
 - `MIGRATION_DATA_FILENAME`: the name of the migration data file in Azure Storage Accounts
 - `MIGRATION_SCRIPT_FILENAME`: the name of the migration script in the `scripts` directory

Once these parameters have been entered, press `Build` and the data migration will be carried out.

## Metrics

The pipeline produces a metrics file which gives the following information:
 - the number of records read from the input file
 - the number of duplicate records in the input file (which are then excluded from the migration)
 - the number of records in the input file that already exist in the access_management table (which are then excluded from the migration)
 - the number of records in the access_management table pre-migration
 - the number of records in the access_management table post-migration, allowing you to calculate the number of records migrated
 - the number of erroneous records in the input file that were not migrated
 - the erroneous records that were not migrated (limited to 100 records)

This metrics file can be found through the [Jenkins dashboard](https://build.platform.hmcts.net/job/HMCTS_AM/job/am-data-migration/) once the migration has been completed.

## More information

More information about the design of the Access Management Data Migration Service can be found here: https://tools.hmcts.net/confluence/display/AM/Initial+Data+Migration
