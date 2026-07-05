-- ---------------------------
-- Analysis & reports
-- ---------------------------

-- 1. Write a query to find the top 5 mostly ordered dishes by customer callled "Arjun Mehta" in the last 1 year.

WITH CTE AS
(
	SELECT t2.order_item,COUNT(*) AS "Mostly_ordered"
	FROM customers t1
	JOIN orders t2
	ON t1.customer_id = t2.customer_id
	WHERE customer_name = "Arjun Mehta"  AND t2.order_date >= CURRENT_DATE - INTERVAL 3 YEAR
	GROUP BY order_item
	ORDER BY Mostly_ordered DESC
), 
RANKED_CTE AS
(
	SELECT  *,
	DENSE_RANK() OVER(ORDER BY Mostly_ordered DESC) AS "Rank"
	FROM CTE
) 
SELECT order_item,mostly_ordered 
FROM RANKED_CTE
WHERE RANKED_CTE.Rank <= 5;

-- 2. Identify the time slots during which the most orders are placed, based on 2-hours intervals

-- Approach 1

SELECT 
	CASE 
		WHEN HOUR(order_time) BETWEEN 0 AND 1 THEN '00:00 - 02:00'
		WHEN HOUR(order_time) BETWEEN 2 AND 3 THEN '02:00 - 04:00'        
		WHEN HOUR(order_time) BETWEEN 4 AND 5 THEN '04:00 - 06:00'
		WHEN HOUR(order_time) BETWEEN 6 AND 7 THEN '06:00 - 08:00'
		WHEN HOUR(order_time) BETWEEN 8 AND 9 THEN '08:00 - 10:00'
		WHEN HOUR(order_time) BETWEEN 10 AND 11 THEN '10:00 - 12:00'
		WHEN HOUR(order_time) BETWEEN 12 AND 13 THEN '12:00 - 14:00'
		WHEN HOUR(order_time) BETWEEN 14 AND 15 THEN '14:00 - 16:00'
		WHEN HOUR(order_time) BETWEEN 16 AND 17 THEN '16:00 - 18:00'
		WHEN HOUR(order_time) BETWEEN 18 AND 19 THEN '18:00 - 20:00'
		WHEN HOUR(order_time) BETWEEN 20 AND 21 THEN '20:00 - 22:00'
		WHEN HOUR(order_time) BETWEEN 22 AND 23 THEN '22:00 - 00:00'
	END AS time_slot,
		COUNT(*) AS 'order_count'
FROM orders
GROUP BY time_slot
ORDER BY order_count DESC;
        
-- Approach 2

SELECT
	ROUND(HOUR(order_time)/2,0) * 2 AS 'start_slot',
	(ROUND(HOUR(order_time)/2,0) * 2) + 2 AS 'end_slot',
    COUNT(*) AS 'order_count'
FROM orders
GROUP BY start_slot,end_slot
ORDER BY order_count DESC;
        
-- 3. Find the average order value per customer who has placed more than 750 orders. 
-- -- Return customer_name, and aov(average order value)

SELECT customer_name, avg_order_value
FROM 
(
	SELECT t1.customer_name,COUNT(*) AS 'total_order_placed',ROUND(AVG(t2.total_amount),0) AS 'avg_order_value'
	FROM customers t1
	JOIN orders t2 
	ON t1.customer_id = t2.customer_id
	GROUP BY t1.customer_name
) t
WHERE total_order_placed > 750;

-- 4. List the customers who have spent more than 100K in total on food orders. 
-- -- Return customer_name, and customer_id

SELECT t1.customer_name, SUM(t2.total_amount) AS 'total_order_amount'
FROM customers t1
JOIN orders t2
ON t1.customer_id = t2.customer_id
GROUP BY t1.customer_name
HAVING total_order_amount > 100000;

-- 5. Write a query to find orders that were placed but not delivered. 
-- -- Return each restaurant_name, city and number of not delivered orders.

SELECT t2.restaurant_name,t2.city,COUNT(*) AS 'no_of_not_delivered_orders'
FROM orders t1
LEFT JOIN restaurants t2
ON t1.restaurant_id = t2.restaurant_id
LEFT JOIN deliveries t3
ON t1.order_id = t3.order_id
WHERE t3.delivery_id IS NULL
GROUP BY t2.restaurant_name,t2.city
ORDER BY no_of_not_delivered_orders DESC;

-- 6. Rank restaurants by their total revenue from the last year, including their name, total revenue, and rank within their city.

WITH CTE AS
(
	SELECT t1.restaurant_name,t1.city,SUM(total_amount) AS 'revenue'
	FROM restaurants t1
	JOIN orders t2
	ON t1.restaurant_id = t2.restaurant_id
	GROUP BY t1.restaurant_name,t1.city
	ORDER BY revenue DESC
)
SELECT *,
RANK() OVER(PARTITION BY city ORDER BY revenue DESC) AS 'rank'
FROM CTE;

