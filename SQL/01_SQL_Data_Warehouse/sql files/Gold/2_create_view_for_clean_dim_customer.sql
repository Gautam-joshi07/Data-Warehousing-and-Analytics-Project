

SELECT c1.cst_id,
		c1.cst_key,
		c1.cst_firstname,
		c1.cst_lastname,
		c1.cst_marital_status,
		c1.cst_gndr,
		c1.cst_create_date,
		ca.bdate,
		ca.gen,
		la.cntry
FROM silver.crm_cust_info c1
LEFT JOIN silver.erp_cust_az12 ca
ON c1.cst_key = ca.cid
LEFT JOIN silver.erp_loc_a101 la
ON c1.cst_key = la.cid

-- check if there is any dupliacte in id after joining the tables
SELECT cst_id, COUNT(*) FROM (
		SELECT c1.cst_id,
			c1.cst_key,
			c1.cst_firstname,
			c1.cst_lastname,
			c1.cst_marital_status,
			c1.cst_gndr,
			c1.cst_create_date,
			ca.bdate,
			ca.gen,
			la.cntry
	FROM silver.crm_cust_info c1
	LEFT JOIN silver.erp_cust_az12 ca
	ON c1.cst_key = ca.cid
	LEFT JOIN silver.erp_loc_a101 la
	ON c1.cst_key = la.cid

)t GROUP BY cst_id
HAVING COUNT(*) > 1

-- data integration because we have two colu for gender, some have different values in it so solve 
-- that issuse
SELECT DISTINCT 
	c1.cst_gndr,
	ca.gen

FROM silver.crm_cust_info c1
LEFT JOIN silver.erp_cust_az12 ca
ON c1.cst_key = ca.cid
LEFT JOIN silver.erp_loc_a101 la
ON c1.cst_key = la.cid
ORDER BY 1,2

-- NULL often comes from joined tables
-- null will appear if sql finds no match

-- which source is master for these values? ---> CRM
-- solution below
SELECT DISTINCT 
	c1.cst_gndr,
	ca.gen,
	CASE WHEN c1.cst_gndr != 'n/a' THEN c1.cst_gndr -- CRM  is master table
		ELSE COALESCE(ca.gen, 'n/a')
	END AS new_gen

FROM silver.crm_cust_info c1
LEFT JOIN silver.erp_cust_az12 ca
ON c1.cst_key = ca.cid
LEFT JOIN silver.erp_loc_a101 la
ON c1.cst_key = la.cid
ORDER BY 1,2

-- main query

SELECT c1.cst_id,
		c1.cst_key,
		c1.cst_firstname,
		c1.cst_lastname,
		c1.cst_marital_status,
			CASE WHEN c1.cst_gndr != 'n/a' THEN c1.cst_gndr -- CRM  is master table
		ELSE COALESCE(ca.gen, 'n/a')
	END AS new_gen,
		c1.cst_create_date,
		ca.bdate,
		la.cntry
FROM silver.crm_cust_info c1
LEFT JOIN silver.erp_cust_az12 ca
ON c1.cst_key = ca.cid
LEFT JOIN silver.erp_loc_a101 la
ON c1.cst_key = la.cid

-- Renaming the column
-- this is a dimension customer : holds descriptive information about customer
-- sort the columns into logical groups to improve readablity

SELECT c1.cst_id AS customer_id,
		c1.cst_key AS customer_number,
		c1.cst_firstname AS first_name,
		c1.cst_lastname AS last_name,
		la.cntry AS country,

		c1.cst_marital_status AS married_status,
			CASE WHEN c1.cst_gndr != 'n/a' THEN c1.cst_gndr -- CRM  is master table
		ELSE COALESCE(ca.gen, 'n/a')
	END AS gender,
		ca.bdate,
		c1.cst_create_date
FROM silver.crm_cust_info c1
LEFT JOIN silver.erp_cust_az12 ca
ON c1.cst_key = ca.cid
LEFT JOIN silver.erp_loc_a101 la
ON c1.cst_key = la.cid



CREATE VIEW gold.dim_customer AS 
SELECT 
		ROW_NUMBER() OVER(ORDER BY cst_id) AS customer_key,
		c1.cst_id AS customer_id,
		c1.cst_key AS customer_number,
		c1.cst_firstname AS first_name,
		c1.cst_lastname AS last_name,
		la.cntry AS country,

		c1.cst_marital_status AS married_status,
			CASE WHEN c1.cst_gndr != 'n/a' THEN c1.cst_gndr -- CRM  is master table
		ELSE COALESCE(ca.gen, 'n/a')
	END AS gender,
		ca.bdate,
		c1.cst_create_date
FROM silver.crm_cust_info c1
LEFT JOIN silver.erp_cust_az12 ca
ON c1.cst_key = ca.cid
LEFT JOIN silver.erp_loc_a101 la
ON c1.cst_key = la.cid

-- view 
select * from gold.dim_customers;
select distinct gender from gold.dim_customers;




