/* change over the time */
-- Analyze sales over time(year)
SELECT 
YEAR(order_date) as order_year,
SUM(sales_amount) as total_sales,
COUNT(DISTINCT(customer_key)) as total_customer,
SUM(quantity) as total_quantity
FROM gold.fact_sales
GROUP BY YEAR(order_date)
ORDER BY YEAR(order_date) 

--Analyze sales over month
SELECT 
DATETRUNC(month, order_date) as order_date,
SUM(sales_amount) as total_sales
FROM gold.fact_sales
GROUP BY DATETRUNC(MONTH, order_date)
ORDER BY DATETRUNC(MONTH, order_date)

SELECT 
FORMAT(order_date,'yyyy-MMM') as order_date,
SUM(sales_amount) as total_sales
FROM gold.fact_sales
GROUP BY FORMAT(order_date,'yyyy-MMM')
ORDER BY FORMAT(order_date,'yyyy-MMM')

-- how many new customer added each year
SELECT 
DATETRUNC(YEAR,create_date) as create_date,
COUNT(customer_key) as total_customer
FROM gold.dim_customers
GROUP BY DATETRUNC(YEAR, create_date)
ORDER BY DATETRUNC(YEAR, create_date)


/* cumulative Analysis */
-- calculate the total sales per month

SELECT order_date, total_sales,
SUM(total_sales) OVER(ORDER BY order_date) as running_total_sales
FROM 
	(
	SELECT 
		DATETRUNC(month, order_date) as order_date,
		SUM(sales_amount) as total_sales
		FROM gold.fact_sales
		WHERE order_date IS NOT NULL
		GROUP BY DATETRUNC(MONTH, order_date)
	)t

-- claculate the moving avg sales 
SELECT order_date, avg_sales,
AVG(avg_sales) OVER(ORDER BY order_date) as moving_avg_sales
FROM(
	SELECT
	DATETRUNC(MONTH,order_date) as order_date,
	AVG(sales_amount) as avg_sales
	FROM gold.fact_sales
	WHERE order_date IS NOT NULL
	GROUP BY DATETRUNC(MONTH, order_date)
	)t


/* performance analysis */
-- Analyze the yearly performance of the product by comparing their sales to both sales performance of product and the previous year sales
WITH yearly_product_sales AS (
	SELECT 
		YEAR(f.order_date) as order_year,
		p.product_name,
		SUM(f.sales_amount) as current_sales
		FROM gold.fact_sales f
		LEFT JOIN gold.dim_products p
		ON p.product_key = f.product_key
		WHERE f.order_date IS NOT NULL
		GROUP BY YEAR(f.order_date), p.product_name 
	)

	SELECT 
		order_year, product_name, current_sales,
		AVG(current_sales) OVER(PARTITION BY product_name) as avg_sales,
		current_sales - AVG(current_sales) OVER(PARTITION BY product_name) diff_avg,
		CASE 
			WHEN current_sales - AVG(current_sales) OVER(PARTITION BY product_name) > 0 THEN 'Above avg'
			WHEN current_sales - AVG(current_sales) oVER(PARTITION BY product_name) < 0 THEN 'Below avg'
			ELSE 'Avg'
		END avg_change,

		--LAG is used to get the previous row value
		LAG(current_sales) OVER(PARTITION BY product_name ORDER BY order_year) py_sales,
		current_sales - LAG(current_sales) OVER(PARTITION BY product_name ORDER BY order_year) diff_sales,
		CASE 
			WHEN LAG(current_sales) OVER(PARTITION BY product_name ORDER BY order_year) > 0 THEN 'Increase'
			WHEN LAG(current_sales) OVER(PARTITION BY product_name ORDER BY order_year) < 0 THEN 'Decrease'
			ELSE 'No Change'
		END py_change
		FROM yearly_product_sales
		ORDER BY product_name, order_year;

	

/* proportional analysis( part to whole) */

-- which category contribute the most to the sales
WITH category_sales AS (
	SELECT 
		p.category,
		SUM(f.sales_amount) as total_sales
		FROM gold.fact_sales f
		LEFT JOIN gold.dim_products p
		ON p.product_key = f.product_key
		GROUP BY category 

		)

SELECT category, total_sales,
SUM(total_sales) OVER() as overall,
CONCAT(ROUND(CAST(total_sales AS FLOAT) / SUM(total_sales) OVER() * 100, 2),'%') AS percentage_of_total
FROM category_sales
ORDER BY total_sales DESC


