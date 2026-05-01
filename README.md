# Fresh-Segments-T-SQL-Customer-Interest-Analysis


### Data Exploration and Cleansing

#### 1. Update the fresh_segments.interest_metrics table by modifying the month_year column to be a date data type with the start of the month

```sql
    UPDATE interest_metrics
    SET month_year = NULL;

    ALTER TABLE interest_metrics ALTER COLUMN month_year DATE;

    UPDATE interest_metrics
    SET month_year = DATEFROMPARTS(year, month, 1);
```

#### 2 What is count of records in the fresh_segments.interest_metrics for each month_year value sorted in chronological order (earliest to latest) with the null values appearing first?
```sql
SELECT month_year, COUNT(*) AS no_of_records
FROM interest_metrics
GROUP BY month_year
ORDER BY month_year;
```

*Output -* 

| month_year | no_of_records  |
|------------|----------------|
| NULL       | 1194           |
| 2018-07-01 | 729            |
| 2018-08-01 | 767            |
| 2018-09-01 | 780            |
| 2018-10-01 | 857            |
| 2018-11-01 | 928            |
| 2018-12-01 | 995            |
| 2019-01-01 | 973            |
| 2019-02-01 | 1121           |
| 2019-03-01 | 1136           |
| 2019-04-01 | 1099           |
| 2019-05-01 | 857            |
| 2019-06-01 | 824            |
| 2019-07-01 | 864            |
| 2019-08-01 | 1149           |



*Interpretation - Count of rows having null as month_year is 1194.*



-- 3 What do you think we should do with these null values in the fresh_segments.interest_metrics

/* 
My recommendation would be to drop these records, Without interest_id and the date fields, there is no way to tell which interest the metrics belong to or when they captured and thats the entire point of this dataset. Keeping them would only introduce noise into any time-based analysis downstream.
Hence, dropping is a solution. However, its good to know the quantam first, we should document what percent we are removing before we drop.
*/

select cast((count(*)-count(month_year))*100.0/count(*) as decimal (5,2)) as null_percentage, count(*) - count(month_year) as null_count
from interest_metrics;

/* The result is 8.37% and 1194 rows
Since total null percentae is less than 10%, the data can be deleted. But its always advised to keep a backup of the data */

-- select * into interest_metrics_back from interest_metrics;

Delete from interest_metrics
where month_year is null ;


-- 4 How many interest_id values exist in the fresh_segments.interest_metrics table but not in the fresh_segments.interest_map table? What about the other way around?
select count(distinct m.interest_id) as not_in_interest_map_table, count(distinct i.id) as not_in_interest_metrics_table
from interest_metrics m
full outer join interest_map i on m.interest_id = i.id
where m.interest_id is null or i.id is null
-- Interpretation - There are no interest_id that is there in interest_metrics but not in interest_map table. 
-- The other way round, There are 7 interest_metrics that are in interest_map table and not in interest_metrics table.

-- 5 Summarise the id values in the fresh_segments.interest_map by its total record count in this table

select count(id) as total_ids, count(distinct id) as total_distinct_ids
from interest_map;


-- 6. What sort of table join should we perform for our analysis and why? Check your logic by checking the rows where interest_id = 21246 in your 
--joined output and include all columns from fresh_segments.interest_metrics and all columns from fresh_segments.interest_map except from the id column.

-- I would go with an Inner Join between interest_metrics and interest_map on interest_id = id
-- The reason is straightforward. Any interest_id in the metrics table that has no corresponding entry in the map table is unidentifiable. 
-- We can't name it, describe it or present it meaningfully to a client. Including it in the analysis would be like reporting on a segment that doesn't exist on paper.
-- The interest_id = 21246 check confirms the logic holds - it appears in both tables, joins cleanly and returns a complete row with all metric and map columns intact. 
-- If the join were producing unexpected nulls or duplicate rows on this ID, that would be a signal to revisit the relationship assumption. It doesn't, so we are good.

select m.*, i.interest_name, i.interest_summary, i.created_at, i.last_modified
from interest_map i
inner join interest_metrics m on i.id = m.interest_id
where m.interest_id = 21246;

-- Result returns clean rows with no unexpected nulls in the key columns, confirming the join logic is sound and we can proceed with this proceed.


-- 7. Are there any records in your joined table where the month_year value is before the created_at value from the fresh_segments.interest_map table? Do you think these values are valid and why?
with joined_table as 
(Select m.*, i.interest_name, i.interest_summary, i.created_at, i.last_modified
from interest_map i
inner join interest_metrics m on i.id = m.interest_id)

select count(*) as true_errors
from joined_table
where month_year < created_at;
 

-- Yes, There are 188 records where month_year is earlier than created_at. This is probably because date for month_year for all the rows was set as '1', however they might have been created in the same month. To check the same

with joined_table as
(Select m.*, i.interest_name, i.interest_summary, i.created_at, i.last_modified
from interest_map i
inner join interest_metrics m on i.id = m.interest_id)

select count(*)  as true_errors
from joined_table
where month_year < datetrunc(month, created_at);

-- All the records fall within the same month. No true errors, all records are valid.
