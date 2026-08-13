create database olympic;
use olympic;

select * from sales;

select * from customers;

select * from inventory;

select * from products;

select * from stores;

# Sales Analysis
#	What is the total revenue?

SELECT 
    ROUND(SUM(sales_amount), 2) AS Total_sales
FROM
    sales;
# 	What is the total profit?
SELECT
    ROUND(
        SUM((s.unit_price - p.cost_price) * s.quantity_sold),
        2
    ) AS total_profit
FROM sales s
JOIN products p
ON s.product_id = p.product_id;

# 	What is the total quantity sold?
SELECT 
    ROUND(SUM(quantity_sold), 2) AS Total_quantitiSold
FROM
    sales;
#  Find the top 3 revenue-generating products in each category.
WITH Product_Revenue AS (
    SELECT
        p.category,
        p.product_id,
        p.product_name,

        ROUND(
            SUM(s.quantity_sold * s.unit_price),
            2
        ) AS total_revenue,

        RANK() OVER (
            PARTITION BY p.category
            ORDER BY SUM(s.quantity_sold * s.unit_price) DESC
        ) AS revenue_rank

    FROM sales AS s
    JOIN products AS p
        ON s.product_id = p.product_id

    GROUP BY
        p.category,
        p.product_id,
        p.product_name
)

SELECT
    category,
    product_id,
    product_name,
    total_revenue,
    revenue_rank
FROM Product_Revenue
WHERE revenue_rank <= 3
ORDER BY
    category,
    revenue_rank,
    total_revenue DESC ;

# 2. Calculate monthly revenue, profit, previous month's revenue, and month-over-month growt
with sales_month as (
SELECT
      Year(s.sale_date) AS sales_Year,
    MONTH(s.sale_date) AS sales_month,

    ROUND(
        SUM((s.unit_price - p.cost_price) * s.quantity_sold),
        2
    ) AS monthly_profit,

    ROUND(
        SUM(s.quantity_sold * s.unit_price),
        2
    ) AS monthly_revenue

FROM sales s
JOIN products p
    ON s.product_id = p.product_id

GROUP BY
    MONTH(s.sale_date),
    Year(s.sale_date)

ORDER BY
    sales_Year,
    sales_month
    )
SELECT
       sales_Year,
     sales_month, 
     monthly_revenue ,
     monthly_profit ,
    lag(monthly_revenue) over (order by sales_Year ,sales_month ) as previou_month ,
    
    round( monthly_revenue - (lag(monthly_revenue) over (order by sales_Year ,sales_month )) ,2) as MOM_grought ,
    round( 
    ( ((
     monthly_revenue - lag(monthly_revenue) over (order by sales_Year ,sales_month )
     )/ NULLIF( lag(monthly_revenue) over (order by sales_Year ,sales_month ) ,0 ) )
     )*100, 2) as MOM_grouth_pct
     
    from sales_month
;

# 3. Identify the products contributing to the top 80% of total revenue.

WITH product_revenue AS (
    SELECT
        p.product_id,
        p.product_name,
        ROUND(SUM(s.unit_price * s.quantity_sold), 2) AS total_revenue
    FROM sales s
    JOIN products p
        ON s.product_id = p.product_id
    GROUP BY
        p.product_id,
        p.product_name
),

cumulative_sales AS (
    SELECT
        product_id,
        product_name,
        total_revenue,
        SUM(total_revenue) OVER (
            ORDER BY total_revenue DESC
        ) AS cumulative_revenue
    FROM product_revenue
),

pareto_analysis AS (
    SELECT
        product_id,
        product_name,
        total_revenue,
        cumulative_revenue,
        ROUND(
            (cumulative_revenue /
            SUM(total_revenue) OVER ()) * 100,
            2
        ) AS cumulative_pct
    FROM cumulative_sales
)

SELECT *
FROM pareto_analysis
WHERE cumulative_pct <= 80
ORDER BY total_revenue DESC;

# 4. Find stores whose revenue is higher than the average store revenue.

WITH store_revenue AS (
    SELECT
        st.store_id,
        st.store_name,
        ROUND(SUM(s.unit_price * s.quantity_sold),2) AS total_revenue
    FROM sales s
    JOIN stores st
        ON s.store_id = st.store_id
    GROUP BY
        st.store_id,
        st.store_name
),

average_revenue AS (
    SELECT
        AVG(total_revenue) AS avg_store_revenue
    FROM store_revenue
)

SELECT
    sr.store_id,
    sr.store_name,
    sr.total_revenue
FROM store_revenue sr
CROSS JOIN average_revenue ar
WHERE sr.total_revenue > ar.avg_store_revenue
ORDER BY sr.total_revenue DESC;

# 5. Find the top 5 customers by revenue in each city.
with customer_city_revenue as (
    
    select c.customer_id , c.city ,
sum(s.unit_price * s.quantity_sold) as total_revenue 

from sales s
join customers c
ON s.customer_id = c.customer_id
GROUP BY c.customer_id , c.city 
) ,
customer_rank as (
select customer_id, city , total_revenue,
DENSE_RANK() over (PARTITION BY city ORDER BY total_revenue DESC ) as Rank_by_reveue
from 
customer_city_revenue 
)

