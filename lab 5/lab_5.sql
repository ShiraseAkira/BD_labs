-- Лаптев М.И. ПС-22
-- 1. Добавить внешние ключи.
ALTER TABLE [room]
ADD CONSTRAINT FK_room_hotel
	FOREIGN KEY (id_hotel)
	REFERENCES [hotel] (id_hotel),

	CONSTRAINT FK_room_room_category
	FOREIGN KEY (id_room_category)
	REFERENCES [room_category] (id_room_category);

ALTER TABLE [booking]
ADD CONSTRAINT FK_booking_client
	FOREIGN KEY (id_client)
	REFERENCES [client] (id_client);

ALTER TABLE [room_in_booking]
ADD CONSTRAINT FK_room_in_booking_booking
	FOREIGN KEY (id_booking)
	REFERENCES [booking] (id_booking),

	CONSTRAINT FK_room_in_booking_room
	FOREIGN KEY (id_room)
	REFERENCES [room] (id_room);


-- 2. Выдать информацию о клиентах гостиницы “Космос”, проживающих в номерах категории “Люкс” на 1 апреля 2019г.
WITH proper_room_id AS (
	SELECT id_room FROM room
	WHERE id_hotel IN (
		SELECT id_hotel FROM hotel
		WHERE name = 'Космос'
	) AND
	id_room_category IN (
		SELECT id_room_category FROM room_category
		WHERE name = 'Люкс'
	)
),
proper_date_rib AS (
	SELECT id_booking, id_room FROM room_in_booking
	WHERE checkin_date <= '1/04/2019' AND checkout_date > '1/04/2019'
)

SELECT client.* FROM proper_date_rib
JOIN proper_room_id ON proper_date_rib.id_room = proper_room_id.id_room
JOIN booking ON proper_date_rib.id_booking = booking.id_booking
JOIN client ON client.id_client = booking.id_client;

-- Или так, если CTE не нравится
--SELECT c.* FROM room r
--JOIN hotel h ON r.id_hotel = h.id_hotel
--JOIN room_category rc ON rc.id_room_category = r.id_room_category
--JOIN room_in_booking rib ON r.id_room = rib.id_room
--JOIN booking b ON rib.id_booking = b.id_booking
--JOIN client c ON c.id_client = b.id_client
--WHERE h.name = 'Космос' AND rc.name = 'Люкс' AND checkin_date <= '1/04/2019' AND checkout_date > '1/04/2019'

-- 3. Дать список свободных номеров всех гостиниц на 22 апреля.
WITH occupied_room(id_room) AS (
	SELECT DISTINCT id_room FROM room_in_booking
	WHERE checkin_date <= '22/04/2019' AND checkout_date > '22/04/2019'
)
--SELECT * FROM room
--WHERE room.id_room NOT IN (SELECT * FROM occupied_room)
--ORDER BY id_room

-- Можно использовать закомменченый выше селект если не нужны имена гостиниц/категорий а только их id
-- ну и ORDER BY тоже опционально
SELECT hotel.name 'hotel name', room_category.name category, room.price FROM room
JOIN hotel ON room.id_hotel = hotel.id_hotel
JOIN room_category ON room_category.id_room_category = room.id_room_category
WHERE room.id_room NOT IN (SELECT * FROM occupied_room)
ORDER BY 'hotel name', category, price;


-- 4. Дать количество проживающих в гостинице “Космос” на 23 марта по каждой категории номеров
WITH proper_room_id AS (
	SELECT id_room, id_room_category FROM room
	WHERE id_hotel IN (
		SELECT id_hotel FROM hotel
		WHERE name = 'Космос'
	)
),
proper_date_rib AS (
	SELECT * FROM room_in_booking
	WHERE checkin_date <= '23/03/2019' AND checkout_date > '23/03/2019'
)

SELECT proper_room_id.id_room_category, room_category.name category, COUNT(proper_room_id.id_room_category) occupied_room_count FROM proper_date_rib
JOIN proper_room_id ON proper_date_rib.id_room = proper_room_id.id_room
JOIN room_category ON proper_room_id.id_room_category = room_category.id_room_category
GROUP BY room_category.name, proper_room_id.id_room_category;


-- 5. Дать список последних проживавших клиентов по всем комнатам гостиницы “Космос”, 
--    выехавшим в апреле с указанием даты выезда.
/*не совсем понятно условие, то ли имелись ввиду а) клиенты выехавшие из комнаты последним, 
и это происходило в апреле (т.е. с апреля номер никем не занимался)
 то ли б) последний клиент который из номера в апреле выехал
 но а) мало вероятно, т.к. таких нет, что видно из запроса ниже, потому решение для варианта б) */
-- 	SELECT id_room, MAX(checkout_date) last_date FROM room_in_booking
--	GROUP BY id_room
--	HAVING MONTH(MAX(checkout_date)) = 4

WITH proper_room_id AS (
	SELECT id_room FROM room
	WHERE id_hotel IN (
		SELECT id_hotel FROM hotel
		WHERE name = 'Космос'
	)
),
last_april_room_booking AS (
	SELECT id_room, MAX(checkout_date) checkout_date FROM room_in_booking
	WHERE MONTH(checkout_date) = 4
	AND id_room IN (SELECT * FROM proper_room_id)
	GROUP BY id_room
)

