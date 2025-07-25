-- ✅ STEP 1: Create Raw Events Table and Load Data
-- Assumes raw CSV is imported already OR use the following query:

LOAD DATA INFILE '/path/to/raw_events.csv'
INTO TABLE raw_events
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(event_time, event_type, product_id, category_id, category_code, brand, price, user_id, user_session);


-- ✅ STEP 2: Clean the raw_events data
-- Remove nulls and irrelevant event types
CREATE TABLE clean_events AS
SELECT *
FROM raw_events
WHERE event_type IN ('view', 'cart', 'purchase', 'return')
  AND user_id IS NOT NULL
  AND product_id IS NOT NULL;


-- ✅ STEP 3: Create Dimension Tables

-- 🎯 dim_users
CREATE TABLE dim_users (
  user_key INT AUTO_INCREMENT PRIMARY KEY,
  user_id BIGINT UNIQUE
);

INSERT INTO dim_users (user_id)
SELECT DISTINCT user_id FROM clean_events;

-- 🎯 dim_products
CREATE TABLE dim_products (
  product_key INT AUTO_INCREMENT PRIMARY KEY,
  product_id BIGINT,
  brand VARCHAR(100),
  price DECIMAL(10,2),
  UNIQUE(product_id, brand, price)
);

INSERT INTO dim_products (product_id, brand, price)
SELECT DISTINCT product_id, brand, price
FROM clean_events;

-- 🎯 dim_category
CREATE TABLE dim_category (
  category_id INT AUTO_INCREMENT PRIMARY KEY,
  category_code VARCHAR(255) UNIQUE
);

INSERT INTO dim_category (category_code)
SELECT DISTINCT category_code
FROM clean_events;

-- 🎯 dim_sessions
CREATE TABLE dim_sessions (
  session_id VARCHAR(255) PRIMARY KEY
);

INSERT INTO dim_sessions (session_id)
SELECT DISTINCT user_session FROM clean_events;

-- 🎯 dim_date
CREATE TABLE dim_date (
  date_id INT AUTO_INCREMENT PRIMARY KEY,
  full_date DATE,
  year INT,
  month INT,
  day INT,
  week INT,
  weekday VARCHAR(15),
  weekend_flag BOOLEAN,
  UNIQUE(full_date)
);

INSERT INTO dim_date (full_date, year, month, day, week, weekday, weekend_flag)
SELECT DISTINCT
  DATE(event_time) AS full_date,
  YEAR(event_time),
  MONTH(event_time),
  DAY(event_time),
  WEEK(event_time),
  DAYNAME(event_time),
  CASE WHEN DAYOFWEEK(event_time) IN (1,7) THEN TRUE ELSE FALSE END
FROM clean_events;


-- ✅ STEP 4: Create Fact Table
CREATE TABLE fact_sales (
  sales_id INT AUTO_INCREMENT PRIMARY KEY,
  user_id BIGINT,
  product_key INT,
  category_id INT,
  session_id VARCHAR(255),
  date_id INT,
  price DECIMAL(10,2),
  event_type VARCHAR(20)
);

-- Insert only 'purchase' and 'return' records into fact_sales
INSERT INTO fact_sales (user_id, product_key, category_id, session_id, date_id, price, event_type)
SELECT 
  ce.user_id,
  dp.product_key,
  dc.category_id,
  ce.user_session,
  dd.date_id,
  ce.price,
  ce.event_type
FROM clean_events ce
JOIN dim_products dp ON ce.product_id = dp.product_id AND ce.brand = dp.brand AND ce.price = dp.price
JOIN dim_category dc ON ce.category_code = dc.category_code
JOIN dim_sessions ds ON ce.user_session = ds.session_id
JOIN dim_date dd ON DATE(ce.event_time) = dd.full_date
WHERE ce.event_type IN ('purchase', 'return');


-- ✅ STEP 5: Add Foreign Keys to fact_sales
ALTER TABLE fact_sales
ADD CONSTRAINT fk_user FOREIGN KEY (user_id) REFERENCES dim_users(user_id),
ADD CONSTRAINT fk_product FOREIGN KEY (product_key) REFERENCES dim_products(product_key),
ADD CONSTRAINT fk_category FOREIGN KEY (category_id) REFERENCES dim_category(category_id),
ADD CONSTRAINT fk_session FOREIGN KEY (session_id) REFERENCES dim_sessions(session_id),
ADD CONSTRAINT fk_date FOREIGN KEY (date_id) REFERENCES dim_date(date_id);


