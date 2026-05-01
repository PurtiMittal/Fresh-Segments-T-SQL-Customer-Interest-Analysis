

-- Index Analysis

-- 1 What is the top 10 interests by the average composition for each month?

/*
Average composition is calculated by dividing composition by index_value roudned to 2 decimal places, as defined in the problem statement.
DENSE_RANK() partitioned by m9nth_year ranks interests within each month by their average composition.
*/


   WITH cte AS(
        SELECT month_year, interest_id, CAST(composition/index_value AS DECIMAL (5,2)) AS avg_composition, DENSE_RANK() OVER(PARTITION BY month_year ORDER BY (composition/index_value) DESC) AS rnk
        FROM interest_metrics)

    SELECT month_year, c.interest_id, i.interest_name, avg_composition, rnk
    FROM cte c
    INNER JOIN interest_map i on c.interest_id = i.id
    WHERE rnk <=10;

/*
Result:
Work Comes First Travelers dominates Sep 2018 to Feb 2019, peaking at 9.14 in October.
Las Vegas Trip Planners and Gym Equipment Owners lead in mid-2018 amd reappear in 2019.
Notably: Average composition drops sharply from May 201 onwards across the entire top 10.
*/


-- 2 For all of these top 10 interests - which interest appears the most often?

/* Reuses the same avg_composition logic from Q1 inside a CTE.
DENSE_RANK() partitioned by month_year ranks interests within each month.
We then filter to top 10 per month and count how many months each interest appears in (frequency of top 10 presence, nit just a single month ranking)
TOP 1 WITH TIES surfaces all interests tied for the highest appearance count.
*/

    WITH cte AS(
      SELECT month_year, interest_id, CAST(composition/index_value AS DECIMAL (5,2)) AS avg_composition, DENSE_RANK() OVER(PARTITION BY month_year ORDER BY composition/index_value DESC) AS rnk
      FROM interest_metrics)

    SELECT TOP 1 WITH TIES c.interest_id, interest_name, COUNT(*) AS frequency
    FROM cte c 
    INNER JOIN interest_map i ON i.id = c.interest_id
    WHERE rnk<=10
    GROUP BY c.interest_id, interest_name
    ORDER BY 3 DESC;

/*
Result: Alabama Trip Planners, Luxury Bedding Shoppers & Solar Energy Researchers, each appear in 10 out of 14 months top 10 lists
Consistent top 10 presence across multiple months makes them the most reliable high performing interest in the entire dataset.
*/

-- 3 What is the average of the average composition for the top 10 interests for each month?

/*
Same CTE pattern as Q1 and Q2. Avg_composition calculated as composition/index_value

We filter to top 10 per month first, then AVG across those 10 values (this given the avg composition of the top performig interests each month)
*/

    WITH cte AS (
        SELECT month_year, interest_id, composition/index_value as avg_composition, DENSE_rANK() OVER(PARTITION BY month_year ORDER BY composition/index_value DESC) AS rnk
        FROM interest_metrics)

    SELECT month_year, CAST(AVG(avg_composition) AS DECIMAL(5,2)) AS monthly_top_10_avg_composition
    FROM cte 
    WHERE rnk <=10
    GROUP BY month_year;

/*
Results:
Average top 10 composition peaks in Oct 2018 at 7.07 and holds relatively stable till March 2019. Then drops sharply in May to 3.54 and even lower to 2.63 at end of the period i.e, Aug 2019.
This is not individual interest declining, the entire top tier is losing engagement from May 2019 onwards.
*/


--4 What is the 3 month rolling average of the max average composition value from September 2018 to August 2019 and include the previous top ranking interests in the same output shown below.
/*
CTE calcualtes avg_composition per row and stamps the monthly maximum.
MAX() as a window function partitioned by month_year keeps all rows intact so we can filter to only the row where avg_composition = max in the outer query.

Outer query:
ROWS BETWEEN 2 PRECEEDING AND CURRENT ROW gives a true 3-month rolling average of the monthly max avg_composition values ordered chronologically.
LAG(interest_name,1) and LAG(interest_name,2) pull the top interest name from 1 and 2 months prior respectively.
CONCAT combines the lagged name and value into the required format
Final WHERE restricts output to Sep 2018 to Aug 2019 as required.
*/


  WITH CTE AS (
      SELECT
          month_year,
          interest_name,
          composition/index_value AS avg_composition,
          MAX(composition/index_value) OVER(PARTITION BY month_year) AS max_avg_composition
      FROM interest_metrics m
      INNER JOIN interest_map i ON m.interest_id = i.id)

  SELECT * FROM (
        SELECT
            month_year,
            interest_name,
            ROUND(max_avg_composition,2) AS max_avg_composition,
            ROUND(AVG(avg_composition) OVER(ORDER BY month_year ROWS BETWEEN 2 PRECEDING AND CURRENT ROW),2) AS rolling_three_month_max_avg,
            CONCAT(LAG(interest_name,1) OVER(ORDER BY month_year),': ', LAG(ROUND(max_avg_composition,2),1) OVER(ORDER BY month_year)) AS one_month_ago,
            CONCAT(LAG(interest_name,2) OVER(ORDER BY month_year),': ', LAG(ROUND(max_avg_composition,2),2) OVER(ORDER BY month_year)) AS two_month_ago
        FROM cte
        WHERE avg_composition = max_avg_composition
        ) A
  WHERE month_year BETWEEN '2018-09-01' AND '2019-08-01'


/*
Result:
Result matches expected output exactly.
Work Comes First Travelers dominates teh top spot from Sep 2018 to Feb 2019, six consecutive months at the highest avg composition.
From March 2019 the top interest rotates every month and avg composition falls sharply from 8.26 in Sep 2018 to 2.79 in Aug 2019.
The 3-month rolling average tells the same story, peaks at 8.58 in Dec 2018 and steadily declines to 2.77 by Aug 2019. This is a directional drop and not any seasonal drop.
*/



-- 5. Provide a possible reason why the max average composition might change from month to month? Could it signal something is not quite right with the overall business model for Fresh Segments?

/*
Month to month changes in max average composition are expected to some degree, different interests naturally peak at different times of the year.
Work Comes First Travelers peaking in autmn/winter season totally makes sense.

What is not normal is the magnitude of the decline from early 2019 onwards.
Max avg composition drops from 9.14 in Oct 2018 to 2.73 by Aug 2019, a fall of over 70%. This is not seasonality, this is structural.

Possible Reasons:
The client's customer base is shrinking or becoming less engaged over time.
The interest categories themselves may be losing relevance for this client's audience.


For Fresh Segments' business model this is a concern worth raising.
- Their value proposition is built on delivering actionable interest-level insights.
- If composition values are consistently declining, the segments become less meaningful and harder to act on, which ultimately undermines client confidence in the platform.