-- 7. Identify the most popular dish in each city based on the number of orders.

WITH CTE AS
(
	SELECT t2.order_item,t1.city,COUNT(*) 'count_of_orders'
	FROM restaurants t1
	JOIN orders t2
	ON t1.restaurant_id = t2.restaurant_id
	GROUP BY t2.order_item,t1.city
), rank_cte AS
(
	SELECT *,
	RANK() OVER(PARTITION BY city ORDER BY count_of_orders DESC) AS 'rank'
	FROM CTE
)
SELECT city, order_item,count_of_orders 
FROM rank_cte
WHERE rank_cte.rank = 1;

-- 8. Find the customers who haven't placed an order in 2024 but did in 2023.

SELECT DISTINCT(customer_id)
FROM orders
WHERE 
	YEAR(order_date) = 2023
    AND
    customer_id NOT IN 
    (
		SELECT DISTINCT(customer_id)
        FROM orders
        WHERE YEAR(order_date) = 2024
    );

-- 9. Calculate and compare the order cancellation rate for each restaurant between the current year and the previous year.

WITH cancel_ratio_23 AS
(
	SELECT t1.restaurant_id,COUNT(t2.order_id) 'total_orders',
		COUNT(CASE WHEN t2.delivery_id IS NULL THEN 1 END) 'not_delivered'
	FROM orders t1
	LEFT JOIN deliveries t2
	ON t1.order_id = t2.order_id
	WHERE YEAR(t1.order_date) = 2023
	GROUP BY t1.restaurant_id
),
last_year_ratio AS
(
	SELECT *,ROUND(not_delivered/total_orders * 100,2) AS 'canc_rate'
	FROM cancel_ratio_23
), 
cancel_ratio_24 AS
(
	SELECT t1.restaurant_id,COUNT(t2.order_id) 'total_orders',
		COUNT(CASE WHEN t2.delivery_id IS NULL THEN 1 END) 'not_delivered'
	FROM orders t1
	LEFT JOIN deliveries t2
	ON t1.order_id = t2.order_id
	WHERE YEAR(t1.order_date) = 2024
	GROUP BY t1.restaurant_id
),
current_year_ratio AS
(
	SELECT *,ROUND(not_delivered/total_orders * 100,2) AS 'canc_rate'
	FROM cancel_ratio_24
)

SELECT
	t1.restaurant_id AS 'rest_id',
    t1.canc_rate AS 'cs_ratio',
    t2.canc_rate AS 'ls_ratio' 
FROM current_year_ratio AS t1
JOIN last_year_ratio AS t2
ON t1.restaurant_id = t2.restaurant_id;
    
-- 10. Determine each rider's average delivery time.

SELECT
    t2.delivery_time,
    t1.order_time,
    TIME_TO_SEC(
        TIMEDIFF(
            CASE
                WHEN t2.delivery_time < t1.order_time
                THEN ADDTIME(t2.delivery_time, '24:00:00')
                ELSE t2.delivery_time
            END,
            t1.order_time
        )
    ) / 60 AS rider_time_taken_minutes
FROM orders t1
JOIN deliveries t2
    ON t1.order_id = t2.order_id;

WITH CTE AS
(
	SELECT
		t3.rider_id,
		t3.rider_name,
		t2.delivery_time,
		t1.order_time,
		TIME_TO_SEC(
            TIMEDIFF(
					CASE 
						WHEN t2.delivery_time < t1.order_time
						THEN ADDTIME(t2.delivery_time, '24:00:00')
						ELSE t2.delivery_time
					END,
					t1.order_time
			)
        ) AS 'riders_taken_time'
	FROM orders t1
	JOIN deliveries t2
	ON t1.order_id = t2.order_id
	JOIN riders t3
	ON t2.rider_id = t3.rider_id
	WHERE t2.delivery_status = 'Delivered'
)
SELECT rider_id,rider_name,ROUND(AVG(riders_taken_time)/60,2) AS 'riders_avg_time_taken' 
FROM CTE
GROUP BY rider_id,rider_name;

-- 11. Calculate each restaurant's growth ratio based on the total number of delivered orders since its joining

-- Approach 1.

