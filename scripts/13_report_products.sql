/*
===============================================================
Create Product Report View
===============================================================

Script Purpose:
    This view provides product-level metrics for analytics and
    reporting, including sales performance, customer reach,
    product lifespan, and revenue metrics.

WARNING:
    This view depends on gold.fact_sales and gold.dim_products.
    The source Gold layer views must be available before creating it.
*/


CREATE OR ALTER VIEW gold.report_products AS

WITH base_query AS (
    SELECT
        f.order_number,
        f.order_date,
        f.customer_key,
        f.sales_amount,
        f.quantity,
        f.price,
        f.product_key,
        p.product_name,
        p.category,
        p.subcategory,
        p.cost

    FROM gold.fact_sales f

    LEFT JOIN gold.dim_products p
        ON f.product_key = p.product_key
)


, products_aggregate AS (
    SELECT
        product_key,
        product_name,
        category,
        subcategory,
        cost,

        SUM(sales_amount) AS total_sales,
        SUM(quantity) AS total_quantity,
        COUNT(DISTINCT order_number) AS total_orders,
        COUNT(DISTINCT customer_key) AS total_customers,

        ROUND(
            AVG(
                CAST(sales_amount AS FLOAT)
                / NULLIF(quantity, 0)
            ),
            1
        ) AS avg_selling_price,

        MAX(order_date) AS last_sale_date,
        DATEDIFF(
            MONTH,
            MIN(order_date),
            MAX(order_date)
        ) AS lifespan

    FROM base_query

    GROUP BY
        product_key,
        product_name,
        category,
        subcategory,
        cost
)


SELECT
    product_key,
    product_name,
    category,
    subcategory,
    cost,

    total_sales,

    CASE
        WHEN total_sales > 50000 THEN 'High Performance'
        WHEN total_sales >= 10000 THEN 'Mid-Range'
        ELSE 'Low Performance'
    END AS product_segmentation,

    lifespan,

    CASE
        WHEN total_orders = 0 THEN 0
        ELSE CAST(total_sales AS DECIMAL(18, 2)) / total_orders
    END AS avg_order_revenue,

    CASE
        WHEN lifespan = 0 THEN total_sales
        ELSE CAST(total_sales AS DECIMAL(18, 2)) / lifespan
    END AS avg_sales_per_month,

    total_quantity,
    total_orders,
    total_customers,
    avg_selling_price,
    last_sale_date

FROM products_aggregate;
