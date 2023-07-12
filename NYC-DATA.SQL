--Create Table NYC_Accidents_2020

CREATE TABLE NYC_Accidents_2020 (
    [CRASH DATE] DATE,
    [CRASH TIME] TIME,
    BOROUGH NVARCHAR(13),
    [ZIP CODE] NVARCHAR(7),
    LATITUDE FLOAT,
    LONGITUDE FLOAT,
    LOCATION NVARCHAR(28),
    [ON STREET NAME] NVARCHAR(32),
    [CROSS STREET NAME] NVARCHAR(32),
    [OFF STREET NAME] NVARCHAR(37),
    [NUMBER OF PERSONS INJURED] INT,
    [NUMBER OF PERSONS KILLED] INT,
    [NUMBER OF PEDESTRIANS INJURED] INT,
    [NUMBER OF PEDESTRIANS KILLED] INT,
    [NUMBER OF CYCLIST INJURED] INT,
    [NUMBER OF CYCLIST KILLED] INT,
    [NUMBER OF MOTORIST INJURED] INT,
    [NUMBER OF MOTORIST KILLED] INT,
    [CONTRIBUTING FACTOR VEHICLE 1] NVARCHAR(53),
    [CONTRIBUTING FACTOR VEHICLE 2] NVARCHAR(53),
    [CONTRIBUTING FACTOR VEHICLE 3] NVARCHAR(53),
    [CONTRIBUTING FACTOR VEHICLE 4] NVARCHAR(30),
    [CONTRIBUTING FACTOR VEHICLE 5] NVARCHAR(30),
    COLLISION_ID INT,
    [VEHICLE TYPE CODE 1] NVARCHAR(35),
    [VEHICLE TYPE CODE 2] NVARCHAR(38),
    [VEHICLE TYPE CODE 3] NVARCHAR(35),
    [VEHICLE TYPE CODE 4] NVARCHAR(35),
    [VEHICLE TYPE CODE 5] NVARCHAR(35)
)
--Insert Data

BULK INSERT NYC_Accidents_2020
FROM 'NYC Accidents 2020.csv'
WITH 
(
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',  
    ROWTERMINATOR = '\n',   
    TABLOCK
)

--Retrieves the total number of accidents for each borough

SELECT BOROUGH, COUNT(*) as accident_count 
FROM NYC_Accidents_2020 
WHERE BOROUGH IS NOT NULL 
GROUP BY BOROUGH 
ORDER BY accident_count DESC

--Retrieves the total number of accidents for each hour of the day
SELECT 
    DATEPART(HOUR, [CRASH TIME]) AS hour, 
    COUNT(*) as accident_count 
FROM NYC_Accidents_2020  
GROUP BY DATEPART(HOUR, [CRASH TIME])
ORDER BY accident_count DESC

--Combines the contributing factors from five columns into one column and counts the occurrences of each contributing factor, excluding null and 'Unspecified' values
SELECT CONTRIBUTING_FACTOR, COUNT(*) as count 
FROM (
    SELECT [CONTRIBUTING FACTOR VEHICLE 1] AS CONTRIBUTING_FACTOR FROM NYC_Accidents_2020 
    UNION ALL
    SELECT [CONTRIBUTING FACTOR VEHICLE 2] FROM NYC_Accidents_2020 
    UNION ALL
    SELECT [CONTRIBUTING FACTOR VEHICLE 3] FROM NYC_Accidents_2020 
    UNION ALL
    SELECT [CONTRIBUTING FACTOR VEHICLE 4] FROM NYC_Accidents_2020 
    UNION ALL
    SELECT [CONTRIBUTING FACTOR VEHICLE 5] FROM NYC_Accidents_2020 
) AS subquery
WHERE CONTRIBUTING_FACTOR IS NOT NULL AND CONTRIBUTING_FACTOR <> 'Unspecified'
GROUP BY CONTRIBUTING_FACTOR 
ORDER BY count DESC