SELECT client.*, room_in_booking.id_room, room_in_booking.checkout_date FROM room_in_booking
JOIN last_april_room_booking ON room_in_booking.id_room = last_april_room_booking.id_room 
		AND room_in_booking.checkout_date = last_april_room_booking.checkout_date
--order by room_in_booking.id_room
--В этом местя я несколько офигел получив для id_room 2 и 22 по два клиента одновременно
JOIN booking ON room_in_booking.id_booking = booking.id_booking
JOIN client ON booking.id_client = client.id_client;


-- 6. Продлить на 2 дня дату проживания в гостинице “Космос” всем клиентам 
-- комнат категории “Бизнес”, которые заселились 10 мая.
WITH proper_room_id AS (
	SELECT id_room FROM room
	WHERE id_hotel IN (
		SELECT id_hotel FROM hotel
		WHERE name = 'Космос'
	) AND
	id_room_category IN (
		SELECT id_room_category FROM room_category
		WHERE name = 'Бизнес'
	)
)

UPDATE room_in_booking 
SET checkout_date = DATEADD(day, 2, checkout_date)
WHERE checkin_date = '10/05/2019'
	AND id_room IN (SELECT * FROM proper_room_id);


-- 7. Найти все "пересекающиеся" вариантыпроживания. Правильноесостояние:
--	не может быть забронирован один номер на одну дату несколько раз,
--  т.к. нельзя заселиться нескольким клиентам в один номер.
--  Записи в таблице room_in_booking с id_room_in_booking=5 и 2154
--  являются примером неправильного с остояния, которые необходимо найти.
--  Результирующий кортеж выборки должен содержать информацию о двух конфликтующих номерах.
SELECT * FROM room_in_booking t1
JOIN room_in_booking t2
ON t1.id_room = t2.id_room
	AND t1.id_room_in_booking < t2.id_room_in_booking
WHERE t1.checkin_date < t2.checkout_date AND t2.checkin_date < t1.checkout_date


-- 8. Создать бронирование в транзакции.
-- не понятно, что тут конкретно имеется ввиду:
-- 1)Что есть бронирование? 
--      Трактовал как запись в [booking] и соответсвующая(ие) ей запись(и) в [room_in_booking]
-- 2)На основании чего создавать? 
--      Исхожу из того, что нам уже известены id_client, id_room, checkin_date и checkout_date,
-- 3)Если посмотреть данные:
--SELECT DISTINCT id_booking, COUNT(*) a FROM room_in_booking
--GROUP BY id_booking
--order by a desc
-- , то мы увидим, что одной записи в [booking] может соответсвовать несколько забронированых комнат.
-- Что делать, если бронируется несколько комнат, часть из которых не валидны?
-- Т.е. требуемые интервалы для части комнат уже заняты. Отменять бронирование для всех комнат, 
-- или только для не правильных?
--      Исходил из того что, правильные будут забронированы, а не правильные - нет.

-- Данные на основе которых мы создаем бронирование, полученные к примеру как параметры
DECLARE @client int = 1;
DECLARE @roomToBook TABLE (id INT IDENTITY(1,1), id_room INT, checkin_date DATE, checkout_date DATE);
INSERT INTO @roomToBook VALUES (1, '1/01/2019', '10/01/2019'), 
								(2, '1/02/2019', '10/02/2019'), 
								(3, '19/05/2019', '21/05/2019');
-- Переменные
DECLARE @roomCounter int = 1;
DECLARE @maxRoomCounter int = (SELECT COUNT(*) FROM @roomToBook);
DECLARE @bookedCounter int = 0;
DECLARE @idBooking int;

-- Запрещаем добавлять комнаты
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
BEGIN TRAN
INSERT INTO booking VALUES (@client, (SELECT CAST(GETDATE() AS DATE )));
SET @idBooking = @@IDENTITY;

WHILE @roomCounter <= @maxRoomCounter
BEGIN
	IF NOT EXISTS (
		SELECT * FROM room_in_booking rib
		JOIN (SELECT * FROM @roomToBook WHERE id = @roomCounter) rtb
		ON rib.id_room = rtb.id_room
		WHERE rib.checkin_date < rtb.checkout_date AND rtb.checkin_date < rib.checkout_date
	) BEGIN
		INSERT INTO room_in_booking 
		SELECT @idBooking, id_room, checkin_date, checkout_date FROM @roomToBook WHERE id = @roomCounter;
		SET @bookedCounter = @bookedCounter + 1
	END

	SET @roomCounter = @roomCounter + 1
END
SELECT @bookedCounter


IF @bookedCounter > 0
BEGIN
	COMMIT
END ELSE BEGIN
	ROLLBACK
END;


-- 9. Добавить необходимые индексы для всех таблиц
-- Не вижу смысла создавать индексы для таблиц [hotel] и [room_category], поскольку
--SELECT * FROM hotel -- Всего 9 записей
--SELECT * FROM room_category -- Всего 6 записей

CREATE NONCLUSTERED INDEX IX_room_id_hotel_id_room_category
ON room
(
	id_hotel ASC,
	id_room_category ASC
);

CREATE NONCLUSTERED INDEX IX_room_in_booking_id_room_id_booking_checkin_date_checkout_date
ON room_in_booking
(
	id_room ASC,
	id_booking ASC,
	checkin_date ASC,
	checkout_date ASC
);