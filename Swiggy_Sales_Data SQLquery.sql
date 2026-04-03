select * from swiggy_data;

-- Data Validation & Cleaning
-- Null values

SELECT
	SUM(CASE WHEN State IS NULL THEN 1 ELSE 0 END) As null_state,
	SUM(CASE WHEN City IS NULL THEN 1 ELSE 0 END) As null_city,
	SUM(CASE WHEN Order_date IS NULL THEN 1 ELSE 0 END) As null_order_date,
	SUM(CASE WHEN Restaurant_Name IS NULL THEN 1 ELSE 0 END) As null_restaurant,
	SUM(CASE WHEN Location IS NULL THEN 1 ELSE 0 END) As null_location,
	SUM(CASE WHEN Category IS NULL THEN 1 ELSE 0 END) As null_category,
	SUM(CASE WHEN Dish_Name IS NULL THEN 1 ELSE 0 END) As null_dish,
	SUM(CASE WHEN Price_INR IS NULL THEN 1 ELSE 0 END) As null_price,
	SUM(CASE WHEN Rating IS NULL THEN 1 ELSE 0 END) As null_rating,
	SUM(CASE WHEN Rating_Count IS NULL THEN 1 ELSE 0 END) As null_rating_count 
FROM swiggy_data;

-- Blank Strings

SELECT *
FROM swiggy_data
WHERE
State = '' OR City = '' OR Location = '' OR Category = '' OR Dish_Name = '';


-- Detect Duplicates
SELECT
State, City, order_date, restaurant_name,location,category, dish_name, price_INR, rating, rating_count, count(*) as CNT
FROM swiggy_data
GROUP BY
State, City, order_date, restaurant_name,location,category, dish_name, price_INR, rating, rating_count
HAVING count(*) >1;

-- Delete Duplicates
WITH CTE AS (
SELECT *, ROW_NUMBER () Over(
	PARTITION BY State, City, order_date, restaurant_name,location,category, dish_name, price_INR, rating, rating_count
ORDER BY (SELECT NULL)
) AS rn
FROM swiggy_data
)
DELETE FROM CTE WHERE rn>1

--CREATE SCHEMA
--DIMENSION TABLES
-- DATE TABLE

CREATE TABLE dim_date(
	date_id INT IDENTITY (1,1) PRIMARY KEY,
	FULL_DATE DATE,
	YEAR INT,
	MONTH INT,
	Month_Name varchar(20),
	Quarter INT,
	Day INT,
	Week INT
	)

-- dim location
CREATE TABLE dim_location(
location_id INT IDENTITY(1,1) PRIMARY KEY,
State VARCHAR (100),
City VARCHAR (100),
Location VARCHAR (200)
);

-- dim restaurant
CREATE TABLE dim_restaurant(
restaurant_id INT IDENTITY (1,1) PRIMARY KEY,
Restaurant_Name VARCHAR (200),
);

-- dim category
CREATE TABLE dim_category(
category_id INT IDENTITY(1,1) PRIMARY KEY,
Category VARCHAR (200),
);

-- dim_dish
CREATE TABLE dim_dish(
dish_id INT IDENTITY(1,1) PRIMARY KEY,
Dish_name VARCHAR (200),
);

-- FACT TABLE
CREATE TABLE fact_swiggy_orders(
order_id INT IDENTITY (1,1) PRIMARY KEY,

date_id INT,
Price_INR DECIMAL (10,2),
Rating DECIMAL (4,2),
Rating_count INT,

location_id INT,
restaurant_id INT,
category_id INT,
dish_id INT,

FOREIGN KEY (date_id) REFERENCES dim_date(date_id),
FOREIGN KEY (location_id) REFERENCES dim_location(location_id),
FOREIGN KEY (restaurant_id) REFERENCES dim_restaurant(restaurant_id),
FOREIGN KEY (category_id) REFERENCES dim_category(category_id),
FOREIGN KEY (dish_id) REFERENCES dim_dish(dish_id),
);

SELECT * FROM fact_swiggy_orders;

--INSERT DATA IN TABLES
--dim date
INSERT INTO dim_date (Full_Date, Year, Month, Month_Name, Quarter, Day, Week)
SELECT DISTINCT
	Order_Date,
	YEAR(Order_Date),
	MONTH(Order_Date),
	DATENAME(MONTH, Order_Date),
	DATEPART(QUARTER, Order_Date),
	DAY(Order_Date),
	DATEPART(WEEK, Order_Date)
FROM swiggy_data
WHERE Order_Date IS NOT NULL;

-- dim location
INSERT INTO dim_location (State, City, Location)
SELECT DISTINCT
	State,
	City,
	Location 
FROM swiggy_data;

--dim restaurant
INSERT INTO dim_restaurant (Restaurant_Name)
SELECT DISTINCT
	Restaurant_Name
FROM swiggy_data;

--dim category
INSERT INTO dim_category(category)
SELECT DISTINCT
	Category
FROM swiggy_data;

--dim dish
INSERT INTO dim_dish(Dish_Name)
SELECT DISTINCT 
	Dish_Name
FROM swiggy_data;

