select * from amazon_sales;

-- ====================================================================================
-- CATEGORY 1: FINANCIAL PERFORMANCE & REVENUE STRATEGY
-- ====================================================================================

-- 1. The B2B vs. B2C Check
SELECT 
    b2b, 
    SUM(amount) AS total_revenue, 
    AVG(amount) AS avg_order_value 
FROM amazon_sales 
GROUP BY b2b;

-- 2. Category Trend Drops (Month-over-Month)
WITH MonthlyCategoryRevenue AS (
    SELECT category, TO_CHAR(date::DATE, 'YYYY-MM') AS month, SUM(amount) AS total_revenue
    FROM amazon_sales
    WHERE amount IS NOT NULL
    GROUP BY category, TO_CHAR(date::DATE, 'YYYY-MM')
),
RevenueWithPrevious AS (
    SELECT category, month, total_revenue,
        LAG(total_revenue) OVER (PARTITION BY category ORDER BY month) AS prev_month_revenue
    FROM MonthlyCategoryRevenue
)
SELECT category, month, total_revenue, prev_month_revenue,
    ROUND(((total_revenue - prev_month_revenue) / prev_month_revenue::NUMERIC) * 100, 2) AS mom_growth_pct
FROM RevenueWithPrevious;

-- 3. The Most Profitable Day
SELECT 
    TO_CHAR(date::DATE, 'Day') AS day_of_week,
    SUM(amount) AS total_revenue
FROM amazon_sales
WHERE amount IS NOT NULL
GROUP BY TO_CHAR(date::DATE, 'Day')
ORDER BY total_revenue DESC;

-- 4. The Value Tier Contribution
WITH Tiers AS (
    SELECT 
        CASE 
            WHEN amount > 1000 THEN 'High Value'
            WHEN amount BETWEEN 500 AND 1000 THEN 'Medium Value'
            ELSE 'Low Value' 
        END AS tier,
        SUM(amount) AS tier_rev
    FROM amazon_sales
    WHERE amount IS NOT NULL
    GROUP BY 
        CASE 
            WHEN amount > 1000 THEN 'High Value'
            WHEN amount BETWEEN 500 AND 1000 THEN 'Medium Value'
            ELSE 'Low Value' 
        END
), 
Global AS (
    SELECT SUM(amount) AS total_rev FROM amazon_sales WHERE amount IS NOT NULL
)
SELECT 
    t.tier, 
    t.tier_rev, 
    ROUND((t.tier_rev / g.total_rev::NUMERIC) * 100, 2) AS percentage_contribution
FROM Tiers t, Global g;


-- ====================================================================================
-- CATEGORY 2: OPERATIONAL EFFICIENCY & FULFILLMENT
-- ====================================================================================

-- 5. The Cancellation Hotspots
WITH TotalOrders AS (
    SELECT fulfilment, COUNT(*) AS total_count 
    FROM amazon_sales 
    GROUP BY fulfilment
),
CancelledOrders AS (
    SELECT fulfilment, COUNT(*) AS cancelled_count 
    FROM amazon_sales 
    WHERE status = 'Cancelled' 
    GROUP BY fulfilment
)
SELECT 
    t.fulfilment, 
    c.cancelled_count, 
    t.total_count,
    ROUND((c.cancelled_count::NUMERIC / t.total_count) * 100, 2) AS cancellation_rate
FROM TotalOrders t
JOIN CancelledOrders c ON t.fulfilment = c.fulfilment;

-- 6. Identifying "Dead Weight" Inventory
SELECT 
    size, 
    SUM(amount) AS total_revenue
FROM amazon_sales
--WHERE amount IS NOT NULL
GROUP BY size
HAVING SUM(amount) < 5000
ORDER BY total_revenue ASC;

-- 7. Bulk Buying Habits
SELECT 
    category, 
    AVG(qty) AS avg_qty_per_order
FROM amazon_sales
GROUP BY category
ORDER BY avg_qty_per_order DESC;

-- 8. Courier Status Discrepancies
SELECT 
    status, 
    courier_status, 
    COUNT(*) AS total_errors, 
    SUM(amount) AS lost_revenue
FROM amazon_sales
WHERE status = 'Cancelled' AND courier_status = 'Shipped'
GROUP BY status, courier_status;


-- ====================================================================================
-- CATEGORY 3: GEOGRAPHIC & MARKET EXPANSION
-- ====================================================================================

-- 9. The Emerging Markets
SELECT 
    shistate, 
    SUM(amount) AS total_revenue
FROM amazon_sales
WHERE ship_state != 'MAHARASHTRA' AND amount IS NOT NULL
GROUP BY ship_state
ORDER BY total_revenue DESC
LIMIT 5;

-- 10. The High-Volume, Low-Value Trap
SELECT 
    ship_state, 
    COUNT(*) AS total_orders, 
    AVG(amount) AS avg_order_value
FROM amazon_sales
WHERE amount IS NOT NULL
GROUP BY ship_state
HAVING COUNT(*) > 5000
ORDER BY avg_order_value ASC
LIMIT 5;

-- 11. Regional Product Preferences
WITH StateCategoryRanks AS (
    SELECT 
        state, 
        category, 
        SUM(qty) AS total_qty,
        ROW_NUMBER() OVER (PARTITION BY state ORDER BY SUM(qty) DESC) AS rank
    FROM amazon_sales
    GROUP BY state, category
)
SELECT 
    state, 
    category AS top_category, 
     total_qty 
FROM StateCategoryRanks
WHERE rank = 1;

-- 12. The City Dependency Risk
WITH StateTotal AS (
    SELECT SUM(amount) AS total_rev 
    FROM amazon_sales 
    WHERE ship_state = 'KARNATAKA' AND amount IS NOT NULL
),
CityTotal AS (
    SELECT SUM(amount) AS city_rev 
    FROM amazon_sales 
    WHERE ship_city = 'BENGALURU' AND ship_state = 'KARNATAKA' AND amount IS NOT NULL
)
SELECT 
    c.city_rev, 
    s.total_rev, 
    ROUND((c.city_rev / s.total_rev::NUMERIC) * 100, 2) AS city_dependency_pct
FROM CityTotal c, StateTotal s;


-- ====================================================================================
-- CATEGORY 4: CUSTOMER BEHAVIOR & MARKETING
-- ====================================================================================

-- 13. The Promo Code Reality Check
WITH PromoFlags AS (
    SELECT 
        qty,
        CASE 
            WHEN promotion_ids IS NOT NULL THEN 'Promo Used' 
            ELSE 'No Promo' 
        END AS promo_status
    FROM amazon_sales
)
SELECT 
    promo_status, 
    AVG(qty) AS avg_qty_per_order
FROM PromoFlags
GROUP BY promo_status;

-- 14. Seasonal Promo Adoption
SELECT 
    TO_CHAR(date::DATE, 'YYYY-MM') AS month, 
    COUNT(*) AS promo_order_count
FROM amazon_sales
WHERE promotion_ids IS NOT NULL
GROUP BY TO_CHAR(date::DATE, 'YYYY-MM')
ORDER BY promo_order_count DESC;

-- 15. Expedited Shipping Value
SELECT 
    ship_service_level, 
    AVG(amount) AS avg_order_value,
    COUNT(*) AS total_orders
FROM amazon_sales
WHERE amount IS NOT NULL
GROUP BY ship_service_level;


select * from amazon_sales;

ALTER TABLE amazon_sales
rename column n to id ;