WITH CTE AS
(
	SELECT 
		t1.restaurant_id,
		t1.restaurant_name,
		DATE_FORMAT(order_date,  '%Y-%m') AS month_year,
		COUNT(t2.order_id) AS 'no_of_orders'
	FROM restaurants t1
	JOIN orders t2
	ON t1.restaurant_id = t2.restaurant_id
	JOIN deliveries t3
	ON t2.order_id = t3.order_id
	WHERE t3.delivery_status = 'Delivered'
	GROUP BY t1.restaurant_id,t1.restaurant_name,DATE_FORMAT(order_date, '%Y-%m')
    ORDER BY DATE_FORMAT(order_date, '%Y-%m') 
), 
new_table AS
(
	SELECT *,
		MIN(month_year) OVER(PARTITION BY restaurant_name ORDER BY month_year) AS 'join_mnt',
		LAG(no_of_orders) OVER(PARTITION BY restaurant_name ORDER BY month_year) AS 'pre_mnt_orders'
	FROM CTE
)
SELECT *,
	ROUND((no_of_orders - pre_mnt_orders)/pre_mnt_orders * 100,2) AS 'gwth_ratio_mnt_wise'
FROM new_table;

-- Approach 2.

WITH CTE AS
(
	SELECT 
		t1.restaurant_id,
		t1.restaurant_name,
		DATE_FORMAT(order_date,  '%Y-%m') AS month_year,
		COUNT(t2.order_id) AS 'curr_month_orders',
		LAG(COUNT(t2.order_id)) OVER(PARTITION BY restaurant_name ORDER BY (DATE_FORMAT(order_date,  '%Y-%m'))) AS 'previous_month_orders'
	FROM restaurants t1
	JOIN orders t2
	ON t1.restaurant_id = t2.restaurant_id
	JOIN deliveries t3
	ON t2.order_id = t3.order_id
	WHERE t3.delivery_status = 'Delivered'
	GROUP BY t1.restaurant_id,t1.restaurant_name,DATE_FORMAT(order_date, '%Y-%m')
	ORDER BY t1.restaurant_id,DATE_FORMAT(order_date, '%Y-%m')
)
SELECT *,
	ROUND(((curr_month_orders - previous_month_orders)/previous_month_orders)*100,2) AS '%_growth_ratio'
FROM CTE;

-- 12. 	Customer segmentation: Segment customers into 'Gold' or 'Silver' groups based on their total spending
-- 		compared with the average total value(aov). If the customers total spending excceds the aov, 
-- 		label them as 'Gold'; otherwise, label them as 'Silver'. Write a query to determine each segment's total number of 
-- 		orders and total revenue.

SELECT 
	customer_type,
    SUM(total_orders) AS 'orders',
    SUM(total_spent) AS 'expense'
FROM
(
	SELECT 
		customer_id,
		COUNT(order_id) AS 'total_orders',
		SUM(total_amount) AS 'total_spent',
		CASE 
			WHEN SUM(total_amount) > (SELECT AVG(total_amount) FROM orders) 
			THEN 'Gold'
			ELSE 'Silver'
		END AS 'customer_type'
	FROM orders
	GROUP BY customer_id
) t
GROUP BY customer_type;

-- 13. Calculate each rider's total monthly earnings, assuming they earn 8% of the order amount.

WITH CTE AS
(
	SELECT 
		t2.rider_id,
		t2.rider_name,
        DATE_FORMAT(t3.order_date, '%m-%y') AS 'month_name',
		t3.total_amount
	FROM deliveries t1
	JOIN riders t2
	ON t1.rider_id = t2.rider_id
	JOIN orders t3
	ON t1.order_id = t3.order_id
), 
rider_earnings AS
(
	SELECT 
		*,
		ROUND(total_amount * 0.08,2) AS 'rider_earnings'
	FROM CTE
)
SELECT 
	rider_id,
	rider_name,
    month_name,
    ROUND(SUM(rider_earnings),2) AS 'ind_rider_earnings'
FROM rider_earnings
GROUP BY rider_id,rider_name,month_name
ORDER BY rider_id;

-- 14.	Rider rating analysis:
-- 		Find the number of 5-star,4-star,3-star ratings each rider has.
-- 		rider receives this rating based on delivery time.
-- 		If orders are delivered less than 15 minutes of order received time the rider gets 5-star rating.
-- 		If they delivered between 15 and 20 minutes they get 4-star rating.
-- 		If they delivered after 20 minutes they get 3-star rating.

WITH CTE AS 
(
	SELECT 
		t2.rider_id,
		t1.order_time,
		t2.delivery_time,
		ROUND(TIME_TO_SEC(
			TIMEDIFF(
					CASE 
						WHEN t2.delivery_time < t1.order_time
						THEN ADDTIME(t2.delivery_time, '24:00:00')
						ELSE t2.delivery_time
					END,
					t1.order_time
			)
		)/60,2) AS 'riders_taken_time'
	FROM orders t1
	JOIN deliveries t2
	ON t1.order_id = t2.order_id
    WHERE t2.delivery_status = 'Delivered'
)
SELECT 
	ratings,
    COUNT(rider_id) AS 'riders_count'