--Insert dimensions into fact_table
INSERT INTO fact_swiggy_orders
(
	date_id,
	Price_INR,
	Rating,
	Rating_Count,
	location_id,
	restaurant_id,
	category_id,
	dish_id
)
SELECT
	dd.date_id,
	s.Price_INR,
	s.Rating,
	s.Rating_Count,

	dl.location_id,
	dr.restaurant_id,
	dc.category_id,
	dsh.dish_id
FROM swiggy_data s

JOIN dim_date dd
	ON dd.Full_Date = s.Order_Date

JOIN dim_location dl
	ON dl.State = s.State
	AND dl.city = s.City
	AND dl.Location = s.Location

JOIN dim_restaurant dr
	ON dr.Restaurant_Name = s.Restaurant_Name
	
JOIN dim_category dc
	ON dc.Category = s.Category

JOIN dim_dish dsh
	ON dsh.Dish_Name = s.Dish_Name;

SELECT * FROM fact_swiggy_orders;

SELECT * FROM fact_swiggy_orders f
JOIN dim_date d ON f.date_id = d.date_id
JOIN dim_location l ON f.location_id = l.location_id
JOIN dim_restaurant r ON f.restaurant_id = r.restaurant_id
JOIN dim_category c ON f.category_id = c.category_id
JOIN dim_dish di ON f.dish_id = di.dish_id;

-- KPI's
--Total orders
SELECT COUNT(*) AS Total_orders
FROM fact_swiggy_orders;

--Total Revenue (INR Million)
SELECT
FORMAT(SUM(CONVERT(FLOAT,price_INR))/1000000, 'N2') +'INR Million'
AS Total_Revenue
FROM fact_swiggy_orders;

--Average Dish Price
SELECT 
FORMAT(AVG(CONVERT(FLOAT,price_INR)), 'N2') 
AS Avg_Dish_Price
FROM fact_swiggy_orders;

--Average Rating
SELECT AVG(Rating)
AS Avg_Rating
FROM fact_swiggy_orders;

--Monthly Order Trends
SELECT
d.year,
d.month,
d.month_name,
count(*) AS Total_Orders
FROM fact_swiggy_orders f
JOIN dim_date d ON f.date_id = d.date_id
GROUP BY 
d.year,
d.month,
d.month_name
ORDER BY count(*) DESC;

--Total Revenue by Month
SELECT
d.year,
d.month,
d.month_name,
SUM (price_INR) AS Total_Revenue
FROM fact_swiggy_orders f
JOIN dim_date d ON f.date_id = d.date_id
GROUP BY 
d.year,
d.month,
d.month_name
ORDER BY SUM (price_INR) DESC;

--Quarterly Trend
SELECT
d.year,
d.quarter,
count(*) AS Total_orders
FROM fact_swiggy_orders f
JOIN dim_date d ON f.date_id = d.date_id
GROUP BY 
d.year,
d.quarter
ORDER BY count(*);

--Orders by Day of Week (Mon-Sun)
SELECT
	DATENAME(WEEKDAY,d.full_date) AS Day_Name,
	COUNT(*) AS total_orders
FROM fact_swiggy_orders f
JOIN dim_date d ON f.date_id = d.date_id
GROUP BY DATENAME(WEEKDAY,d.full_date), DATEPART(WEEKDAY,d.full_date)
ORDER BY DATEPART(WEEKDAY,d.full_date);

--Top 10 cities by Order Volume
SELECT TOP 10
l.city,
COUNT(*) AS Total_orders FROM fact_swiggy_orders f
JOIN dim_location l ON l.location_id = f.location_id
GROUP BY l.city
ORDER BY COUNT(*) DESC ;

--Revenue Contribution By States
SELECT TOP 10
l.state,
SUM(Price_INR) AS Total_orders FROM fact_swiggy_orders f
JOIN dim_location l ON l.location_id = f.location_id
GROUP BY l.state
ORDER BY SUM(Price_INR) DESC ;

--Top 10 Restaurants by Orders
SELECT TOP 10
r.restaurant_name,
SUM(f.Price_INR) AS Total_orders FROM fact_swiggy_orders f
JOIN dim_restaurant r ON r.restaurant_id = f.restaurant_id
GROUP BY r.Restaurant_Name
ORDER BY SUM(f.Price_INR) DESC ;

--Top Categories by Order volume
SELECT 
c.category,
COUNT(*) AS Total_orders FROM fact_swiggy_orders f
JOIN dim_category c ON f.category_id = c.category_id
GROUP BY c.category
ORDER BY COUNT(*) DESC ;

--Most Ordered Dish
SELECT 
d.dish_name,
COUNT(*) AS Order_count FROM fact_swiggy_orders f
JOIN dim_dish d ON f.dish_id = d.dish_id
GROUP BY d.dish_name
ORDER BY COUNT(*) DESC ;

--Cuisine Performance (Orders+Avg Rating)
SELECT
	c.category,
	COUNT(*) AS total_orders,
	AVG(f.rating) AS Avg_Rating
	FROM fact_swiggy_orders f
	JOIN dim_category c ON f.category_id = c.category_id
	GROUP BY c.category
	ORDER BY total_orders DESC;