-- ✅ STEP 6: Data Quality Checks


-- 6.1 – Check for NULLs in fact_sales
-- Make sure no important foreign keys are missing:

SELECT 
  COUNT(*) AS total_rows,
  SUM(CASE WHEN user_id IS NULL THEN 1 ELSE 0 END) AS null_users,
  SUM(CASE WHEN product_key IS NULL THEN 1 ELSE 0 END) AS null_products,
  SUM(CASE WHEN category_id IS NULL THEN 1 ELSE 0 END) AS null_categories,
  SUM(CASE WHEN session_id IS NULL THEN 1 ELSE 0 END) AS null_sessions,
  SUM(CASE WHEN date_id IS NULL THEN 1 ELSE 0 END) AS null_dates,
  SUM(CASE WHEN price IS NULL THEN 1 ELSE 0 END) AS null_prices,
  SUM(CASE WHEN event_type IS NULL THEN 1 ELSE 0 END) AS null_event_types
FROM fact_sales;


-- 🧩 6.2 – Check for Orphan Keys (Foreign Keys that Don’t Exist in Dimensions)
-- Example: Users in fact_sales not in dim_users


SELECT COUNT(*)
FROM fact_sales fs
LEFT JOIN dim_users du ON fs.user_id = du.user_id
WHERE du.user_id IS NULL;

SELECT COUNT(*)
FROM fact_sales fs
LEFT JOIN dim_products dp ON fs.product_key = dp.product_key
WHERE dp.product_key IS NULL;

SELECT COUNT(*)
FROM fact_sales fs
LEFT JOIN dim_category dc ON fs.category_id = dc.category_id
WHERE dc.category_id IS NULL;

SELECT COUNT(*)
FROM fact_sales fs
LEFT JOIN dim_sessions ds ON fs.session_id = ds.user_session
WHERE ds.user_session IS NULL;

SELECT COUNT(*)
FROM fact_sales fs
LEFT JOIN dim_date dd ON fs.date_id = dd.date_id
WHERE dd.date_id IS NULL;

-- 6.4 Null value check
SELECT *
FROM fact_sales
WHERE user_id IS NULL
   OR product_key IS NULL
   OR category_id IS NULL
   OR session_id IS NULL
   OR date_id IS NULL;


-- ✅ STEP 7: Business Insights Queries


-- Q1. Total Revenue from Purchases
-- ---------------------------------
SELECT SUM(price) AS total_revenue
FROM fact_sales
WHERE event_type = 'purchase';

-- Q2. Unique Users Who Made at Least One Purchase
-- ------------------------------------------------
SELECT COUNT(DISTINCT user_id) AS purchasing_users
FROM fact_sales
WHERE event_type = 'purchase';

-- Q3. How many users have only ever viewed products but never purchased?
-- --------------------------------------------------------------------
select count(distinct user_id)
from clean_events
where event_type = "view";


-- Q4. What is the average order value per user (total purchase amount / no. of purchasing users)?
-- -----------------------------------------------------------------------------------------------
with temp as (
    select count(distinct user_id) as tot_user, sum(price) as tot_revenue
    from fact_sales
    where event_type = 'purchase'
)
select tot_revenue / tot_user
from temp;


-- 📦 Part 2 – Product Performance Analysis
-- ----------------------------------------


-- Q5. Which product category has generated the highest total revenue?
-- -------------------------------------------------------------------
with temp as (
    SELECT fs.category_id, sum(fs.price) as tot_rev
    from fact_sales fs
    where fs.event_type = "purchase"
    group by fs.category_id
    order by tot_rev desc
    limit 1
)
select tot_rev, temp.category_id, dc.category_code
from temp
join dim_category dc on temp.category_id = dc.category_id;


-- Q6. What are the top 5 brands by number of purchases?
-- -----------------------------------------------------
select dp.brand, count(*) as nop
from fact_sales fs
join dim_products dp on dp.product_key = fs.product_key
where fs.event_type = 'purchase'
group by dp.brand
order by nop desc
limit 5;


-- Q7. Which product has the highest average selling price (among those purchased at least 5 times)?
-- ------------------------------------------------------------------------------------------------

-- Option 1 (Direct)
select dp.brand, count(*) as nop, avg(price) as avg_SP
from fact_sales fs
join dim_products dp on dp.product_key = fs.product_key
where fs.event_type = 'purchase'
group by fs.product_key
having nop > 5
order by avg_SP desc
limit 5;