FROM 
(
	SELECT 
		*,
		CASE
			WHEN riders_taken_time < 15 THEN '5-star' 
			WHEN riders_taken_time BETWEEN 15 AND 20 THEN '4-star'
			ELSE '3-star'
		END AS 'ratings'
	FROM CTE
) t
GROUP BY ratings;

-- 15.	Analyze the order frequency per day of the week and identify the peak day for each restaurant.	

WITH CTE AS
(
	SELECT 
		t.restaurant_id,
		t.day,
        t.week_days,
		COUNT(t.order_id) AS 'rest_cnt_of_orders'
	FROM 
	(
		SELECT 
			*,
			DAYNAME(order_date) AS 'day',
			DAYOFWEEK(order_date) AS 'week_days'
		FROM orders
	) t
	GROUP BY t.day,t.week_days,t.restaurant_id
	ORDER BY t.restaurant_id,t.week_days
), 
highest_orders AS
(
	SELECT 
		*,
		RANK() OVER(PARTITION BY restaurant_id ORDER BY rest_cnt_of_orders DESC) AS 'max_of_orders'
	FROM CTE
)
SELECT 
	restaurant_id, 
    day,
    rest_cnt_of_orders AS 'highest_orders'
FROM highest_orders
WHERE max_of_orders = 1;

-- 16. Calculated the total revenue generated by the each customer over all their orders.

SELECT 
	t1.customer_id,
    t2.customer_name,
    COUNT(t1.order_id) AS 'cnt_of_orders',
	SUM(t1.total_amount) AS 'total_revenue'
FROM orders t1
JOIN customers t2
ON t1.customer_id = t2.customer_id
GROUP BY t1.customer_id,t2.customer_name;

-- 17. Identify sales trends by comapring each month's total sales to the previous months.

WITH CTE AS
( 
	SELECT 
		MONTH(order_date) AS 'month',
		YEAR(order_date) AS 'year',
		COUNT(order_id) AS 'total_orders',
		SUM(total_amount) AS 'total_sales'
	FROM orders
	GROUP BY 
		YEAR(order_date),
		MONTH(order_date)
	ORDER BY 
		YEAR(order_date),
		MONTH(order_date)
)
SELECT 
	*,
    LAG(total_sales) OVER(ORDER BY year, month) AS 'prev_month_sales'
FROM CTE;

-- 18. Evaluate rider's efficiency by determining the average delivery times and identifying those with the lowest and highest averages.

WITH CTE AS
(
	SELECT 
		t2.rider_id,
		ROUND(TIME_TO_SEC(
			TIMEDIFF(
			CASE
				WHEN t2.delivery_time < t1.order_time
				THEN ADDTIME(t2.delivery_time,'24:00:00')
				ELSE t2.delivery_time
			END,
			t1.order_time
			)
		)/60,2) AS 'riders_taken_time'
	FROM orders t1
	JOIN deliveries t2
	ON t1.order_id = t2.order_id
	WHERE t2.delivery_status = 'Delivered'
),
ranked_rider AS
(
	SELECT 
		rider_id,
		ROUND(AVG(riders_taken_time),2) AS 'avg_taken_time'
	FROM CTE
	GROUP BY rider_id
	ORDER BY rider_id
)
SELECT 
    rider_id,
    avg_taken_time,
    RANK() OVER (ORDER BY avg_taken_time ASC)  AS fastest_rank,
    RANK() OVER (ORDER BY avg_taken_time DESC) AS slowest_rank
FROM ranked_rider;

-- 19. Track the popularity of specific order items over time and identify seasonal demand spikes.

WITH CTE AS
(
	SELECT 
		*,
		MONTH(order_date) AS 'month',
		CASE 
			WHEN MONTH(order_date) BETWEEN 2 AND 5 THEN 'Summer'
			WHEN MONTH(order_date) BETWEEN 6 AND 9 THEN 'Rainy'
			ELSE 'Winter'
		END AS 'season'
	FROM orders
), 
new_table AS
(
	SELECT 
		order_item,
		season,
		COUNT(order_id) AS 'cnt_of_orders'
	FROM CTE
	GROUP BY order_item,season
)
SELECT 
	season,
    GROUP_CONCAT(order_item) AS 'fvrt_dish_season_wise'
FROM
(
	SELECT 
		*,
		RANK() OVER(PARTITION BY season ORDER BY cnt_of_orders DESC) AS 'rank'
	FROM new_table
) t
WHERE t.rank = 1
GROUP BY season;

-- 20. Rank each city based on the total revenue for last year 2023.

SELECT 
	*,
    RANK() OVER(ORDER BY total_revenue DESC) AS 'rank'
FROM
(
	SELECT 
		t1.city,
		SUM(t2.total_amount) AS 'total_revenue'
	FROM restaurants t1
	JOIN orders t2
	ON t1.restaurant_id = t2.restaurant_id
	WHERE YEAR(order_date) = '2023'
	GROUP BY t1.city
) t
