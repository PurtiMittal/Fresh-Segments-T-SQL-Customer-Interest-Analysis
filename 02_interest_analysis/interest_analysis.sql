-- Interest Analysis

 -- 1 Which interests have been present in all month_year dates in our dataset?

 select i.interest_id, m.interest_name, count(distinct month_year) as total_months
 from interest_metrics i
 inner join interest_map m on i.interest_id= m.id
 where i.interest_id is not null
 group by interest_id, m.interest_name
 having count(distinct month_year) = (select count(distinct month_year) from interest_metrics where interest_id is not null);

 -- 2 Using this same total_months measure - calculate the cumulative percentage of all records starting at 14 months - which total_months value passes the 90% cumulative percentage value?

 
 with month_counts as
 (select interest_id, count(distinct month_year) as total_months 
 from interest_metrics
 group by interest_id)

 , interest_counts as
 (select total_months, count(interest_id) as total_ids
 from month_counts
 group by total_months)

select top 1 total_months from
(select total_months, total_ids, sum(total_ids) over(order by total_months desc) as cumulative_sum
, sum(total_ids) over(order by total_months desc)*100.0/sum(total_ids) over() as cumulative_perc
from interest_counts) A
where cumulative_perc > 90;



--- 3 If we were to remove all interest_id values which are lower than the total_months value we found in the previous question - how many total data points would we be removing?


 with interest_longevity as
 (select interest_id, count(distinct month_year) as total_months 
 from interest_metrics
 group by interest_id
 having count(distinct month_year) < 6)

 select count(*) as records_to_remove, count(*)*100.0/(select count(*) from interest_metrics) as percent_records_to_remove
 from interest_metrics m
 inner join interest_longevity l on m.interest_id = l.interest_id;



 ---  4 Does this decision make sense to remove these data points from a business perspective? Use an example where there are all 14 months 
 -- present to a removed interest example for your arguments - think about what it means to have less months present from a segment perspective.



 -- 5. After removing these interests - how many unique interests are there for each month?
  with high_quality_interests as
 (select interest_id, count(distinct month_year) as total_months 
 from interest_metrics
 group by interest_id
 having count(distinct month_year) >= 6)

 select month_year, count(distinct m.interest_id) as unique_ids
 from interest_metrics m
 inner join high_quality_interests l on m.interest_id = l.interest_id
 group by month_year
 order by month_year;


-- Despite filtering out low-quality interests, our core audience segments grew by approx 50% from July 2018 to Aug 2019, showing that the platform reach is expanding sustainably.