-- Option 2 (Using total / count)
with temp as (
    select dp.brand, count(*) as nop, sum(fs.price) as tot_sale_4_brand
    from fact_sales fs
    join dim_products dp on dp.product_key = fs.product_key
    where fs.event_type = 'purchase'
    group by fs.product_key
    having nop > 5
    order by nop desc
)
select tot_sale_4_brand / nop as avg_SP, temp.brand
from temp
order by avg_SP desc
limit 5;


-- 📈 Part 3 – Time Series Trends
-- ------------------------------


-- Q8. What is the monthly trend of total revenue?
-- ----------------------------------------------
-- SELECT 
    dd.year,
    dd.month,
    SUM(fs.price) AS total_revenue
FROM fact_sales fs
JOIN dim_date dd ON fs.date_id = dd.date_id
WHERE fs.event_type = 'purchase'
GROUP BY dd.year, dd.month
ORDER BY dd.year, dd.month;


-- Q9. Which month had the highest number of purchases?
-- ----------------------------------------------------
SELECT dd.year, dd.month, COUNT(*) AS tot_pur
FROM fact_sales fs
JOIN dim_date dd ON dd.date_id = fs.date_id
WHERE fs.event_type = 'purchase'
GROUP BY dd.year, dd.month
ORDER BY tot_pur DESC
LIMIT 1;


-- Q10. What is the daily average revenue in each month?
-- -----------------------------------------------------
with temp as (
    SELECT 
        dd.year,
        dd.month,
        sum(fs.price) AS total_revenue
    FROM fact_sales fs
    JOIN dim_date dd ON fs.date_id = dd.date_id
    WHERE fs.event_type = 'purchase'
    GROUP BY dd.year, dd.month
),
temp2 as (
    select dd.year,
           dd.month,
           count(*) as tot_day
    from dim_date dd
    group by dd.year, dd.month
)
select dd.year,
       dd.month,
       total_revenue / tot_day as monthly_avg_revenue
from dim_date dd
join temp t on dd.year = t.year and dd.month = t.month
join temp2 t2 on dd.year = t2.year and dd.month = t2.month;


-- Q11. Who are the top 3 users who spent the most overall?
-- --------------------------------------------------------
select user_id, sum(price) as money_spent
from fact_sales
where event_type = 'purchase'
group by user_id
order by money_spent desc
limit 3;


-- Q12. For each month, what is the total number of purchases and total revenue?
-- ---------------------------------------------------------------------------
select dd.year, dd.month, count(*) as n_o_p , sum(price) as tot_rev
from fact_sales fs
join dim_date dd on dd.date_id = fs.date_id
where fs.event_type = 'purchase'
group by dd.year, dd.month
order by dd.year, dd.month;


-- Q13. What is the repeat purchase rate?
-- ------------------------------------

-- Option 1
with user_more_1 as (
    select fs.user_id as id
    from fact_sales fs
    where fs.event_type = 'purchase'
    group by fs.user_id
    having count(*) > 1
),
user_least_1 as (
    select fs.user_id as id
    from fact_sales fs
    where fs.event_type = 'purchase'
    group by fs.user_id
)
select 
    COUNT(DISTINCT u1.id) * 1.0 / COUNT(DISTINCT u2.id) AS repeat_purchase_rate
from user_more_1 u1
join user_least_1 u2 ON u1.id = u2.id;

-- Option 2

with user_purchases as (
    select user_id, count(*) as purchase_count
    from fact_sales
    where event_type = 'purchase'
    group by user_id
)
select 
    COUNT(case when purchase_count > 1 then 1 end) * 1.0 / COUNT(*) AS repeat_purchase_rate
from user_purchases;


-- Q14. What percentage of users made more than one purchase?
-- ---------------------------------------------------------
with temp as (
    select user_id, count(*) as nop
    from fact_sales
    where event_type = 'purchase'
    group by user_id
    having nop > 1
)
select 
    (sum(nop) / (select count(distinct user_id) from fact_sales)) * 100 AS customer_stickiness_percentage
from temp;


-- Q15. What’s the average number of days between two purchases per user?
-- ---------------------------------------------------------------------
with purchase_dates as (
    select 
        fs.user_id,
        dd.full_date,
        row_number() over (partition by fs.user_id order by dd.full_date) as rn,
        lag(dd.full_date) over (partition by fs.user_id order by dd.full_date) as prev_date
    from fact_sales fs
    join dim_date dd on fs.date_id = dd.date_id
    where fs.event_type = 'purchase'
),
diffs as (
    select 
        user_id,
        datediff(full_date, prev_date) as days_between
    from purchase_dates
    where prev_date is not null
)
select round(avg(days_between), 2) as avg_days_between_purchases
from diffs;


