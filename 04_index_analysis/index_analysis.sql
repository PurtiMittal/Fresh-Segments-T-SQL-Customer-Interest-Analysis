

-- Index Analysis

-- 1 What is the top 10 interests by the average composition for each month?

/*
Average composition is calculated by dividing composition by index_value roudned to 2 decimal places, as defined in the problem statement.
DENSE_RANK() partitioned by m9nth_year ranks interests within each month by their average composition.
*/


with cte as
(select month_year, interest_id, CAST(composition/index_value AS DECIMAL (5,2)) as avg_composition, dense_rank() over(partition by month_year order by (composition/index_value) desc) as rnk
from interest_metrics)

select month_year, c.interest_id, i.interest_name, avg_composition, rnk
from cte c
inner join interest_map i on c.interest_id = i.id
where rnk <=10;

/*
Result:
Work Comes First Travelers dominates Sep 2018 to Feb 2019, peaking at 9.14 in October.
Las Vegas Trip Planners and Gym Equipment Owners lead in mid-2018 amd reappear in 2019.
Notably: Average composition drops sharply from May 201 onwards across the entire top 10.
*/


-- 2 For all of these top 10 interests - which interest appears the most often?

/* Reuses the same avg_composition logic from Q1 inside a CTE.
DENSE_rANK() partitioned by month_year ranks interests within each month.
We then filter to top 10 per month and count how many months each interest appears in (frequency of top 10 presence, nit just a single month ranking)
TOP 1 WITH TIES surfaces all interests tied for the highest appearance count.
*/

with cte as
(select month_year, interest_id, CAST(composition/index_value AS DECIMAL (5,2)) as avg_composition, dense_rank() over(partition by month_year order by composition/index_value desc) as rnk
from interest_metrics)

select top 1 with ties c.interest_id, interest_name, count(*) as frequency
from cte c 
inner join interest_map i on i.id = c.interest_id
where rnk<=10
group by c.interest_id, interest_name
order by 3 desc;

/*
Result: Alabama Trip Planners, Luxury Bedding Shoppers & Solar Energy Researchers, each appear in 10 out of 14 months top 10 lists
Consistent top 10 presence across multiple months makes them the most reliable high performing interest in the entire dataset.
*/

-- 3 What is the average of the average composition for the top 10 interests for each month?

/*
Same CTE pattern as Q1 and Q2. Avg_composition calculated as composition/index_value

We filter to top 10 per month first, then AVG across those 10 values (this given the avg composition of the top performig interests each month)
*/

with cte as
(select month_year, interest_id, composition/index_value as avg_composition, dense_rank() over(partition by month_year order by composition/index_value desc) as rnk
from interest_metrics)

select month_year, cast(avg(avg_composition) as decimal(5,2)) as monthly_top_10_avg_composition
from cte 
where rnk <=10
group by month_year;

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


with cte as
(select month_year, interest_name
,composition/index_value as avg_composition
,max(composition/index_value) over(partition by month_year) as max_avg_composition
from interest_metrics m
inner join interest_map i on m.interest_id = i.id)

Select * from
(select month_year, interest_name, round(max_avg_composition,2) as max_avg_composition
, ROUND(avg(avg_composition) over(order by month_year rows between 2 preceding and current row),2) as rolling_three_month_max_avg
, concat(lag(interest_name,1) over(order by month_year),': ', lag(ROUND(max_avg_composition,2),1) over(order by month_year)) as one_month_ago
, concat(lag(interest_name,2) over(order by month_year),': ', lag(ROUND(max_avg_composition,2),2) over(order by month_year)) as two_month_ago
from cte
where avg_composition = max_avg_composition) A
where month_year between '2018-09-01' and '2019-08-01'

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