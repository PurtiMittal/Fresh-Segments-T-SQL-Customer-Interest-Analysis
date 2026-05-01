# Fresh-Segments-T-SQL-Customer-Interest-Analysis 

## Interest Analysis

### 1. Which interests have been present in all month_year dates in our dataset?

 - To find this, we count distinct month_year apperances per interest and compare against the total number of distinct months in the dataset usIng a subquery.
 - Any interest matching the full month count has been consistently tracked throughtout the entire dataset period, there are our most reliable segments for trend analysis.

```sql
     SELECT i.interest_id, m.interest_name, COUNT(DISTINCT month_year) AS total_months
     FROM interest_metrics i
     INNER JOIN interest_map m ON i.interest_id= m.id
     GROUP BY interest_id, m.interest_name
     HAVING COUNT(DISTINCT month_year) = (SELECT COUNT(DISTINCT month_year) FROM interest_metrics);
```

*Result - There are 480 interest_id that are present in all month_year dates in our dataset.*


 ### 2. Using this same total_months measure - calculate the cumulative percentage of all records starting at 14 months - which total_months value passes the 90% cumulative percentage value?

- Built in two CTE layers:
- First `CTE` counts how many months each interest appears across the datset.
- Second `CTE` groups those counts to find how  many interests share each total_months_value.
- The final `SELECT` adds a running cumulative sum and percentage using `SUM()` `OVER()`, ordered descending so we start from the most consistent interests (14 months) downward.

```sql
    WITH month_counts AS
     (SELECT
        interest_id,
        COUNT(DISTINCT month_year) AS total_months 
     FROM interest_metrics
     GROUP BY interest_id)

   ,interest_counts as
     (SELECT
        total_months,
        COUNT(interest_id) AS total_ids
     FROM month_counts
     GROUP BY total_months)


   SELECT
     total_months,
     total_ids,
     SUM(total_ids) OVER(ORDER BY total_months desc) AS cumulative_sum,
     CAST(SUM(total_ids) OVER(ORDER BY total_months DESC)*100.0/SUM(total_ids) OVER() AS DECIMAL (5,2)) AS cumulative_perc
  FROM interest_counts;
```
*Output -* 

| total_months | total_ids | cumulative_sum | cumulative_perc |
|--------------|-----------|----------------|-----------------|
| 14           | 480       | 480            | 39.93           |
| 13           | 82        | 562            | 46.76           |
| 12           | 65        | 627            | 52.16           |
| 11           | 94        | 721            | 59.98           |
| 10           | 86        | 807            | 67.14           |
| 9            | 95        | 902            | 75.04           |
| 8            | 67        | 969            | 80.62           |
| 7            | 90        | 1059           | 88.10           |
| 6            | 33        | 1092           | 90.85           |
| 5            | 38        | 1130           | 94.01           |
| 4            | 32        | 1162           | 96.67           |
| 3            | 15        | 1177           | 97.92           |
| 2            | 12        | 1189           | 98.92           |
| 1            | 13        | 1202           | 100.00          |

*Result - Cumulative percentage crosses 90% at total_months = 6. Interests present for 6 or more months account for over 90% of all records.*

### 3. If we were to remove all interest_id values which are lower than the total_months value we found in the previous question - how many total data points would we be removing?

- Used `DECLARE` to store the total record count upfront rather than nesting a subquery inside the `CAST` keeps the final `SELECT` cleaner and easier to read.
- The `CTE` identifies all interest_ids appearing in fewer than *6* distinct months and we join back to interest_metrics to count the actual rows they represent.

```sql
   DECLARE @cnt int
   SET @cnt = (SELECT COUNT(*) FROM interest_metrics);

   WITH interest_longevity AS
    (SELECT interest_id, count(DISTINCT month_year) aAS total_months 
    FROM interest_metrics
    GROUP BY interest_id
    HAVING COUNT(DISTINCT month_year) < 6)

   SELECT 
      COUNT(*) AS records_to_remove,
      CAST(COUNT(*)*100.0/@cnt as DECIMAL (5,2)) AS percent_records_to_remove
   FROM interest_metrics m
   INNER JOIN interest_longevity l ON m.interest_id = l.interest_id;
```

*Output -*

| records_to_remove | percent_records_to_remove |
|-------------------|---------------------------|
| 400               | 3.06                      |



 *Result - 400 records would be removed, representing just 3.06% of the total dataset.*



 ### 4. Does this decision make sense to remove these data points from a business perspective? Use an example where there are all 14 months present to a removed interest example for your arguments - think about what it means to have less months present from a segment perspective.

- Absolutely. Consider two interests from the dataset:
- "Order-in Eaters" appears across all 14 months. "Big Box Shoppers" appears in just 1.
- Order-in Eaters is exactly the kind of segment a client should be acting on as it represents consistent presence over 14 months that means the audience is real, trackable and reliable.
- Big box Shoppers on the other hand gives you nothing to work with. One month of data could be anything - a season blip or some trending thing.
- No client should be allocating budget based on that and Fresh Segments should not be presenting it as a menaingful segment.
- We are only removing 400 records which is 3.06% of the dataset. This is a very small price for a meaningfully cleaner analysis.


### 5. After removing these interests - how many unique interests are there for each month?

- The `CTE` filters to interests present in 6 or more months (our quality threshold)
- We then join back to interest_metrics and count distinct interests per month_year to see what the cleaned dataset looks like month by month.
- This gives us confidence that enough segment diversity remains in each month for the analysis to still be meaningful after the removal.
```SQL
   WITH high_quality_interests AS
   (SELECT interest_id, COUNT(DISTINCT month_year) AS total_months 
   FROM interest_metrics
   GROUP BY interest_id
   HAVING COUNT(DISTINCT month_year) >= 6)

   SELECT month_year, COUNT(DISTINCT m.interest_id) AS unique_ids
   FROM interest_metrics m
   INNER JOIN high_quality_interests l ON m.interest_id = l.interest_id
   GROUP BY month_year
   ORDER BY month_year;
```
*Output -*

| month_year | unique_ids |
|------------|------------|
| 2018-07-01 | 709        |
| 2018-08-01 | 752        |
| 2018-09-01 | 774        |
| 2018-10-01 | 853        |
| 2018-11-01 | 925        |
| 2018-12-01 | 986        |
| 2019-01-01 | 966        |
| 2019-02-01 | 1072       |
| 2019-03-01 | 1078       |
| 2019-04-01 | 1035       |
| 2019-05-01 | 827        |
| 2019-06-01 | 804        |
| 2019-07-01 | 836        |
| 2019-08-01 | 1062       |

*Result - The filtered dataset retains a healthy number of interests across all months, confirming the 6-month threshold provides the right balance between data quality and analytical coverage.*