-- Q16. What are the top 3 most returned product categories?
-- -------------------------------------------------------
select category_id, count(*) as fre
from fact_sales 
where event_type = "returned"
group by product_id
order by fre desc
limit 3;


-- Q17. For each user, what is their first purchase date and most recent purchase date?
-- -----------------------------------------------------------------------------------
with ranked_dates as (
    select 
        fs.user_id,
        dd.full_date,
        row_number() over (partition by fs.user_id order by dd.full_date asc) as rn_first,
        row_number() over (partition by fs.user_id order by dd.full_date desc) as rn_last
    from fact_sales fs
    join dim_date dd on fs.date_id = dd.date_id
    where fs.event_type = 'purchase'
)
select 
    user_id,
    max(case when rn_first = 1 then full_date end) as first_purchase,
    max(case when rn_last = 1 then full_date end) as most_recent_purchase
from ranked_dates
group by user_id
order by user_id;


-- Q18. What is the current conversion rate (views → purchases)?
-- -----------------------------------------------------------
with event_counts as (
    select
        sum(case when event_type = 'purchase' then 1 else 0 end) as purchases,
        sum(case when event_type = 'view' then 1 else 0 end) as views
    from clean_events
    where event_type in ('purchase', 'view')
)
select
    round((purchases * 100.0) / views, 2) as conversion_rate
from event_counts;


-- Q19. What is the return rate (returned orders as % of total purchases)?
-- ---------------------------------------------------------------------
with temp as (
    select 
        sum(case when event_type = 'purchase' then 1 else 0 end) as tot_buys,
        sum(case when event_type = 'returned' then 1 else 0 end) as tot_return
    from clean_events
    where event_type in ('purchase', 'returned')
)
select round((tot_return * 100) / tot_buys, 2) as return_rate
from temp;


-- Q20. What’s the monthly return rate trend?
-- ----------------------------------------
with data_table as (
    select 
        dd.year as year_name, 
        dd.month as month_name,
        sum(case when event_type = 'return' then 1 else 0 end) as returned_quant,
        sum(case when event_type = 'purchase' then 1 else 0 end) as purchased_quant
    from fact_sales fs
    join dim_date dd on fs.date_id = dd.date_id
    group by dd.year, dd.month
)
select 
    year_name, 
    month_name, 
    (returned_quant * 100.0 / (returned_quant + purchased_quant)) as return_rate
from data_table;


-- Q21. Which users have both returned and purchased the same product?
-- -----------------------------------------------------------------
with returned_data as (
    select
        fs.user_id as r_id,
        fs.product_key,
        min(dd.full_date) as return_date
    from fact_sales fs
    join dim_date dd on fs.date_id = dd.date_id
    where fs.event_type = 'return'
    group by fs.user_id, fs.product_key 
),
purchased_data as (
    select
        fs1.user_id,
        fs1.product_key,
        min(dd.full_date) as purchase_date
    from fact_sales fs1
    join dim_date dd on fs1.date_id = dd.date_id
    where fs1.event_type = 'purchase'
    group by fs1.user_id, fs1.product_key
)
select distinct r_id
from returned_data rd
join purchased_data pd 
    on pd.user_id = rd.r_id and rd.product_key = pd.product_key
where purchase_date < return_date;



-- 🔸 High-Value Customer Segmentation

-- 1. Users with Highest Average Order Value (AOV)
-- -----------------------------------------------

select user_id, avg(price) as AOV
from fact_sales
where event_type = 'purchase'
group by user_id
ORDER BY AOV desc
limit 10;


# 2. Users with Low Return Rate but High Revenue
-- ----------------------------------------------


 WITH user_stats AS (
    SELECT 
         user_id,
         SUM(CASE WHEN event_type = 'purchase' THEN price ELSE 0 END) AS purchase_total,
         COUNT(CASE WHEN event_type = 'purchase' THEN 1 END) AS purchase_count,
         SUM(CASE WHEN event_type = 'return' THEN price ELSE 0 END) AS return_total,
         COUNT(CASE WHEN event_type = 'return' THEN 1 END) AS return_count
    FROM fact_sales
    GROUP BY user_id
)
 SELECT 
     user_id,
     purchase_total,
     purchase_count,
     return_count,
     ROUND(return_count * 100.0 / NULLIF(purchase_count + return_count, 0), 2) AS return_rate
 FROM user_stats
 WHERE 
   purchase_total > 1000
    AND (return_count = 0 OR return_count * 1.0 / (purchase_count + return_count) < 0.1)
 ORDER BY purchase_total DESC
 LIMIT 10;


