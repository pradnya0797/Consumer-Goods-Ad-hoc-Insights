
/* 1. Provide the list of markets in which customer "Atliq Exclusive" operates its
business in the APAC region. */

SELECT DISTINCT market
FROM   dim_customer
WHERE  customer = "Atliq Exclusive"
       AND region = "APAC" 


/* 2. What is the percentage of unique product increase in 2021 vs. 2020? The
		final output contains these fields,
		unique_products_2020
		unique_products_2021
		percentage_chg  */

WITH CTE1 AS
(
       SELECT Count(DISTINCT product_code) AS unique_product_2020
       FROM   fact_sales_monthly
       WHERE  fiscal_year="2020" ), 
CTE2 AS
(
       SELECT Count(DISTINCT product_code) AS unique_product_2021
       FROM   fact_sales_monthly
       WHERE  fiscal_year="2021" )
SELECT c1.unique_product_2020,
       c2.unique_product_2021,
       Round((c2.unique_product_2021-c1.unique_product_2020)*100/c1.unique_product_2020,2) AS percentage_chg
FROM   CTE1 c1
JOIN   CTE2 c2	


/*3. Provide a report with all the unique product counts for each segment and
sort them in descending order of product counts. The final output contains
2 fields,
segment
product_count */

SELECT segment,
       Count(DISTINCT product_code) AS product_count
FROM   dim_product
GROUP  BY segment
ORDER  BY product_count DESC


/* 4. Follow-up: Which segment had the most increase in unique products in
2021 vs 2020? The final output contains these fields,
segment
product_count_2020
product_count_2021
difference */ 

WITH CTE1
     AS (SELECT p.segment,
                Count(DISTINCT s.product_code) AS product_count_2020
         FROM   fact_sales_monthly s
                JOIN dim_product p using(product_code)
         WHERE  s.fiscal_year = "2020"
         GROUP  BY p.segment),
     CTE2
     AS (SELECT p.segment,
                Count(DISTINCT s.product_code) AS product_count_2021
         FROM   fact_sales_monthly s
                JOIN dim_product p using(product_code)
         WHERE  s.fiscal_year = "2021"
         GROUP  BY p.segment)
SELECT c1.segment,
       product_count_2020,
       product_count_2021,
       ( product_count_2021 - product_count_2020 ) AS Difference
FROM   CTE1 c1
       JOIN CTE2 c2
         ON c1.segment = c2.segment
ORDER  BY difference DESC 


/* 5. Get the products that have the highest and lowest manufacturing costs.
The final output should contain these fields,
product_code
product
manufacturing_cost */

SELECT m.product_code,
       product,
       cost_year,
       manufacturing_cost
FROM   fact_manufacturing_cost m
       JOIN dim_product p
         ON m.product_code = p.product_code
WHERE  manufacturing_cost = (SELECT Max(manufacturing_cost)
                             FROM   fact_manufacturing_cost)
        OR manufacturing_cost = (SELECT Min(manufacturing_cost)
                                 FROM   fact_manufacturing_cost)
ORDER  BY manufacturing_cost DESC 


/* 6. Generate a report which contains the top 5 customers who received an
average high pre_invoice_discount_pct for the fiscal year 2021 and in the
Indian market. The final output contains these fields,
customer_code
customer
average_discount_percentage */
 
 SELECT d.customer_code,
       c.customer,
       ROUND(AVG (pre_invoice_discount_pct) * 100, 4)AS
       average_discount_percentage
FROM   fact_pre_invoice_deductions d
       JOIN dim_customer c USING(customer_code)
WHERE  d.fiscal_year = "2021"
       AND c.market = "India"
GROUP  BY c.customer,
          c.customer_code
ORDER  BY average_discount_percentage DESC
LIMIT  5 


/* 7. Get the complete report of the Gross sales amount for the customer â€œAtliq
Exclusiveâ€ for each month. This analysis helps to get an idea of low and
high-performing months and take strategic decisions.
The final report contains these columns:
Month
Year
Gross sales Amount */

SELECT Concat(Monthname(f.date), ' (', Year(f.date), ')')                    AS
       'Month'
       ,
       f.fiscal_year,
       Concat(Round(Sum(g.gross_price * f.sold_quantity) / 1000000, 2), 'M') AS
       gross_sales_amount
FROM   fact_sales_monthly f
       JOIN dim_customer c
         ON f.customer_code = c.customer_code
       JOIN fact_gross_price g
         ON f.product_code = g.product_code
WHERE  C.customer = 'Atliq Exclusive'
GROUP  BY month,
          f.fiscal_year
ORDER  BY f.fiscal_year


/* 8. In which quarter of 2020, got the maximum total_sold_quantity? The final
output contains these fields sorted by the total_sold_quantity,
Quarter
total_sold_quantity */

WITH CTE
     AS (SELECT date,
                MONTH(DATE_ADD(date, interval 4 month)) AS period,
                fiscal_year,
                sold_quantity
         FROM   fact_sales_monthly)
SELECT CASE
         WHEN period / 3 <= 1 THEN "Q1"
         WHEN period / 3 <= 2 AND period / 3 > 1 THEN "Q2"
         WHEN period / 3 <= 3 AND period / 3 > 2 THEN "Q3"
         WHEN period / 3 <= 4 AND period / 3 > 3 THEN "Q4"
       END                                    quarter,
       ROUND(SUM(sold_quantity) / 1000000, 2) AS total_sold_quanity_in_millions
FROM   CTE
WHERE  fiscal_year = 2020
GROUP  BY quarter
ORDER  BY total_sold_quanity_in_millions DESC


/* 9. Which channel helped to bring more gross sales in the fiscal year 2021
and the percentage of contribution? The final output contains these fields,
channel
gross_sales_mln
percentage */

WITH CTE
     AS (SELECT c.channel,
                Sum(s.sold_quantity * g.gross_price) AS total_sales
         FROM   fact_sales_monthly s
                JOIN fact_gross_price g using(product_code)
                JOIN dim_customer c using(customer_code)
         WHERE  s.fiscal_year = 2021
         GROUP  BY c.channel
         ORDER  BY total_sales DESC)
SELECT channel,
       CONCAT(Round(total_sales / 1000000, 2), 'M') AS
       gross_sales_in_millions,
       CONCAT(Round(total_sales / ( Sum(total_sales) OVER() ) * 100, 2), '%') AS 
       percentage
FROM   CTE

/* 10. Get the Top 3 products in each division that have a high
total_sold_quantity in the fiscal_year 2021? The final output contains these
fields,
division
product_code
product
total_sold_quantity
rank_order                 */

WITH CTE1
     AS (SELECT p.division,
                s.product_code,
                p.product,
                Sum(s.sold_quantity) AS Total_sold_quantity
         FROM   dim_product p
                JOIN fact_sales_monthly s using(product_code)
         WHERE  s.fiscal_year = 2021
         GROUP  BY s.product_code,
                   division,
                   p.product),
     CTE2
     AS (SELECT division,
                product_code,
                product,
                total_sold_quantity,
                RANK()
                  OVER(
                    partition BY division
                    ORDER BY total_sold_quantity DESC) AS 'Rank_Order'
         FROM   cte1)
SELECT CTE1.division,
       CTE1.product_code,
       CTE1.product,
       CTE2.total_sold_quantity,
       CTE2.rank_order
FROM   CTE1
       JOIN CTE2
         ON CTE1.product_code = CTE2.product_code
WHERE  CTE2.rank_order IN ( 1, 2, 3 ) 
