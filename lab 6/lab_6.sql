-- Лаптев М.И. ПС-22
-- 1. Добавить внешние ключи.
ALTER TABLE production
ADD CONSTRAINT FK_production_medicine
	FOREIGN KEY (id_medicine)
	REFERENCES medicine (id_medicine),

	CONSTRAINT FK_production_company
	FOREIGN KEY (id_company)
	REFERENCES company (id_company);

ALTER TABLE dealer
ADD CONSTRAINT FK_dealer_company
	FOREIGN KEY (id_company)
	REFERENCES company (id_company);

ALTER TABLE [order]
ADD CONSTRAINT FK_order_production
	FOREIGN KEY (id_production)
	REFERENCES production (id_production),

	CONSTRAINT FK_order_dealer
	FOREIGN KEY (id_dealer)
	REFERENCES dealer (id_dealer),

	CONSTRAINT FK_order_pharmacy
	FOREIGN KEY (id_pharmacy)
	REFERENCES pharmacy (id_pharmacy);

-- 2. Выдать информацию по всем заказам лекарства “Кордерон” компании “Аргус”
--    с указанием названий аптек, дат, объема заказов.
SELECT m.name 'drug name', c.name company, ph.name pharmacy, o.date, o.quantity 
FROM medicine m
JOIN production pr ON m.id_medicine = pr.id_medicine
JOIN company c ON pr.id_company = c.id_company
JOIN [order] o ON pr.id_production = o.id_production
JOIN pharmacy ph ON o.id_pharmacy = ph.id_pharmacy
WHERE m.name = 'Кордерон' AND c.name = 'Аргус'

-- 3. Дать список лекарств компании “Фарма”, на которые не были сделаны заказы
--    до 25 января.
SELECT c.name company, m.name 'drug name', MIN(o.date) drug_first_order_date
FROM medicine m
JOIN production pr ON m.id_medicine = pr.id_medicine
JOIN company c ON pr.id_company = c.id_company
JOIN [order] o ON o.id_production = pr.id_production
WHERE c.name = 'Фарма'
GROUP BY c.name, m.name
HAVING MIN(o.date) > '25/01/2019'

-- 4. Дать минимальный и максимальный баллы лекарств каждой фирмы, которая
--    оформила не менее 120 заказов.
SELECT c.name, MAX(pr.rating) max_rating, MIN(pr.rating) min_ratingv 
FROM company c
JOIN production pr ON pr.id_company = c.id_company
JOIN [order] o ON o.id_production = pr.id_production
GROUP BY c.name
HAVING COUNT(*) >= 120

-- 5. Дать списки сделавших заказы аптек по всем дилерам компании “AstraZeneca”.
--    Если у дилера нет заказов, в названии аптеки проставить NULL.
SELECT DISTINCT c.id_company, c.name, d.id_dealer, d.name, ph.name 
FROM dealer d
JOIN company c ON d.id_company = c.id_company
LEFT JOIN [order] o ON d.id_dealer = o.id_dealer
LEFT JOIN pharmacy ph ON o.id_pharmacy = ph.id_pharmacy
WHERE c.name = 'AstraZeneca'
ORDER BY d.id_dealer, ph.name

-- 6. Уменьшить на 20% стоимость всех лекарств, если она превышает 3000, а
--    длительность лечения не более 7 дней.

-- v1, хуже execution plan
--UPDATE production
--SET price = price * 0.8
--WHERE id_production IN (
--	SELECT id_production FROM medicine m
--	JOIN production p ON m.id_medicine = p.id_medicine
--	WHERE cure_duration <= 7 AND price > 3000
--)

UPDATE production
SET price = price * 0.8
FROM production p
JOIN medicine m ON m.id_medicine = p.id_medicine
WHERE cure_duration <= 7 AND price > 3000

-- 7. Добавить необходимые индексы для всех таблиц
-- таск 2
CREATE NONCLUSTERED INDEX IX_production_id_medicine
ON production
(
	id_medicine ASC
) INCLUDE (id_company)

CREATE NONCLUSTERED INDEX IX_order_id_production
ON [order]
(
	id_production ASC
) INCLUDE (id_pharmacy, date, quantity)

-- таск 3
CREATE NONCLUSTERED INDEX IX_production_id_company
ON production
(
	id_company ASC	
) INCLUDE (id_medicine)

-- таск 6
CREATE NONCLUSTERED INDEX IX_medicine_cure_duration
ON medicine
(
	cure_duration ASC
) 