USE inventory;

SELECT
	*
FROM
	inventory_data;

--- INVENTORY OPTIMIZATION & FORECASTING SQL QUERIES ---
--Objective: Calculate critical inventory KPIs to optimize stock level, reduce costs, and minimize stockouts.


--- 1️ Economic Order Quantity (EOQ)
		-- Formula: EOQ = SQRT( (2 * D * S) / H )
		-- D = Number_of_products_sold (Annualized)
		-- S = Ordering Cost (proxy: average Shipping_costs)
		-- H = Holding Cost per unit per year (we assume 20% of Price)

SELECT 
    SKU,
    Product_type,
    Number_of_products_sold AS Annual_Demand,
    Shipping_costs AS Ordering_Cost,
    Price * 0.2 AS Holding_Cost,
    ROUND(SQRT((2 * Number_of_products_sold * Shipping_costs) / (Price * 0.2)), 2) AS EOQ
FROM inventory_data;


--- 2️ Reorder Point (ROP)
	-- Formula: ROP = (Daily Demand × Lead Time) + Safety Stock
	-- Daily Demand = Number_of_products_sold / 365
	-- Safety Stock (assume 10% of lead time demand for now)

SELECT 
    SKU,
    Product_type,
    ROUND(Number_of_products_sold / 365.0, 2) AS Daily_Demand,
    Lead_times,
    ROUND((Number_of_products_sold / 365.0) * Lead_times, 2) AS Lead_Time_Demand,
    ROUND(((Number_of_products_sold / 365.0) * Lead_times) * 0.1, 2) AS Safety_Stock,
    ROUND(((Number_of_products_sold / 365.0) * Lead_times) * 1.1, 2) AS Reorder_Point
FROM inventory_data;


--- 3️ Inventory Turnover Ratio
	-- Formula: Inventory Turnover = Cost of Goods Sold / Average Inventory
	-- Proxy: Revenue_generated / Stock_levels

SELECT 
    SKU,
    Product_type,
    Revenue_generated,
    Stock_levels,
    ROUND(Revenue_generated / NULLIF(Stock_levels, 0), 2) AS Inventory_Turnover
FROM inventory_data;

--- 4️ Days Sales of Inventory (DSI)
	-- Formula: DSI = (Average Inventory / COGS) × 365
	-- Proxy: (Stock_levels / Revenue_generated) × 365

SELECT 
    SKU,
    Product_type,
    ROUND((Stock_levels / NULLIF(Revenue_generated, 0)) * 365, 2) AS Days_Sales_of_Inventory
FROM inventory_data;

--- 5️ Low Stock Alert (Stock Below Reorder Point)
	-- Use the same logic from ROP calculation above

SELECT 
    SKU,
    Product_type,
    Stock_levels,
    ROUND(((Number_of_products_sold / 365.0) * Lead_times) * 1.1, 2) AS Reorder_Point,
    CASE 
        WHEN Stock_levels < ROUND(((Number_of_products_sold / 365.0) * Lead_times) * 1.1, 2)
        THEN ' Restock Needed'
        ELSE ' Stock Sufficient'
    END AS Status
FROM inventory_data;

--- 6️ Overstock Flag (Stock Far Above EOQ)
	-- If Stock Level > 2x EOQ, flag as overstock

WITH eoq_calc AS (
    SELECT 
        SKU,
        ROUND(SQRT((2 * Number_of_products_sold * Shipping_costs) / (Price * 0.2)), 2) AS EOQ
    FROM inventory_data
)
SELECT 
    i.SKU,
    i.Product_type,
    i.Stock_levels,
    e.EOQ,
    CASE 
        WHEN i.Stock_levels > 2 * e.EOQ THEN 'Overstocked'
        ELSE 'OK'
    END AS Overstock_Status
FROM inventory_data i
JOIN eoq_calc e ON i.SKU = e.SKU;


--- SUPPLIER PERFORMANCE ANALYSIS SQL QUERIES ---
-- Objective: Measure supplier reliability, cost efficiency, and product quality impact

--- 7️ Supplier Lead Time Analysis
	-- Calculate average lead time per supplier

SELECT 
    Supplier_name,
    Location,
    ROUND(AVG(Lead_time), 2) AS Avg_Lead_Time
FROM inventory_data
GROUP BY Supplier_name, Location;

--- 8️ Supplier Reliability Score
	-- Proxy Score = On-Time Delivery Percentage
	-- Assume 'expected lead time' = median lead time, and score is variance from it (lower is better)

WITH lead_stats AS (
    SELECT 
        Supplier_name,
        Lead_time,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY Lead_time) OVER (PARTITION BY Supplier_name) AS Median_Lead_Time
    FROM inventory_data
)
SELECT 
    i.Supplier_name,
    i.Location,
    l.Median_Lead_Time,
    ROUND(AVG(ABS(i.Lead_time - l.Median_Lead_Time)), 2) AS Avg_Lead_Time_Variance,
    CASE 
        WHEN AVG(ABS(i.Lead_time - l.Median_Lead_Time)) < 3 THEN 'Reliable'
        WHEN AVG(ABS(i.Lead_time - l.Median_Lead_Time)) < 7 THEN 'Moderate'
        ELSE 'Unreliable'
    END AS Reliability_Status