-- Funnel Analysis: View → Purchase (→ Cart if exists)
-- ---------------------------------------------------

WITH funnel AS (
  SELECT
    user_id,
    MAX(CASE WHEN event_type = 'view' THEN 1 ELSE 0 END) AS viewed,
    MAX(CASE WHEN event_type = 'cart' THEN 1 ELSE 0 END) AS carted,
    MAX(CASE WHEN event_type = 'purchase' THEN 1 ELSE 0 END) AS purchased
  FROM fact_sales
  GROUP BY user_id
)
SELECT
  COUNT(*) FILTER (WHERE viewed = 1) AS viewed_users,
  COUNT(*) FILTER (WHERE carted = 1) AS carted_users,
  COUNT(*) FILTER (WHERE purchased = 1) AS purchased_users,
  ROUND(
    100.0 * COUNT(*) FILTER (WHERE carted = 1) / NULLIF(COUNT(*) FILTER (WHERE viewed = 1), 0), 2
  ) AS view_to_cart_pct,
  ROUND(
    100.0 * COUNT(*) FILTER (WHERE purchased = 1) / NULLIF(COUNT(*) FILTER (WHERE carted = 1), 0), 2
  ) AS cart_to_purchase_pct,
  ROUND(
    100.0 * COUNT(*) FILTER (WHERE purchased = 1) / NULLIF(COUNT(*) FILTER (WHERE viewed = 1), 0), 2
  ) AS view_to_purchase_pct
FROM funnel;



-- 📊 FINAL DASHBOARD METRICS


-- 🔹 1. Total Users
SELECT COUNT(DISTINCT user_id) AS total_users
FROM fact_sales;

-- 🔹 2. Total Revenue
SELECT SUM(price) AS total_revenue
FROM fact_sales
WHERE event_type = 'purchase';

-- 🔹 3. Total Number of Purchases
SELECT COUNT(*) AS total_purchases
FROM fact_sales
WHERE event_type = 'purchase';

-- 🔹 4. Total Number of Returns
SELECT COUNT(*) AS total_returns
FROM fact_sales
WHERE event_type = 'return';

-- 🔹 5. Conversion Rate (Views → Purchases)
WITH conversion AS (
  SELECT
    SUM(CASE WHEN event_type = 'view' THEN 1 ELSE 0 END) AS views,
    SUM(CASE WHEN event_type = 'purchase' THEN 1 ELSE 0 END) AS purchases
  FROM clean_events
)
SELECT 
  ROUND((purchases * 100.0) / views, 2) AS conversion_rate_percentage
FROM conversion;

-- 🔹 6. Return Rate (% of purchases that were returned)
WITH returns AS (
  SELECT
    SUM(CASE WHEN event_type = 'purchase' THEN 1 ELSE 0 END) AS purchases,
    SUM(CASE WHEN event_type = 'return' THEN 1 ELSE 0 END) AS returns
  FROM clean_events
)
SELECT 
  ROUND((returns * 100.0) / purchases, 2) AS return_rate_percentage
FROM returns;

-- 🔹 7. Average Order Value (AOV)
WITH aov AS (
  SELECT 
    COUNT(DISTINCT user_id) AS total_users,
    SUM(price) AS total_revenue
  FROM fact_sales
  WHERE event_type = 'purchase'
)
SELECT 
  ROUND(total_revenue / total_users, 2) AS avg_order_value
FROM aov;

-- 🔹 8. Top Performing Month by Revenue
SELECT 
  dd.year, dd.month, 
  SUM(price) AS monthly_revenue
FROM fact_sales fs
JOIN dim_date dd ON fs.date_id = dd.date_id
WHERE event_type = 'purchase'
GROUP BY dd.year, dd.month
ORDER BY monthly_revenue DESC
LIMIT 1;

-- 🔹 9. Top 5 High-Spending Users
SELECT 
  user_id, SUM(price) AS total_spent
FROM fact_sales
WHERE event_type = 'purchase'
GROUP BY user_id
ORDER BY total_spent DESC
LIMIT 5;

-- 🔹 10. Product Category with Most Returns
SELECT 
  category_id, COUNT(*) AS return_count
FROM fact_sales
WHERE event_type = 'return'
GROUP BY category_id
ORDER BY return_count DESC
LIMIT 1;


