--Segment Analysis
--1 Using our filtered dataset by removing the interests with less than 6 months worth of data, which are the top 10 and bottom 10 interests which have the largest composition values in any month_year? Only use the maximum composition value for each interest but you must keep the corresponding month_year

/*
 First CTE filters to qualify interest (6 or more months)
 Second CTE finds each interest's maximum compoisition row and its corresponding month_year using RANK() partitioned by interest_id (RANK() chosen over ROW_number() to avoid silently dropping interests that share the same peak composition value)
 Third CTE ranks across all peak rows in both directions using DENSE_rANK() so tied values are all included
 Final SELECT: DISTINCT is added to handle cases where an interest ties on composition and month_year 
*/

 WITH high_quality_interests AS(
      SELECT interest_id, COUNT(DISTINCT month_year) AS total_months 
      FROM interest_metrics
      GROUP BY interest_id
      HAVING COUNT(DISTINCT month_year) >= 6)


 , max_composition AS (
      SELECT 
          m.interest_id,
          i.interest_name,
          m.month_year,
          m.composition,
          RANK() OVER(PARTITION BY m.interest_id ORDER BY m.composition DESC) AS rn
      FROM interest_metrics m
      INNER JOIN high_quality_interests h ON m.interest_id = h.interest_id
      INNER JOIN interest_map i ON m.interest_id = i.id)

  , qualified_interests AS (
      SELECT *,
         DENSE_RANK() OVER(ORDER BY composition ASC) AS rn_asc,
         DENSE_RANK() OVER(ORDER BY composition DESC) AS rn_desc
      FROM max_composition
      WHERE rn = 1)


      SELECT DISTINCT
        (CASE WHEN rn_asc <=10 THEN 'Bottom' ELSE 'Top' END) AS category,
        interest_id,
        interest_name,
        month_year,
        composition
      FROM qualified_interests
      WHERE rn_asc <=10 OR rn_desc <=10



-- 2 Which 5 interests had the lowest average ranking value?

/* 
 Lower ranking value = higher position (rank 1 is the top performer).
 So the 5 interests with the lowest average ranking are the segemnts that consistently index highest against the broader fresh segemnts cleint base.
 CAST to FLOAT before AVG to avoid integer division truncation and get precise results
 Top 5 with ties ensures no interest is unfairly excluded.
 */


    WITH high_quality_interests AS (
        SELECT interest_id, COUNT(DISTINCT month_year) AS total_months 
        FROM interest_metrics
        GROUP BY interest_id
        HAVING COUNT(DISTINCT month_year) >= 6)

    SELECT
        TOP 5 WITH TIES m.interest_id,
        i.interest_name,
        AVG(CAST(ranking AS FLOAT)) AS avg_ranking
    FROM interest_metrics m
    INNER JOIN high_quality_interests h ON h.interest_id = m.interest_id
    INNER JOIN interest_map i ON i.id = m.interest_id
    GROUP BY m.interest_id, i.interest_name
    ORDER BY 3 ASC;


/* Results - Winter Apparel Shoppers ranks 1st with a perfect average ranking of 1, meaning it had the highest index/_value every single month it appeared in. */


-- 3 Which 5 interests had the largest standard deviation in their percentile_ranking value?

/*
High standard deviation = volatile performance across months.
These are interests that dont hold a consistent position - they spike and drop.
STDEV() calcualtes standard deviation pf percentile_ranking of each interest_id
TOP 5 WITH TIES handles any boundary ties cleanly.
*/
     
    WITH high_quality_interests AS ( 
        SELECT interest_id, COUNT(DISTINCT month_year) AS total_months 
        FROM interest_metrics
        GROUP BY interest_id
        HAVING COUNT(DISTINCT month_year) >= 6)

    SELECT TOP 5 WITH TIES
        m.interest_id,
        i.interest_name,
        CAST(STDEV(percentile_ranking) AS DECIMAL (5,2)) AS standard_dev
    FROM interest_metrics m
    INNER JOIN high_quality_interests h ON m.interest_id = h.interest_id
    INNER JOIN interest_map i ON i.id = m.interest_id
    GROUP BY m.interest_id, i.interest_name
    ORDER BY 3 DESC;

/* Result: Techies leads with the highest standard deviation of 30.18, its percentile ranking swings the most dramatically across months out of all quality interests. 
           All the 5 interests here are volatile segemnts, menaing thereby their index_value position as compared to other interests shifts. */

-- 4 For the 5 interests found in the previous question - what was minimum and maximum percentile_ranking values for each interest and its corresponding year_month value? Can you describe what is happening for these 5 interests?

 /*
 FIRST_VALUE(month_year) ordered by percentile_ranking ASC/DESC retrives the exact month each boundary occurred in.
 MIN() and MAX() as window functions stamp both boundary values on every row.
 DISTINCT collapses the repeated rows down to one per interest.
 */


    WITH high_quality_interests AS (
        SELECT interest_id, COUNT(DISTINCT month_year) AS total_months 
        FROM interest_metrics
        GROUP BY interest_id
        HAVING COUNT(DISTINCT month_year) >= 6)

  , most_std_dev AS (
        SELECT TOP 5 WITH TIES
            m.interest_id,
            STDEV(percentile_ranking) AS standard_dev
        FROM interest_metrics  m
        INNER JOIN high_quality_interests h ON m.interest_id = h.interest_id
        GROUP BY m.interest_id
        ORDER BY 2 DESC)


    SELECT DISTINCT
      m.interest_id,
      interest_name,
      MIN(percentile_ranking) OVER(PARTITION BY m.interest_id) AS min_percentile_rank,
      MAX(percentile_ranking) OVER(PARTITION BY m.interest_id) AS max_percentile_rank,
      FIRST_VALUE(month_year)  OVER(PARTITION BY m.interest_id ORDER BY percentile_ranking ASC) AS min_percentile_rank_month,
      FIRST_VALUE(month_year)  OVER(PARTITION BY m.interest_id ORDER BY percentile_ranking DESC) AS max_percentile_rank_month
    FROM interest_metrics m
    INNER JOIN interest_map i ON i.id = m.interest_id
    INNER JOIN most_std_dev s ON s.interest_id = m.interest_id


  /*
    All 5 show a clear pattern. They peaked early (mostly July-Nov 2018) and hit their lowest point much later (mid to late 2019).
    This is a consistent fownward trend across all volatile segments, not random noise.
    These are not unpredicatble segments. they were once high performers that declined steadily over time.
    For Fresh Segments, this signals these interests may be losing relevance for this client's customer base, worth flagging before recommending them for future campaigns. 
*/




--- 5 How would you describe our customers in this segment based off their composition and ranking values? What sort of products or services should we show to these customers and what should we avoid?

/*
    This is not a hard sudience to read once we look at the full picture.
    They are affluent, career-driven, health conscious. They travel for work, invest in their homes, buy quality over cheap. Work Comes First Travelers peaks at 21.2% composition.
    Gym Equipment Owners at 18.82%. Luxury Hotel Guests, Luxury Retail Shoppers, Furniture Shoppers all in the top 10. Winter Apparel and Fitness Trackers hold the lowest average rankings in Q2, meaning they stay near the top month after month, not just occasionally.

    What to show them:
    Luxury travel, premium fitness gear, high-end retail and apparel, home furnishings, beauty and cosmetics. They are already for these things.

    What to avoid:
    The bottom 10 tells us where this audience simply is not present.
    Very few of the client's customers are looking for budget mobile phones, satellite TV, loans or generic fitness content.
    Campaigns built around price comparison, budget deals or mass market wellness will reach the wrong people or nobody at all.
*/