SELECT * from customer_rank
where  Rank_by_reveue <= 5 ;

# 6. Find customers who purchased products from at least 3 different categories.
with distinct_category_count as
(
    select s1.customer_id  ,
COUNT(DISTINCT p.category ) as total_cataroey_purchues 
 from sales s1 join customers c
 on s1.customer_id = c.customer_id
join products p
on 
s1.product_id = p.product_id
GROUP BY s1.customer_id 
)
select * from distinct_category_count
where total_cataroey_purchues >= 3
;

# 7. Find customers who placed only one order.
select customer_id ,
count(*) as total_order
from sales
GROUP BY customer_id
having count(*)  = 1
;

#  Calculate Customer Lifetime Value (Revenue, Profit, Orders, and Average Basket Size).
select customer_id , 
ROUND( sum(s.unit_price * s.quantity_sold),2) as total_revenue ,
COUNT(s.customer_id) as total_order ,
ROUND(
    sum((s.unit_price * s.quantity_sold) - (p.cost_price * s.quantity_sold)),2 
) as Total_profite ,
round(
    (
sum(s.unit_price * s.quantity_sold)/COUNT(s.customer_id) ),2) as Avg_bugket 
from sales s
join products p 
on s.product_id =p.product_id
GROUP BY s.customer_id
;


# 9. Find products that were sold in every store.
with sales_store AS
(
    select s.product_id ,
    COUNT(DISTINCT s.store_id) as count_of_store
from sales s 
join stores s1 
on s.store_id = s1.store_id
GROUP BY s.product_id

)
select * from sales_store
where count_of_store =
(
    select COUNT(*) from stores
)
;


# 10. Find products with high revenue but low profit margin.
with produt_profit_margin as (
    select p.product_id , p.product_name ,
    ROUND(SUM(s.unit_price * s.quantity_sold),2) as total_revenue ,
    ROUND(SUM((s.unit_price - p.cost_price) * s.quantity_sold),2) as total_profit ,
    ROUND(
        (SUM((s.unit_price - p.cost_price) * s.quantity_sold)/NULLIF(SUM(s.unit_price * s.quantity_sold),0))*100,2
    ) as profit_margin_pct
    from sales s
    join products p
    on s.product_id = p.product_id
    GROUP BY p.product_id , p.product_name
),
porduct_avg_margin as (
    select round(avg(total_revenue),2) as avg_revenue , round(avg(profit_margin_pct) ,2) as avg_profit_margin
    from produt_profit_margin
)
select * from produt_profit_margin
cross join porduct_avg_margin 
where total_revenue > avg_revenue and profit_margin_pct < avg_profit_margin;


#11. Find products that have never been sold.
select p.product_id , p.product_name
from products p
left join sales s
on p.product_id = s.product_id
where s.product_id is null

#12. Calculate each product category's percentage contribution to total revenue.
with category_revenue as (
    select  p.category ,
    round(sum(s.unit_price * s.quantity_sold),2) as total_revenue
    from sales s
    join products p 
    on s.product_id = p.product_id  
    group by  p.category
) ,
total_revune as (
select category , round(sum(total_revenue),2) as category_revenue  ,
concat(round(
    (sum(total_revenue) /nullif((select sum(total_revenue) from category_revenue),0))*100,2
),'%') as percentage_contribution
 from category_revenue 
 group by category
)
select * from total_revune



# 13. Rank stores by revenue within each city.
with store_revenue as (
    select s.city , s.store_name ,
    round(sum(s1.unit_price * s1.quantity_sold),2) as total_revenue
    from sales s1
    join stores s
    on s1.store_id = s.store_id     
    group by s.city , s.store_name
)
select city , store_name , total_revenue ,
rank() over (partition by city order by total_revenue desc) as revenue_rank
from store_revenue
;


# 14. Find the city with the highest revenue, highest profit, and highest profit margin.
with city_overview as (
select s.city , round(sum(s1.unit_price * s1.quantity_sold),2) as total_revenue ,
round(sum((s1.unit_price - p.cost_price) * s1.quantity_sold),2) as customers_total_profit ,
ROUND(
    (sum((s1.unit_price - p.cost_price) * s1.quantity_sold)/nullif(sum(s1.unit_price * s1.quantity_sold),0))*100,2
) as profit_margin_pct
from sales s1
join stores s
on s1.store_id = s.store_id
join products p
on s1.product_id = p.product_id
group by s.city
)

select city , total_revenue ,customers_total_profit ,profit_margin_pct
 from city_overview 
 order by profit_margin_pct desc , customers_total_profit desc , total_revenue desc
limit 1;


# 15. Find stores that have inventory but no sales.
SELECT DISTINCT
    s.store_id,
    s.store_name
FROM stores s
JOIN inventory i
    ON s.store_id = i.store_id
LEFT JOIN sales sa
    ON s.store_id = sa.store_id
WHERE i.current_stock > 0
  AND sa.store_id IS NULL;