FROM inventory_data i
JOIN lead_stats l ON i.Supplier_name = l.Supplier_name
GROUP BY i.Supplier_name, i.Location, l.Median_Lead_Time;

--- 9️ Defect Rate per Supplier
	-- Total defects / total units produced

SELECT 
    Supplier_name,
    SUM(Production_volumes * Defect_rates) AS Total_Defects,
    SUM(Production_volumes) AS Total_Produced,
    ROUND(SUM(Production_volumes * Defect_rates) / NULLIF(SUM(Production_volumes), 0), 4) AS Defect_Rate
FROM inventory_data
GROUP BY Supplier_name;

--- 10. Cost per Unit Produced by Supplier
	-- Formula: Manufacturing_costs / Production_volumes

SELECT 
    Supplier_name,
    ROUND(SUM(Manufacturing_costs) / NULLIF(SUM(Production_volumes), 0), 2) AS Cost_Per_Unit
FROM inventory_data
GROUP BY Supplier_name;

---  TRANSPORT & SHIPPING EFFICIENCY SQL QUERIES --
-- Objective: Evaluate cost efficiency, delivery speed, and carrier performance

--- 1️1 Average Shipping Time by Carrier

SELECT 
    Shipping_carriers,
    ROUND(AVG(Shipping_times), 2) AS Avg_Shipping_Time
FROM inventory_data
GROUP BY Shipping_carriers;

--- 12 Shipping Cost per Unit Sold

SELECT 
    SKU,
    Product_type,
    ROUND(Shipping_costs / NULLIF(Number_of_products_sold, 0), 2) AS Shipping_Cost_per_Unit
FROM inventory_data;

--- 13 Route Efficiency (Cost per Distance or per Shipment)

SELECT 
    Routes,
    Transportation_modes,
    ROUND(AVG(Costs), 2) AS Avg_Route_Cost
FROM inventory_data
GROUP BY Routes, Transportation_modes;

--- 14 Shipping Performance by Carrier

SELECT 
    Shipping_carriers,
    ROUND(AVG(Shipping_times), 2) AS Avg_Time,
    ROUND(AVG(Shipping_costs), 2) AS Avg_Cost,
    COUNT(*) AS Shipments
FROM inventory_data
GROUP BY Shipping_carriers;

--- 15 High-Cost Carrier Flag
	-- Identify carriers with cost above average of all

WITH avg_carrier_cost AS (
    SELECT AVG(Shipping_costs) AS avg_cost FROM inventory_data
)
SELECT 
    Shipping_carriers,
    ROUND(AVG(Shipping_costs), 2) AS Avg_Cost,
    CASE 
        WHEN ROUND(AVG(Shipping_costs), 2) > (SELECT avg_cost FROM avg_carrier_cost) THEN 'High Cost'
        ELSE 'Efficient'
    END AS Cost_Status
FROM inventory_data
GROUP BY Shipping_carriers;

---  SALES & CUSTOMER INSIGHTS ---
-- Objective: Uncover product trends, customer demographics, and revenue drivers

--- 1️6 Total Revenue per Product Type

SELECT 
    Product_type,
    SUM(Revenue_generated) AS Total_Revenue
FROM inventory_data
GROUP BY Product_type;

--- 17 Revenue per SKU and Price Band
	-- Group prices into bands to analyze pricing strategy

SELECT 
    SKU,
    Product_type,
    Price,
    CASE 
        WHEN Price < 20 THEN 'Low'
        WHEN Price BETWEEN 20 AND 50 THEN 'Medium'
        ELSE 'High'
    END AS Price_Band,
    Revenue_generated
FROM inventory_data;

--- 18 Customer Segment Performance
	-- Revenue per gender/demographic

SELECT 
    Customer_demographics,
    COUNT(*) AS Customers,
    SUM(Revenue_generated) AS Revenue
FROM inventory_data
GROUP BY Customer_demographics;

--- 19 Top-Selling Products

SELECT TOP 10
    SKU,
    Product_type,
    Number_of_products_sold,
    Revenue_generated
FROM inventory_data
ORDER BY Number_of_products_sold DESC;

--- 20 Profitability Estimate per SKU
	-- Proxy: Revenue - Manufacturing & Shipping Costs

SELECT 
    SKU,
    Product_type,
    Revenue_generated,
    Manufacturing_costs + Shipping_costs AS Total_Cost,
    Revenue_generated - (Manufacturing_costs + Shipping_costs) AS Estimated_Profit
FROM inventory_data;

--- 21 Sales vs Stock Analysis
	-- Identify overstocked but underselling items

SELECT 
    SKU,
    Product_type,
    Stock_levels,
    Number_of_products_sold,
    CASE 
        WHEN Stock_levels > Number_of_products_sold * 3 THEN 'Overstocked / Slow Mover'
        ELSE 'Normal'
    END AS Movement_Flag
FROM inventory_data;


---  ADVANCED INSIGHT 
-- Objective: Generate actionable insights based on combined metrics across domains

