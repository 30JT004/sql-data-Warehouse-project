/*
=======================================================
Create Database & Schemas
=======================================================
Script Purpose :
    This script xreates a new database named "DataWarehouse".The script sets up three Schemas within the database:
    'bronze', 'silver', 'gold'.
*/

use master;

create database DataWarehouse;

use DataWarehouse;

CREATE SCHEMA bronze;
GO
CREATE SCHEMA gold;
GO
CREATE SCHEMA silver;
GO

