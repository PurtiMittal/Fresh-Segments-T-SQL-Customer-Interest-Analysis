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

#### 2, What is count of records in the fresh_segments.interest_metrics for each month_year value sorted in chronological order (earliest to latest) with the null values appearing first?
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



#### 3. What do you think we should do with these null values in the fresh_segments.interest_metrics


*My recommendation would be to drop these records, Without interest_id and the date fields, there is no way to tell which interest the metrics belong to or when they were captured and thats the entire point of this dataset. Keeping them would only introduce noise into any time-based analysis downstream.
Hence, dropping is a solution. However, its good to know the quantam first, we should document what percent we are removing before we drop.*

```sql
    SELECT
        CAST((COUNT(*)-COUNT(month_year))*100.0/COUNT(*) AS DECIMAL (5,2)) AS null_percentage,
        COUNT(*) - COUNT(month_year) AS null_count
    FROM interest_metrics;
```
*Output -*

| null_percentage | null_count |
|-----------------|------------|
| 8.37            | 1194       |


*Interprtation - The result is 8.37% and 1194 rows. Since total null percentage is less than 10%, the data can be deleted. But its always advised to keep a backup of the data.*

```SQL
    SELECT *
    INTO interest_metrics_back
    FROM interest_metrics;
```

```SQL
    DELETE FROM interest_metrics
    WHERE month_year IS NULL;
```

#### 4. How many interest_id values exist in the fresh_segments.interest_metrics table but not in the fresh_segments.interest_map table? What about the other way around?
    ```SQL
    SELECT 
        COUNT(DISTINCT m.interest_id) AS not_in_interest_map_table, 
        COUNT(DISTINCT i.id) AS not_in_interest_metrics_table
    FROM interest_metrics m
    FULL OUTER JOIN interest_map i ON m.interest_id = i.id
    WHERE m.interest_id IS NULL or i.id IS NULL
    ```

*Output -*

| not_in_interest_map_table | not_in_interest_metrics_table |
|---------------------------|-------------------------------|
| 0                         | 7                             |


*Interpretation - No interest_id that is there that is in interest_metrics but not in interest_map table. 
The other way round, There are 7 such interest_metrics that are in interest_map table but not in interest_metrics table.*

#### 5. Summarise the id values in the fresh_segments.interest_map by its total record count in this table

```sql
    SELECT
        COUNT(id) AS total_ids,
        COUNT(distinct id) AS total_distinct_ids
    FROM interest_map;
```
*Output -*

| total_ids | total_distinct_ids |
|-----------|--------------------|
| 1209      | 1209               |


#### 6. What sort of table join should we perform for our analysis and why? Check your logic by checking the rows where interest_id = 21246 in your joined output and include all columns from fresh_segments.interest_metrics and all columns from fresh_segments.interest_map except from the id column.

I would go with an Inner Join between interest_metrics and interest_map on interest_id = id. The reason is straightforward. Any interest_id in the metrics table that has no corresponding entry in the map table is unidentifiable. We can't name it, describe it or present it meaningfully to a client. Including it in the analysis would be like reporting on a segment that doesn't exist on paper.

The interest_id = 21246 check confirms the logic holds, it appears in both tables, joins cleanly and returns a complete row with all metric and map columns intact. 
If the join were producing unexpected nulls or duplicate rows on this ID, that would be a signal to revisit the relationship assumption. It doesn't, so we are good.

```sql
    SELECT m.*, i.interest_name, i.interest_summary, i.created_at, i.last_modified
    FROM interest_map i
    INNER JOIN interest_metrics m ON i.id = m.interest_id
    WHERE m.interest_id = 21246;
```

