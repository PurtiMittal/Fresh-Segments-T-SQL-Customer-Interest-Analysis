--Segment Analysis
--Using our filtered dataset by removing the interests with less than 6 months worth of data, which are the top 10 and bottom 10 interests which have the 
--largest composition values in any month_year? Only use the maximum composition value for each interest but you must keep the corresponding month_year



-- 2 Which 5 interests had the lowest average ranking value?

  with high_quality_interests as
 (select interest_id, count(distinct month_year) as total_months 
 from interest_metrics
 group by interest_id
 having count(distinct month_year) >= 6)


select top 5 with ties m.interest_id, i.interest_name, avg(cast (ranking as float)) as avg_ranking
from interest_metrics m
inner join high_quality_interests h on h.interest_id = m.interest_id
inner join interest_map i on i.id = m.interest_id
group by m.interest_id, i.interest_name
order by 3 asc;


-- 3 Which 5 interests had the largest standard deviation in their percentile_ranking value?

select top 5 with ties m.interest_id, i.interest_name, stdev(percentile_ranking) as standard_dev
from interest_metrics m
inner join interest_map i on i.id = m.interest_id
group by m.interest_id, i.interest_name
order by 3 desc;

-- 4 For the 5 interests found in the previous question - what was minimum and maximum percentile_ranking values for each interest and 
-- its corresponding year_month value? Can you describe what is happening for these 5 interests?
with least_std_dev as 
(select top 5 with ties interest_id, stdev(percentile_ranking) as standard_dev
from interest_metrics 
group by interest_id
order by 2 desc)

, min_max as
(select m.interest_id, interest_name, month_year, percentile_ranking
, min(percentile_ranking) over(partition by m.interest_id) as min_percentile_rank
, max(percentile_ranking) over(partition by m.interest_id) as max_percentile_rank
from interest_metrics m
inner join interest_map i on i.id = m.interest_id
inner join least_std_dev s on s.interest_id = m.interest_id)

select interest_id, interest_name, min_percentile_rank, max_percentile_rank
, min(case when min_percentile_rank = percentile_ranking then month_year end) as min_month
, min(case when max_percentile_rank = percentile_ranking then month_year end) as max_month
from min_max
where percentile_ranking = min_percentile_rank or percentile_ranking = max_percentile_rank
group by interest_id, interest_name, min_percentile_rank, max_percentile_rank;




--- 5 How would you describe our customers in this segment based off their composition and ranking values? What sort of products or services should we show to these customers and what should we avoid?