--- 22 SKUs with High Revenue but Low Inventory Turnover (Potential Overstock)

WITH turnover AS (
    SELECT 
        SKU,
        ROUND(Revenue_generated / NULLIF(Stock_levels, 0), 2) AS Turnover,
        Revenue_generated
    FROM inventory_data
)
SELECT 
    SKU,
    Revenue_generated,
    Turnover,
    CASE WHEN Turnover < 1 THEN 'Overstock Risk' ELSE 'OK' END AS Status
FROM turnover
WHERE Revenue_generated > (SELECT AVG(Revenue_generated) FROM inventory_data);

--- 2️3 Suppliers with Low Defect Rate but High Lead Time (Tradeoff Evaluation)

WITH lead_quality AS (
    SELECT 
        Supplier_name,
        AVG(Lead_time) AS Avg_Lead_Time,
        ROUND(SUM(Production_volumes * Defect_rates) / NULLIF(SUM(Production_volumes), 0), 4) AS Defect_Rate
    FROM inventory_data
    GROUP BY Supplier_name
)
SELECT 
    *,
    CASE 
        WHEN Avg_Lead_Time > 25 AND Defect_Rate < 0.01 THEN 'High Quality, Slow Supply'
        ELSE 'OK'
    END AS Insight
FROM lead_quality;

--- 24 Customer Segments with High Spend but Long Shipping Times

SELECT 
    Customer_demographics,
    ROUND(AVG(Revenue_generated), 2) AS Avg_Revenue,
    ROUND(AVG(Shipping_times), 2) AS Avg_Shipping_Time,
    CASE 
        WHEN AVG(Revenue_generated) > (SELECT AVG(Revenue_generated) FROM inventory_data)
         AND AVG(Shipping_times) > (SELECT AVG(Shipping_times) FROM inventory_data)
        THEN 'Improve Delivery to High-Value Customers'
        ELSE 'OK'
    END AS Recommendation
FROM inventory_data
GROUP BY Customer_demographics;

---- LOAD DATABASE --

ALTER TABLE inventory_data
ADD 
    EOQ DECIMAL(10,2),
    Reorder_Point DECIMAL(10,2),
    Inventory_Turnover DECIMAL(10,2),
    Days_Sales_of_Inventory INT,
    Low_Stock_Status VARCHAR(50),
    Overstock_Status VARCHAR(50),
    Daily_Demand DECIMAL(10,2),
    Lead_Time_Demand DECIMAL(10,2),
    Safety_Stock DECIMAL(10,2),
    Movement_Flag VARCHAR(50);

-- Start transaction for safety
BEGIN TRANSACTION;

-- Define the CTE to compute all metrics
WITH CalculatedValues AS (
    SELECT 
        SKU,
        Number_of_products_sold,
        Shipping_costs,
        Price,
        Lead_times,
        Stock_levels,
        Revenue_generated,

        -- Calculations
        ROUND(SQRT((2 * Number_of_products_sold * Shipping_costs) / (Price * 0.2)), 2) AS EOQ,
        ROUND(((Number_of_products_sold / 365.0) * Lead_times) * 1.1, 2) AS Reorder_Point,
        ROUND(Number_of_products_sold / 365.0, 2) AS Daily_Demand,
        ROUND((Number_of_products_sold / 365.0) * Lead_times, 2) AS Lead_Time_Demand,
        ROUND((Number_of_products_sold / 365.0) * Lead_times * 0.1, 2) AS Safety_Stock,
        ROUND(Revenue_generated / NULLIF(Stock_levels, 0), 2) AS Inventory_Turnover,
        ROUND((Stock_levels / NULLIF(Revenue_generated, 0)) * 365, 0) AS Days_Sales_of_Inventory,
        CASE 
            WHEN Stock_levels < ((Number_of_products_sold / 365.0) * Lead_times * 1.1) THEN 'Restock Needed'
            ELSE 'Stock Sufficient'
        END AS Low_Stock_Status,
        CASE 
            WHEN Stock_levels > 2 * ROUND(SQRT((2 * Number_of_products_sold * Shipping_costs) / (Price * 0.2)), 2)
            THEN 'Overstocked'
            ELSE 'OK'
        END AS Overstock_Status,
        CASE 
            WHEN Stock_levels > Number_of_products_sold * 3 THEN 'Overstocked / Slow Mover'
            ELSE 'Normal'
        END AS Movement_Flag
    FROM inventory_data
)
UPDATE i
SET
    i.EOQ = c.EOQ,
    i.Reorder_Point = c.Reorder_Point,
    i.Inventory_Turnover = c.Inventory_Turnover,
    i.Days_Sales_of_Inventory = c.Days_Sales_of_Inventory,
    i.Low_Stock_Status = c.Low_Stock_Status,
    i.Overstock_Status = c.Overstock_Status,
    i.Daily_Demand = c.Daily_Demand,
    i.Lead_Time_Demand = c.Lead_Time_Demand,
    i.Safety_Stock = c.Safety_Stock,
    i.Movement_Flag = c.Movement_Flag
FROM inventory_data i
INNER JOIN CalculatedValues c ON i.SKU = c.SKU;

-- Commit the changes
COMMIT;