*Output -*
| month | year | month_year | interest_id | composition | index_value | ranking | percentile_ranking | interest_name                    | interest_summary                                      | created_at                  | last_modified               |
|-------|------|------------|-------------|-------------|-------------|---------|--------------------|----------------------------------|-------------------------------------------------------|-----------------------------|-----------------------------|
| 7     | 2018 | 2018-07-01 | 21246       | 2.26        | 0.65        | 722     | 0.96               | Readers of El Salvadoran Content | People reading news from El Salvadoran media sources. | 2018-06-11 17:50:00.0000000 | 2018-06-11 17:50:00.0000000 |
| 8     | 2018 | 2018-08-01 | 21246       | 2.13        | 0.59        | 765     | 0.26               | Readers of El Salvadoran Content | People reading news from El Salvadoran media sources. | 2018-06-11 17:50:00.0000000 | 2018-06-11 17:50:00.0000000 |
| 9     | 2018 | 2018-09-01 | 21246       | 2.06        | 0.61        | 774     | 0.77               | Readers of El Salvadoran Content | People reading news from El Salvadoran media sources. | 2018-06-11 17:50:00.0000000 | 2018-06-11 17:50:00.0000000 |
| 10    | 2018 | 2018-10-01 | 21246       | 1.74        | 0.58        | 855     | 0.23               | Readers of El Salvadoran Content | People reading news from El Salvadoran media sources. | 2018-06-11 17:50:00.0000000 | 2018-06-11 17:50:00.0000000 |
| 11    | 2018 | 2018-11-01 | 21246       | 2.25        | 0.78        | 908     | 2.16               | Readers of El Salvadoran Content | People reading news from El Salvadoran media sources. | 2018-06-11 17:50:00.0000000 | 2018-06-11 17:50:00.0000000 |
| 12    | 2018 | 2018-12-01 | 21246       | 1.97        | 0.7         | 983     | 1.21               | Readers of El Salvadoran Content | People reading news from El Salvadoran media sources. | 2018-06-11 17:50:00.0000000 | 2018-06-11 17:50:00.0000000 |
| 1     | 2019 | 2019-01-01 | 21246       | 2.05        | 0.76        | 954     | 1.95               | Readers of El Salvadoran Content | People reading news from El Salvadoran media sources. | 2018-06-11 17:50:00.0000000 | 2018-06-11 17:50:00.0000000 |
| 2     | 2019 | 2019-02-01 | 21246       | 1.84        | 0.68        | 1109    | 1.07               | Readers of El Salvadoran Content | People reading news from El Salvadoran media sources. | 2018-06-11 17:50:00.0000000 | 2018-06-11 17:50:00.0000000 |
| 3     | 2019 | 2019-03-01 | 21246       | 1.75        | 0.67        | 1123    | 1.14               | Readers of El Salvadoran Content | People reading news from El Salvadoran media sources. | 2018-06-11 17:50:00.0000000 | 2018-06-11 17:50:00.0000000 |
| 4     | 2019 | 2019-04-01 | 21246       | 1.58        | 0.63        | 1092    | 0.64               | Readers of El Salvadoran Content | People reading news from El Salvadoran media sources. | 2018-06-11 17:50:00.0000000 | 2018-06-11 17:50:00.0000000 |

*Interpretation - Returns clean rows with no unexpected nulls in the key columns, confirming the join logic is sound and we can proceed with this approach.*

#### 7. Are there any records in your joined table where the month_year value is before the created_at value from the fresh_segments.interest_map table? Do you think these values are valid and why?
    ```sql
    WITH joined_table AS 
    (SELECT m.*, i.interest_name, i.interest_summary, i.created_at, i.last_modified
    FROM interest_map i
    INNER JOIN interest_metrics m ON i.id = m.interest_id)

    SELECT COUNT(*) AS true_errors
    FROM joined_table
    WHERE month_year < created_at;
     ```

*Output -*   
| true_errors |
|-------------|
| 188         |


*Interpretation - Yes, There are 188 records where month_year is earlier than created_at. This is probably because date for month_year for all the rows was set as '1', however they might have been created in the same month. To check the same -*

    WITH joined_table AS
    (SELECT m.*, i.interest_name, i.interest_summary, i.created_at, i.last_modified
    FROM interest_map i
    INNER JOIN interest_metrics m ON i.id = m.interest_id)

    SELECT COUNT(*) AS true_errors
    FROM joined_table
    WHERE month_year < DATETRUNC(month, created_at);

*Output -*
| true_errors |
|-------------|
| 0           |

*Interpretation - All the records fall within the same month. No true errors, all records are valid.*