/* data segmentation */
-- segment product into cost ranges and count how many falls into each segment
WITH product_segment AS (
	SELECT 
		product_key, product_name, cost,
		CASE WHEN cost < 100 THEN 'below 100'
			WHEN cost between 100 AND 500 THEN ' 100-500'
			WHEN cost between 500 AND 1000 THEN '500-1000'
			ELSE 'Above 1000'
		END cost_range
		FROM gold.dim_products
	)

	SELECT cost_range,
		COUNT(product_key) as total_product
		FROM product_segment
		GROUP BY cost_range
		ORDER BY total_product DESC


/* group customer into 3 segment based on their spending behaviour
Vip : customer with atleast 12 month of history and spending more than 5000
Regular : customer with atleast 12 month of history and spending less than 5000
new customer : customer with a lifespan of less than 12 month
*/
-- find the total number customer by each group 

WITH customer_spending AS (
	SELECT d.customer_key,
		SUM(sales_amount) as total_spending,
		MIN(order_date) as first_order,
		MAX(order_date) as last_order,
		DATEDIFF(MONTH, MIN(order_date), MAX(order_date)) as lifespan
	FROM gold.fact_sales f
	LEFT JOIN gold.dim_customers d
	ON d.customer_key = f.customer_key
	GROUP BY d.customer_key
)

SELECT customer_segment,
COUNT(customer_key) as total_customer
FROM (
	SELECT customer_key,
		CASE WHEN lifespan >= 12 and total_spending > 5000 THEN 'VIP'
			WHEN lifespan >= 12 and total_spending < 5000 THEN 'Regular'
			ELSE 'New'
		END customer_segment
		FROM customer_spending
	)t
	GROUP BY customer_segment
	ORDER BY total_customer DESC

/* Build Report */
--
/*  1. Gathers essential fields such as names, ages, and transaction details.
	2. Segments customers into categories (VIP, Regular, New) and age groups.
    3. Aggregates customer-level metrics:
	   - total orders
	   - total sales
	   - total quantity purchased
	   - total products
	   - lifespan (in months)
    4. Calculates valuable KPIs:
	    - recency (months since last order)
		- average order value
		- average monthly spend

*/
CREATE VIEW gold.report_customers AS

-- 1) Base query: Retrieve core columns from tables
WITH base_query AS (
    SELECT 
        f.order_number,
        f.product_key, 
        f.order_date, 
        f.sales_amount, 
        f.customer_key, 
        f.quantity,
        c.customer_number,
        CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
        DATEDIFF(YEAR, c.birthdate, GETDATE()) AS age
    FROM gold.fact_sales f
    LEFT JOIN gold.dim_customers c ON c.customer_key = f.customer_key
    WHERE order_date IS NOT NULL
),

-- 2) Customer level aggregation
customer_aggregation AS (
    SELECT 
        customer_key, 
        customer_name, 
        customer_number, 
        age,
        COUNT(DISTINCT order_number) AS total_orders,
        SUM(sales_amount) AS total_sales,
        SUM(quantity) AS total_quantity,
        COUNT(DISTINCT product_key) AS total_products,
        MAX(order_date) AS last_order_date,
        DATEDIFF(MONTH, MIN(order_date), MAX(order_date)) AS lifespan
    FROM base_query
    GROUP BY customer_key, customer_number, customer_name, age
)

-- Final SELECT
SELECT
    customer_key,
    customer_number,
    customer_name,
    age,
    CASE 
        WHEN age < 20 THEN 'Under 20'
        WHEN age BETWEEN 20 AND 29 THEN '20-29'
        WHEN age BETWEEN 30 AND 39 THEN '30-39'
        WHEN age BETWEEN 40 AND 49 THEN '40-49'
        ELSE '50 and above'
    END AS age_group,
    CASE 
        WHEN lifespan >= 12 AND total_sales > 5000 THEN 'VIP'
        WHEN lifespan >= 12 AND total_sales <= 5000 THEN 'Regular'
        ELSE 'New'
    END AS customer_segment,
    last_order_date,
    DATEDIFF(MONTH, last_order_date, GETDATE()) AS recency,
    total_orders,
    total_sales,
    total_quantity,
    total_products,
    lifespan,
    -- Compute average order value (AOV)
    CASE 
        WHEN total_orders = 0 THEN 0
        ELSE total_sales / total_orders
    END AS avg_order_value,
    -- Compute average monthly spend
    CASE 
        WHEN lifespan = 0 THEN total_sales
        ELSE total_sales / lifespan
    END AS avg_monthly_spend
FROM customer_aggregation;


select * from gold.report_customers

select customer_segment,
	count(customer_segment) as total_customers,
	sum(total_sales) total_sales
	from gold.report_customers
	group by customer_segment