USE supply_db;
-- 1. Get the number of orders by the Type of Transaction excluding the orders shipped from Sangli and Srinagar. 
-- Also, exclude the SUSPECTED_FRAUD cases based on the Order Status, 
-- and sort the result in the descending order based on the number of orders

-- SELECT Total_Order,Type
-- FROM
-- (
-- SELECT COUNT(DISTINCT o.order_id) as Total_order,o.Type,o.Order_City,o.Order_Status
-- FROM orders as o
-- GROUP BY o.Type
-- HAVING o.Order_City <> 'Sangli' AND o.Order_City <> 'Srinagar' AND o.Order_Status <> 'SUSPECTED_FRAUD'
-- ORDER BY COUNT(DISTINCT o.order_id) DESC
-- ) As order_details;

SELECT Total_Order,Type FROM
(
SELECT COUNT(DISTINCT order_id) as Total_order,type,order_city,order_status FROM orders
WHERE Order_City <> 'Sangli' AND order_city <> 'Srinagar' AND Order_Status <> 'SUSPECTED_FRAUD'
GROUP BY Type
ORDER BY Total_order DESC
)as a;

-- 2. Get the list of the Top 3 customers based on the completed orders along with the following details:
-- Customer Id,Customer First Name,Customer City,Customer State,Number of completed orders,Total Sales
-- Tables required: customer_info-Customer Id,Customer First Name,Customer City,Customer State,
-- orders - Number of completed orders(order_status),ordered_items - Total_sales
WITH order_summary AS
(select ord.order_id,ord.customer_id, SUM(sales) AS ord_sales
from orders as ord
JOIN ordered_items as itm
ON ord.order_id=itm.order_id
WHERE ord.order_status='COMPLETE'
GROUP BY ord.order_id)
SELECT Id AS Customer_id,
First_Name AS Customer_First_Name, 
City AS Customer_City, 
State AS Customer_State,
COUNT(DISTINCT order_id) as Completed_Orders,
SUM(ord_sales) as Total_Sales
FROM 
order_summary as ord
INNER JOIN
customer_info as cust
ON ord.customer_id=cust.id
GROUP BY Customer_id,Customer_City,Customer_First_Name
ORDER BY Completed_Orders DESC, Total_Sales DESC
LIMIT 3;
-- Lessons learned : Atfirst we need to work on the order table level and get the required order details
-- Next we need to merge all the details at the customer table level

-- 3. Get the order count by the Shipping Mode and the Department Name. Consider departments 
-- with at least 40 closed/completed orders
-- Tables reqd. - orders - Shipping Mode,   ,Need the product table to connect with Department - only those departments with #order >= 40
WITH Joined_tables
AS(
SELECT Shipping_Mode,ord.Order_id,order_status,dept.Name as Dept_Name
FROM orders as ord
JOIN ordered_items as itm
ON ord.Order_id = itm.order_id
JOIN product_info as prod
ON itm.item_id = prod.product_id
JOIN Department as dept
ON prod.department_id = dept.id
),
Dept_Summary AS(
SELECT Dept_Name,COUNT(Order_id) as Total_orders FROM Joined_Tables
WHERE Order_status IN ('COMPLETE','CLOSED')
GROUP BY Dept_name),
Dept_list AS(
SELECT distinct dept_name FROM Dept_Summary
WHERE Total_orders >=40)
SELECT Shipping_Mode,Dept_Name,COUNT(order_id) as Total_orders
FROM Joined_tables
WHERE dept_name IN (select * FROM dept_list)
GROUP BY Shipping_Mode,Dept_Name;

-- Lessons learnt :  Here we learnt how to use multiple CTEs for a single query using the ','.
-- We also learnt how to unfold the lengthy question and group it into smaller parts. 

