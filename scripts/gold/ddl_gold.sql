/*
===============================================================================
Description:
    This script creates views for the **Gold Layer** of the data warehouse. 
    The Gold Layer consists of dimension and fact views in a Star Schema format, 
    designed for analytical consumption and business reporting.

    These views perform transformations, apply business rules, and join data 
    from the Silver Layer to generate clean, enriched, and analysis-ready datasets.

Views Created:
    - gold.dim_customers
    - gold.dim_products
    - gold.fact_sales

Usage:
    - Query these views directly for analytics, dashboards, and reporting tools.
    - Suitable for business intelligence and decision-making processes.

Dependencies:
    - silver.crm_cust_info
    - silver.erp_cust_az12
    - silver.erp_loc_a101
    - silver.crm_prd_info
    - silver.erp_px_cat_g1v2
    - silver.crm_sales_details

Notes:
    - Surrogate keys are generated using ROW_NUMBER().
    - Historical or inactive product records are filtered out.
===============================================================================
*/

-- =============================================================================
-- Create Dimension: gold.dim_customers
-- =============================================================================
IF OBJECT_ID('gold.dim_customers','V') IS NOT NULL
	DROP VIEW gold.dim_customers;
GO
CREATE VIEW gold.dim_customers AS 
SELECT 
	ROW_NUMBER() OVER(ORDER BY	ci.cst_id) AS customer_key, -- Surrogate key
	ci.cst_id AS customer_id,
	ci.cst_key AS customer_number,
	ci.cst_firstname AS first_name,
	ci.cst_lastname AS last_name,
	ci.cst_marital_status AS marital_status,
	CASE 
		WHEN ci.cst_gndr <> 'n/a' THEN  ci.cst_gndr -- CRM is the primary source for gender
		ELSE COALESCE(ca.gen,'n/a')					-- Fallback to ERP data
	END AS gender,
	ci.cst_create_date AS create_date,
	ca.bdate AS birth_date,
	la.cntry AS country
FROM		silver.crm_cust_info ci
LEFT JOIN	silver.erp_cust_az12 ca
ON			ci.cst_key = ca.cid
LEFT JOIN	silver.erp_loc_a101 la
ON			ci.cst_key = la.cid ;
-- =============================================================================
-- Create Dimension: gold.dim_products
-- =============================================================================
IF OBJECT_ID('gold.dim_products','V') IS NOT NULL
	DROP VIEW gold.dim_products;
GO
CREATE VIEW gold.dim_products AS 
SELECT 
	ROW_NUMBER() OVER(ORDER BY pn.prd_start_dt , pn.prd_key) AS product_key, -- Surrogate key
	pn.prd_id AS product_id, 
	pn.cat_id AS category_id,
	pn.prd_key AS product_number,
	pn.prd_nm AS product_name,
	pn.prd_cost AS cost,
	pn.prd_line AS product_line,
	pn.prd_start_dt AS start_date,
	pc.cat AS category,
	pc.subcat AS sub_category,
	pc.maintenance
FROM silver.crm_prd_info pn
INNER JOIN silver.erp_px_cat_g1v2 pc
	ON pn.cat_id = pc.id
WHERE pn.prd_end_dt IS NULL; -- Filter out all historical data
GO
-- =============================================================================
-- Create Dimension: gold.fact_sales
-- =============================================================================
IF OBJECT_ID('gold.fact_sales','V') IS NOT NULL
	DROP VIEW gold.fact_sales;
GO
CREATE VIEW gold.fact_sales AS
SELECT
	sd.sls_ord_num AS order_number,
	p.product_key ,
	c.customer_key,
	sd.sls_order_dt AS order_date,
	sd.sls_ship_dt AS ship_date,
	sd.sls_due_dt AS due_date,
	sd.sls_sales AS sales,
	sd.sls_quantity AS quantity,
	sd.sls_price AS price
FROM silver.crm_sales_details sd
INNER JOIN gold.dim_customers c
	ON sd.sls_cust_id = c.customer_id
INNER JOIN gold.dim_products p
	ON sd.sls_prd_key = p.product_number;
GO
