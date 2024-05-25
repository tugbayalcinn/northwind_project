PYHTON CASE 1:
Ürün Fiyat Segmentasyonu:
WITH p_price AS (
        SELECT product_name,
               unit_price,
               CASE WHEN unit_price < 10                  THEN '0-10'
                    WHEN unit_price >= 10 AND unit_price < 20  THEN '10-20'
                    WHEN unit_price >= 20 AND unit_price < 30  THEN '20-30'
                    WHEN unit_price >= 30 AND unit_price < 40  THEN '30-40'
                    WHEN unit_price >= 40 AND unit_price < 50  THEN '40-50'
                    WHEN unit_price >= 50 AND unit_price < 60  THEN '50-60'
                    WHEN unit_price >= 60 AND unit_price < 70  THEN '60-70'
                    WHEN unit_price >= 70 AND unit_price < 80  THEN '70-80'
                    WHEN unit_price >= 80 AND unit_price < 90  THEN '80-90'
                    WHEN unit_price >= 90 AND unit_price < 100 THEN '90-100'
                    WHEN unit_price >= 100                THEN '100+'
                     END AS price_segment
          FROM products
       ) 
  SELECT 
       product_name,
       unit_price,
       price_segment,
       COUNT(product_name) OVER (PARTITION BY price_segment) AS segment_product_count
  FROM p_price;
PYTHON CASE 2:
Ürün Fiyatları İçin Önceki ve Sonraki Fiyat Karşılaştırılması
WITH cte_price AS (
SELECT
	d.product_id,
	p.product_name,
	ROUND(LEAD(d.unit_price) OVER (PARTITION BY p.product_name ORDER BY o.order_date)::NUMERIC,2) AS current_price,
	ROUND(LAG(d.unit_price) OVER (PARTITION BY p.product_name ORDER BY o.order_date)::NUMERIC,2) AS previous_unit_price
FROM products AS p
INNER JOIN order_details AS d
ON p.product_id = d.product_id
INNER JOIN orders AS o
ON d.order_id = o.order_id
)
SELECT
	c.product_name,
	c.current_price,
	c.previous_unit_price,
	ROUND(100*(c.current_price - c.previous_unit_price)/c.previous_unit_price) AS percentage_increase
FROM cte_price AS c
WHERE c.current_price != c.previous_unit_price
GROUP BY 
	c.product_name,
	c.current_price,
	c.previous_unit_price;

POWER BI CASE 1
Çalışanlar için satış tutarları incelemesi
WITH TOTAL as
	(WITH e_price as (
	SELECT  
		CONCAT(first_name,' ',last_name) AS name,
		title,
	    SUM(quantity::NUMERIC*unit_price::numeric) AS total_price, -- indirim hariç toplam satış 
		COUNT(DISTINCT od.order_id) as order_count, -- toplam sipariş sayısı
		COUNT(o.employee_id) as total_entry, -- toplam giriş sayısı
		ROUND(SUM(quantity::numeric*unit_price::numeric) / COUNT(DISTINCT od.order_id),2) AS entry_avg_amount, -- giriş başına ortalama tutar
		round(SUM(quantity::numeric*unit_price::numeric) / COUNT(o.employee_id),2) AS order_avg_amount -- sipariş başına ortalama tutar
	    FROM employees as e
	LEFT JOIN orders as o ON e.employee_id=o.employee_id
	LEFT JOIN customers as c ON o.customer_id=c.customer_id
	LEFT JOIN order_details as od ON od.order_id=o.order_id
	GROUP BY 1,2),
e_discount as (
	SELECT 
		concat(first_name,' ',last_name) as name,
		title,
		ROUND(SUM((quantity::numeric*unit_price::numeric)*discount::numeric),2) as discount 
	FROM order_details as od 
	left join orders as o  ON o.order_id=od.order_id
	left join employees as e ON e.employee_id = o.employee_id
	group by 1,2
	)
SELECT e.name,e.title,total_price,order_count,total_entry,entry_avg_amount,order_avg_amount,discount
FROM e_price as e
JOIN e_discount as ed ON e.name = ed.name AND e.title = ed.title)
 select *, 
	(total_price-discount) as indirimli_satis,-- indirimli satış
	 round((discount/total_price),2) AS indirim_yuzdesi
	from total;


POWER BI CASE 2 
Her bir ürün kategorisi için bölgesel tedarikçilerin stoklarının mevcut durumunu:
SELECT
	c.category_name,
	CASE
		WHEN s.country IN ('Australia', 'Singapore', 'Japan' ) THEN 'Asia-Pacific'
		WHEN s.country IN ('US', 'Brazil', 'Canada') THEN 'America'
		ELSE 'Europe'
	END AS supplier_region,
	p.unit_in_stock AS units_in_stock,
	p.unit_on_order AS units_on_order,
	p.reorder_level 
FROM suppliers AS s
INNER JOIN products AS p
ON s.supplier_id = p.supplier_id
INNER JOIN categories AS c
ON p.category_id = c.category_id
WHERE s.region IS NOT NULL
ORDER BY 
	supplier_region,
	c.category_name,
	p.unit_price;
POWER BI CASE 3
Her kategorinin kendi fiyat aralığına göre nasıl performans gösterdiğinin incelenmesi
SELECT
	c.category_name,
	CASE 
		WHEN p.unit_price < 20 THEN '1. Below $20'
		WHEN p.unit_price >= 20 AND p.unit_price <= 50 THEN '2. $20 - $50'
		WHEN p.unit_price > 50 THEN '3. Over $50'
		END AS price_range,
	ROUND(SUM(d.unit_price * d.quantity)) AS total_amount,
	COUNT(DISTINCT d.order_id) AS total_number_orders
FROM categories AS c
INNER JOIN products AS p
ON c.category_id =  p.category_id
INNER JOIN order_details AS d
ON d.product_id =  p.product_id
GROUP BY 
	c.category_name,
	price_range
ORDER BY 
	c.category_name,
	price_range;
POWER BI CASE 4
--Ülkelere göre nakliye bedeli, ve ortalama nakliye 

SELECT ship_country, 
ROUND(SUM(freight::NUMERIC),2) AS total_freight,
ROUND(AVG(freight:: NUMERIC),2) AS avg_freight
FROM orders
GROUP BY 1
ORDER BY 2 DESC;


--Nakiye bedeli en yüksek olan 5 ülke 
SELECT ship_country, 
ROUND(SUM(freight::NUMERIC),2) AS total_freight,
ROUND(AVG(freight:: NUMERIC),2) AS avg_freight
FROM orders
GROUP BY 1
ORDER BY 2 DESC
LIMIT 5;

-- Nakliye bedeli en düşük olan 5 ülke
SELECT ship_country, 
ROUND(SUM(freight:: NUMERIC),2) AS total_freight,
ROUND(AVG(freight:: NUMERIC),2) AS avg_freight
FROM orders
GROUP BY 1
ORDER BY 2
LIMIT 5;

-- Toplam ülke sayısı
SELECT 
COUNT(DISTINCT ship_country) AS total_country
FROM orders;
