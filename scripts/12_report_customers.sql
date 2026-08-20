/*
===============================================================
Create Customer Report View
===============================================================

Script Purpose:
    This view provides customer-level metrics and classifications
    for analytics and reporting, including customer age, orders,
    sales, recency, and customer segment.

WARNING:
    This view depends on gold.fact_sales and gold.dim_customers.
    The source Gold layer views must be available before creating it.
*/


CREATE OR ALTER VIEW gold.report_customers AS

WITH base_query AS (
    SELECT
        f.order_number,
        f.product_key,
        f.order_date,
        f.sales_amount,
        f.quantity,
        c.customer_key,
        c.customer_number,
        CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
        DATEDIFF(YEAR, c.birthdate, GETDATE()) AS customer_age

    FROM gold.fact_sales f

    LEFT JOIN gold.dim_customers c
        ON f.customer_key = c.customer_key

    WHERE f.order_date IS NOT NULL
)


, customer_aggregation AS (
    SELECT
        customer_key,
        customer_number,
        customer_name,
        customer_age,
        COUNT(DISTINCT order_number) AS total_orders,
        SUM(sales_amount) AS total_sales,
        SUM(quantity) AS total_quantity,
        COUNT(DISTINCT product_key) AS total_products,
        MAX(order_date) AS last_order,
        DATEDIFF(YEAR, MIN(order_date), MAX(order_date)) AS lifespan

    FROM base_query

    GROUP BY
        customer_key,
        customer_number,
        customer_name,
        customer_age
)


SELECT
    customer_key,
    customer_number,
    customer_name,
    customer_age,

    CASE
        WHEN customer_age < 20 THEN 'Under 20'
        WHEN customer_age < 30 THEN '20-30'
        WHEN customer_age < 40 THEN '30-40'
        WHEN customer_age < 50 THEN '40-50'
        ELSE 'Above 50'
    END AS age_group,

    CASE
        WHEN lifespan >= 12 AND total_sales > 5000 THEN 'VIP'
        WHEN lifespan >= 12 AND total_sales <= 5000 THEN 'Regular'
        ELSE 'New'
    END AS customer_segment,

    last_order,
    DATEDIFF(MONTH, last_order, GETDATE()) AS recency,

    total_orders,
    total_sales,
    total_quantity,
    total_products,
    lifespan,

    CASE
        WHEN total_orders = 0 THEN 0
        ELSE CAST(total_sales AS DECIMAL(18, 2)) / total_orders
    END AS avg_order_value,

    CASE
        WHEN lifespan = 0 THEN total_sales
        ELSE CAST(total_sales AS DECIMAL(18, 2)) / lifespan
    END AS avg_sales_per_month

FROM customer_aggregation;
