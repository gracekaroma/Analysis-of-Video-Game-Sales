USE VideoGameSalesDB
GO

SELECT COUNT(*) OVER() FROM dbo.videoGameTable2024; -- 64.016
SELECT TOP 100 * FROM dbo.videoGameTable2024

-- 1. Which titles sold the most worldwide?
SELECT
	games_title,
	worldwide_sales,
	worldwide_sales_rank
FROM (
	SELECT
		CAST(title AS nvarchar) AS games_title,
		ROUND(SUM(CAST(total_sales AS FLOAT)), 1) AS worldwide_sales,
		DENSE_RANK() OVER (ORDER BY ROUND(SUM(CAST(total_sales AS FLOAT)), 1) DESC) AS worldwide_sales_rank
	FROM dbo.videoGameTable2024
	GROUP BY CAST(title AS nvarchar)
) t
WHERE worldwide_sales IS NOT NULL AND worldwide_sales_rank <= 10
ORDER BY worldwide_sales DESC

-- 2. Which year had the highest sales? Is the industry growing over time?
SELECT
	release_year,
	worldwide_sales,
	previous_year_sales,
	ISNULL(CAST(worldwide_sales - previous_year_sales AS FLOAT), 0) AS YoY_change
FROM (
	SELECT 
		YEAR(release_date) AS release_year,
		ROUND(SUM(CAST(total_sales AS FLOAT)), 1) AS worldwide_sales,
		LAG(ROUND(SUM(CAST(total_sales AS FLOAT)), 1)) OVER(ORDER BY YEAR(release_date)) AS previous_year_sales
	FROM dbo.videoGameTable2024
	WHERE YEAR(release_date) IS NOT NULL AND total_sales IS NOT NULL
	GROUP BY YEAR(release_date)
) t
ORDER BY ROUND(SUM(CAST(total_sales AS FLOAT)), 1) DESC

-- 3. Do any consoles seem to specialize in a particular genre?
WITH count_by_genre AS (
	SELECT 
		CAST(console AS nvarchar) AS console,
		CAST(genre AS nvarchar) AS genre,
		COUNT(*) AS total_game_genre
	FROM dbo.videoGameTable2024
	GROUP BY CAST(console AS nvarchar), CAST(genre AS nvarchar)
)

, count_all AS (
	SELECT
		CAST(console AS nvarchar) AS console,
		COUNT(*) AS total_game
	FROM dbo.videoGameTable2024
	GROUP BY CAST(console AS nvarchar)
)
SELECT
	console,
	genre,
	total_game_genre,
	game_percentage,
	CASE
		WHEN game_percentage > 50 THEN 'Specialized'
		WHEN game_percentage > 35 THEN 'Generalist'
		ELSE 'Genre-Diverse'
	END console_segment
FROM (
	SELECT
		cbg.console,
		cbg.genre,
		cbg.total_game_genre,
		ca.total_game,
		ROUND(100.0 * CAST(cbg.total_game_genre AS FLOAT) / CAST(ca.total_game AS FLOAT), 2) AS game_percentage
	FROM count_by_genre AS cbg JOIN count_all AS ca
	ON cbg.console = ca.console
) t
ORDER BY game_percentage DESC, genre DESC

-- 4. What titles are popular in one region but flop in another?
WITH region_sales AS (
	SELECT
		CAST(title AS nvarchar) AS title,
		SUM(na_sales) AS na_sales,
		SUM(jp_sales) AS jp_sales,
		SUM(pal_sales) AS pal_sales,
		SUM(other_sales) AS other_sales,
		COUNT(*) AS total_title
	FROM dbo.videoGameTable2024
	GROUP BY CAST(title AS nvarchar)
)
SELECT 
	title,
	na_sales,
	jp_sales,
	pal_sales,
	other_sales,
	total_title,
	CASE
		WHEN na_sales >= ISNULL(jp_sales, 0) AND na_sales >= ISNULL(pal_sales, 0) AND na_sales >= ISNULL(other_sales, 0) THEN 'North America'
		WHEN jp_sales >= ISNULL(na_sales, 0) AND jp_sales >= ISNULL(pal_sales, 0) AND jp_sales >= ISNULL(other_sales, 0) THEN 'Japan'
		WHEN pal_sales >= ISNULL(na_sales, 0) AND pal_sales >= ISNULL(jp_sales, 0) AND pal_sales >= ISNULL(other_sales, 0) THEN 'Europe and Africa'
		ELSE 'Other Region'
	END AS popular_title,
	CASE
		WHEN na_sales <= ISNULL(jp_sales, 0) AND na_sales <= ISNULL(pal_sales, 0) AND na_sales <= ISNULL(other_sales, 0) THEN 'North America'
        WHEN jp_sales <= ISNULL(na_sales, 0) AND jp_sales <= ISNULL(pal_sales, 0) AND jp_sales <= ISNULL(other_sales, 0) THEN 'Japan'
        WHEN pal_sales <= ISNULL(na_sales, 0) AND pal_sales <= ISNULL(jp_sales, 0) AND pal_sales <= ISNULL(other_sales, 0) THEN 'Europe and Africa'
        ELSE 'Other Region'
	END AS flop_title
FROM region_sales
ORDER BY total_title DESC