-- Snowflake SQL script for calculating daily positions and metrics
-- Author: Nelson Luna Silvestre
-- Description: Script to calculate the daily position in USD, identify the top 25% of companies with the largest average position (USD) in the last year, and calculate daily sector positions including weekends.

-- 1. Calculate the daily position in USD and materialize it for use in subsequent steps.
-- DROP VIEW IF EXISTS daily_position_usd;
CREATE OR REPLACE VIEW daily_position_usd AS
WITH price_with_filled_values AS (
    SELECT
        p.company_id,
        p.date,
        pr.close_usd,
        -- Fill missing price values with the last known price for each company, up to a limit of 7 days
        LAST_VALUE(pr.close_usd IGNORE NULLS) 
            OVER (PARTITION BY p.company_id ORDER BY p.date ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS filled_close_usd,
        -- Calculate the difference in days from the last known price date
        DATEDIFF(day, LAST_VALUE(pr.date IGNORE NULLS) OVER (PARTITION BY p.company_id ORDER BY p.date ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW), p.date) AS days_since_last_price
    FROM
        CODE_CHALLENGE_OL9LMSX5V0OB.SOURCE.POSITION p
    LEFT JOIN
        CODE_CHALLENGE_OL9LMSX5V0OB.SOURCE.PRICE pr
    ON
        p.company_id = pr.company_id AND p.date = pr.date
)
SELECT
    p.company_id,
    p.date,
    p.shares,
    CASE
        -- Limit propagation of last known price to a maximum of 7 days to balance accuracy with real market volatility.
        -- This helps avoid unrealistic price persistence during long periods without updates.
        WHEN pwf.days_since_last_price <= 7 THEN pwf.filled_close_usd
        ELSE NULL
    END AS close_usd,
    CASE
        WHEN pwf.days_since_last_price <= 7 THEN p.shares * pwf.filled_close_usd
        ELSE NULL
    END AS position_usd,
    -- price_propagation_flag: Indicates if the last known price has been propagated beyond the allowed limit of 7 days.
    -- This flag can help identify potential stale values, which should be treated with caution in further analysis.
    CASE
        WHEN pwf.days_since_last_price > 7 THEN 1 ELSE 0
    END AS price_propagation_flag
FROM
    CODE_CHALLENGE_OL9LMSX5V0OB.SOURCE.POSITION p
JOIN
    price_with_filled_values pwf
ON
    p.company_id = pwf.company_id AND p.date = pwf.date;

-- 2. Calculate the average position in USD for each company in the last year and find the top 25% companies.
-- DROP VIEW IF EXISTS top_25_percent;
CREATE OR REPLACE VIEW top_25_percent AS
WITH avg_position_last_year AS (
    -- Calculate the average position in USD for each company in the last year
    SELECT
        company_id,
        AVG(position_usd) AS avg_position_usd
    FROM
        daily_position_usd
    WHERE
        date >= DATEADD(year, -1, CURRENT_DATE)
    GROUP BY
        company_id
),
ranked_companies AS (
    -- Rank companies by their average position in USD to find the top 25%
    SELECT
        avg_position_last_year.company_id,
        comp.ticker,
        avg_position_usd,
        PERCENT_RANK() OVER (ORDER BY avg_position_usd DESC) AS percentile_rank
    FROM
        avg_position_last_year
    JOIN CODE_CHALLENGE_OL9LMSX5V0OB.SOURCE.COMPANY comp
    ON
        avg_position_last_year.company_id = comp.id
)
SELECT
    company_id,
    ticker,
    avg_position_usd
FROM
    ranked_companies
WHERE
    percentile_rank <= 0.25
ORDER BY
    avg_position_usd DESC;

-- 3. Calculate daily sector position in USD for every day, including weekends.
-- DROP VIEW IF EXISTS daily_sector_position;
CREATE OR REPLACE VIEW daily_sector_position AS
WITH date_range AS (
    -- Define the range of dates based on the POSITION table to ensure proper coverage
    SELECT
        MIN(date) AS start_date,
        MAX(date) AS end_date,
        DATEDIFF(day, MIN(date), MAX(date)) AS total_days
    FROM
        CODE_CHALLENGE_OL9LMSX5V0OB.SOURCE.POSITION
),
date_series AS (
    -- Generate a series of dates from the start date to the end date
    SELECT
        DATEADD(day, seq4(), start_date) AS date
    FROM
        date_range,
        TABLE(GENERATOR(ROWCOUNT => 20000))  -- Use a sufficiently high value to cover the entire date range
    WHERE
        seq4() <= (SELECT total_days FROM date_range)
),
distinct_sectors AS (
    -- Get all distinct sectors from the COMPANY table
    SELECT DISTINCT sector_name
    FROM CODE_CHALLENGE_OL9LMSX5V0OB.SOURCE.COMPANY
),
date_sector_series AS (
    -- Create all combinations of date and sector_name to ensure each date has all sectors represented
    SELECT
        ds.date,
        s.sector_name
    FROM
        date_series ds
    CROSS JOIN
        distinct_sectors s
),
daily_position_with_sector AS (
    -- Join daily position data with company sector information
    SELECT
        dp.date,
        c.sector_name,
        dp.position_usd
    FROM
        daily_position_usd dp
    JOIN
        CODE_CHALLENGE_OL9LMSX5V0OB.SOURCE.COMPANY c
    ON
        dp.company_id = c.id
),
daily_sector_aggregated AS (
    -- Aggregate the daily position by sector
    SELECT
        date,
        sector_name,
        SUM(position_usd) AS total_sector_position_usd
    FROM
        daily_position_with_sector
    GROUP BY
        date, sector_name
),
complete_daily_sector AS (
    -- Combine all date-sector combinations with the actual aggregated data
    SELECT
        dss.date,
        dss.sector_name,
        dsa.total_sector_position_usd
    FROM
        date_sector_series dss
    LEFT JOIN
        daily_sector_aggregated dsa
    ON
        dss.date = dsa.date AND dss.sector_name = dsa.sector_name
),
filled_sector_position AS (
    -- Fill missing values with the last known value for each sector
    -- This ensures that sector positions remain continuous, avoiding drops to zero on weekends or holidays.
    -- The propagation is subject to a 7-day limit to prevent unrealistically outdated values from influencing results.
    SELECT
        date,
        sector_name,
        LAST_VALUE(total_sector_position_usd IGNORE NULLS) 
            OVER (PARTITION BY sector_name ORDER BY date ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS filled_total_sector_position_usd
    FROM
        complete_daily_sector
)
SELECT
    date,
    sector_name,
    COALESCE(filled_total_sector_position_usd, 0) AS total_sector_position_usd
FROM
    filled_sector_position
ORDER BY
    date, sector_name;

-- Best Practice Note: Propagating prices and sector positions helps ensure data continuity but introduces potential risks of stale values.
-- The chosen 7-day limit for price propagation represents a balance between data continuity and realistic market responsiveness.
