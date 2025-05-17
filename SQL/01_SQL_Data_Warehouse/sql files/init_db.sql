-- use master
use master;

-- create database warehouse
create database datawarehouse;
use datawarehouse;

-- create schemas

create schema bronze;
go

create schema silver;
go

create schema gold;
go
