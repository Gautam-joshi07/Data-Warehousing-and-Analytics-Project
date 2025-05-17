# Data-Warehousing-and-Analytics-Project
This project showcases a complete data warehousing and analytics workflow using SQL and real-world CRM and ERP datasets. It involves designing a star schema, building the data warehouse, and developing robust SQL-based ETL pipelines. The integrated data provides a unified view of customer behavior, sales performance, and operational efficiency. Advanced SQL queries are used to generate KPIs and actionable insights. The solution follows best practices in data modeling and analytics. Designed as a portfolio project, it highlights hands-on expertise in SQL-driven data engineering and analytics.

## Data Architecture
Project follows Medallion Architecture(Bronze, Silver and Gold Layers) 

1) Bronze layer : The Bronze layer is where we get raw data from the source system. Data is ingested from CSV files into SQL Server Database.
2) Silver layer : The silver layer brings the data from different sources into an Enterprise view. It includes data cleaning, standardization and normalization process to prepare data for analysis.
3) Gold layer :  Data in the Gold layer is typically organized in consumption-ready databases which is used for reporting and analysis.