--This block of code combines the vehicle types from five columns into one column and counts the occurrences of each vehicle type, excluding null and 'UNKNOWN' values
SELECT VEHICLE_TYPE, COUNT(*) as count 
FROM (
    SELECT "VEHICLE TYPE CODE 1" AS VEHICLE_TYPE FROM NYC_Accidents_2020
    UNION ALL
    SELECT "VEHICLE TYPE CODE 2" FROM NYC_Accidents_2020
    UNION ALL
    SELECT "VEHICLE TYPE CODE 3" FROM NYC_Accidents_2020
    UNION ALL
    SELECT "VEHICLE TYPE CODE 4" FROM NYC_Accidents_2020
    UNION ALL
    SELECT "VEHICLE TYPE CODE 5" FROM NYC_Accidents_2020
)AS subquery
WHERE VEHICLE_TYPE IS NOT NULL AND VEHICLE_TYPE != 'UNKNOWN'
GROUP BY VEHICLE_TYPE 
ORDER BY count DESC
GO

--Calculates the average number of persons injured per accident for each borough
WITH borough_injury_stats AS (
    SELECT 
        BOROUGH, 
        COUNT(*) as total_accidents, 
        SUM("NUMBER OF PERSONS INJURED") as total_injured
    FROM NYC_Accidents_2020
    WHERE BOROUGH IS NOT NULL
    GROUP BY BOROUGH
)

SELECT 
    BOROUGH, 
    total_injured * 1.0 / total_accidents as avg_injured_per_accident
FROM borough_injury_stats
ORDER BY avg_injured_per_accident DESC

--Calculates the cumulative number of accidents for each borough for each day.

WITH daily_accidents AS (
    SELECT 
        BOROUGH, 
        "CRASH DATE", 
        COUNT(*) as accident_count
    FROM NYC_Accidents_2020
    WHERE BOROUGH IS NOT NULL
    GROUP BY BOROUGH, "CRASH DATE"
)

SELECT 
    BOROUGH, 
    "CRASH DATE", 
    SUM(accident_count) OVER (PARTITION BY BOROUGH ORDER BY "CRASH DATE") as cumulative_accidents
FROM daily_accidents
ORDER BY BOROUGH, "CRASH DATE"

--identifies the day of the week with the highest number of accidents for each borough.

WITH borough_day_accidents AS (
    SELECT 
        BOROUGH, 
        DATEPART(WEEKDAY, [CRASH DATE]) AS day_of_week, 
        COUNT(*) as accident_count
    FROM NYC_Accidents_2020
    WHERE BOROUGH IS NOT NULL
    GROUP BY BOROUGH, DATEPART(WEEKDAY, [CRASH DATE])
), max_accidents AS (
    SELECT BOROUGH, MAX(accident_count) as max_accident_count
    FROM borough_day_accidents
    GROUP BY BOROUGH
)

SELECT m.BOROUGH, 
    CASE 
        WHEN b.day_of_week = 1 THEN 'Sunday'
        WHEN b.day_of_week = 2 THEN 'Monday'
        WHEN b.day_of_week = 3 THEN 'Tuesday'
        WHEN b.day_of_week = 4 THEN 'Wednesday'
        WHEN b.day_of_week = 5 THEN 'Thursday'
        WHEN b.day_of_week = 6 THEN 'Friday'
        WHEN b.day_of_week = 7 THEN 'Saturday'
    END as day_of_week,
    m.max_accident_count
FROM max_accidents m
JOIN borough_day_accidents b ON m.BOROUGH = b.BOROUGH AND m.max_accident_count = b.accident_count
ORDER BY m.BOROUGH

/**prints the BOROUGH and CRASH DATE of each row in the NYC_Accidents_2020 table.
A cussor was not needed to acheive the results below but it is just an example of how we could use Cursors. 
**/
DECLARE @borough NVARCHAR(50), @crash_date DATE

DECLARE accidents_cursor CURSOR FOR 
SELECT BOROUGH, [CRASH DATE] FROM NYC_Accidents_2020

OPEN accidents_cursor

FETCH NEXT FROM accidents_cursor INTO @borough, @crash_date

WHILE @@FETCH_STATUS = 0
BEGIN
    PRINT 'Borough: ' + @borough + ', Crash Date: ' + CONVERT(NVARCHAR, @crash_date, 101)

    FETCH NEXT FROM accidents_cursor INTO @borough, @crash_date
END

CLOSE accidents_cursor
DEALLOCATE accidents_cursor