-- 4.Create a new field as shipment compliance based on Real_Shipping_Days and Scheduled_Shipping_Days. 
-- It should have the following values:
-- Cancelled shipment: If the Order Status is SUSPECTED_FRAUD or CANCELED
-- Within schedule: If shipped within the scheduled number of days 
-- On time: If shipped exactly as per schedule
-- Up to 2 days of delay: If shipped beyond schedule but delayed by 2 days
-- Beyond 2 days of delay: If shipped beyond schedule with a delay of more than 2 days
-- SELECT Order_status,Shipment_Compliance
-- FROM(
WITH Shipment_details AS (
SELECT order_id,Real_Shipping_Days,Scheduled_Shipping_Days,Shipping_Mode,Order_status,
CASE WHEN order_status IN ('SUSPECTED_FRAUD','CANCELED') THEN 'Cancelled shipment'
	 WHEN Real_Shipping_Days < Scheduled_Shipping_Days THEN 'Within Scheduled'
     WHEN Real_Shipping_Days = Scheduled_Shipping_Days THEN 'On Time'
     WHEN Real_Shipping_Days <= (Scheduled_Shipping_Days+2) THEN 'Up to 2 days of delay'
     WHEN Real_Shipping_Days > (Scheduled_Shipping_Days+2) THEN 'Beyond to 2 days of delay'
ELSE 'Others'
END AS Shipment_Compliance
FROM orders
having Shipment_Compliance IN ('Up to 2 days of delay','Beyond to 2 days of delay')
ORDER BY Shipping_mode DESC ,Shipment_Compliance)
SELECT Shipping_Mode, COUNT(Shipment_compliance) as delayed_orders
FROM Shipment_details
GROUP BY Shipping_Mode
ORDER BY delayed_orders DESC;

-- 5. An order is canceled when the status of the order is either CANCELED or SUSPECTED_FRAUD. 
-- Obtain the list of states by the order cancellation% and sort them in the descending order of the cancellation%.
-- Definition: Cancellation% = Cancelled order / Total orders
-- Tables: orders - order_status, order_state
WITH cancelled_orders as
(
SELECT Count(order_id) as Cancelled,order_state
FROM orders
WHERE order_status IN ('Canceled','SUSPECTED_FRAUD')
GROUP BY order_state),
Total_orders as
(
SELECT Count(order_id) as Total,order_state
FROM orders
GROUP BY order_state
)
SELECT t.order_state,(Cancelled/Total) as Cancelled_per FROM cancelled_orders as c
RIGHT JOIN
total_orders as t
ON c.order_state = t.order_state
ORDER BY Cancelled_per DESC;

-- List all customer names, cities, streets of all the customers who have orders in a pending
-- state and shipping mode as first class

SELECT First_Name AS Customer_Name,
       City,
       Street,
       State,
       Shipping_Mode
FROM orders as o
INNER JOIN customer_info as ci
ON ci.id = o.customer_id
WHERE Order_Status IN ("PENDING") AND Shipping_Mode="First Class";

-- . How many completed orders were shipped via first-class mode?
SELECT COUNT(order_id) AS Order_count
FROM orders
WHERE order_status = "Complete" AND shipping_mode = "First Class";

-- What is the average product price of category_id ranging 0-10, 20- 30?
SELECT Category_id,
       AVG(Product_Price) AS avg_price
       FROM product_info
WHERE category_id BETWEEN 0 AND 10 OR Product_Price BETWEEN 20 AND 30
GROUP BY category_id;

-- Calculate rank, dense_rank and row number for the dates of November based on the total
-- number of orders received.(Same number -> arrange with ascending order of date)
-- What are the total number of orders for dense_rank = 15?
-- First Part
SELECT order_date,
       COUNT(order_id) AS Total_orders,
       RANK() OVER(ORDER BY COUNT(order_id) DESC) AS Rank_,
       DENSE_RANK() OVER(ORDER BY COUNT(order_id) DESC) AS Dense_Rank_,
       ROW_NUMBER() OVER(ORDER BY COUNT(order_id) DESC) AS Row_Number_
FROM orders
WHERE MONTH(Order_date) = 11
GROUP BY order_date;
-- Second part
WITH order_details as
(SELECT order_date,
       COUNT(order_id) AS Total_orders,
       RANK() OVER(ORDER BY COUNT(order_id) DESC) AS Rank_,
       DENSE_RANK() OVER(ORDER BY COUNT(order_id) DESC) AS Dense_Rank_,
       ROW_NUMBER() OVER(ORDER BY COUNT(order_id) DESC) AS Row_Number_
FROM orders
WHERE MONTH(Order_date) = 11 
GROUP BY order_date)
SELECT * FROM order_details
WHERE Dense_Rank_ = 15;
-- From the orders & ordered_items table, calculate the last 5 day moving averages for
-- average sales of a date where the month is december 2018.
-- Sort on the basis of dates in ascending order.
SELECT order_date,AVG(date_avg) OVER(ORDER BY order_date ROWS 5 PRECEDING) AS Moving_5_Day_Avg
FROM 
(
SELECT order_date,AVG(Sales) as date_avg 
FROM ordered_items as oi
INNER JOIN orders as o
ON oi.order_id=o.order_id
WHERE MONTH(order_date) = 12 AND year(order_date)=2018
GROUP BY order_date
) as a;


