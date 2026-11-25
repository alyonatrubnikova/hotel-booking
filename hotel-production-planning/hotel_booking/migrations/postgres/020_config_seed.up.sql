-- 020_config_seed.up.sql

-- =============================================
-- 1. СОЗДАНИЕ ТАБЛИЦ
-- =============================================
CREATE TABLE IF NOT EXISTS config_param (
    id SERIAL PRIMARY KEY,
    code VARCHAR(32) NOT NULL UNIQUE,
    name VARCHAR(128) NOT NULL,
    type VARCHAR(20) NOT NULL CHECK (type IN ('INT', 'ENUM', 'BOOL', 'NUMERIC')),
    unit VARCHAR(16)
);

CREATE TABLE IF NOT EXISTS config_class_param (
    class_id INTEGER NOT NULL REFERENCES classification_element(id) ON DELETE CASCADE,
    param_id INTEGER NOT NULL REFERENCES config_param(id) ON DELETE CASCADE,
    is_config_flag BOOLEAN DEFAULT TRUE,
    min_val NUMERIC,
    max_val NUMERIC,
    PRIMARY KEY (class_id, param_id)
);

CREATE TABLE IF NOT EXISTS orders (
    id SERIAL PRIMARY KEY,
    order_number VARCHAR(50) NOT NULL UNIQUE,
    order_date DATE NOT NULL DEFAULT CURRENT_DATE,
    customer_name VARCHAR(255) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'Черновик'
);

CREATE TABLE IF NOT EXISTS order_positions (
    id SERIAL PRIMARY KEY,
    order_id INTEGER NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    product_id INTEGER NOT NULL REFERENCES product(id),
    quantity INTEGER NOT NULL DEFAULT 1 CHECK (quantity > 0)
);

CREATE TABLE IF NOT EXISTS config_variant_values (
    product_id INTEGER NOT NULL REFERENCES product(id) ON DELETE CASCADE,
    param_id INTEGER NOT NULL REFERENCES config_param(id) ON DELETE CASCADE,
    val_int INTEGER,
    val_str VARCHAR(128),
    PRIMARY KEY (product_id, param_id)
);

-- =============================================
-- 2. СПРАВОЧНИК ПАРАМЕТРОВ
-- =============================================
INSERT INTO config_param (code, name, type, unit) VALUES
('ADULTS', 'Количество взрослых', 'INT', 'чел'),
('CHILDREN', 'Количество детей', 'INT', 'чел'),
('NIGHTS', 'Количество ночей', 'INT', 'ночей'),
('BABY_BEDS', 'Детская кроватка', 'INT', 'шт')
ON CONFLICT (code) DO NOTHING;

-- =============================================
-- 3. УНИВЕРСАЛЬНАЯ ПРИВЯЗКА ПАРАМЕТРОВ
-- =============================================
INSERT INTO config_class_param (class_id, param_id)
SELECT DISTINCT p.class_id, cp.id
FROM product p
CROSS JOIN config_param cp
WHERE cp.code IN ('ADULTS', 'CHILDREN', 'NIGHTS', 'BABY_BEDS')
AND p.class_id IS NOT NULL
ON CONFLICT DO NOTHING;

-- =============================================
-- 4. ФУНКЦИЯ ПОЛУЧЕНИЯ ПАРАМЕТРОВ
-- =============================================
DROP FUNCTION IF EXISTS get_config_params(INTEGER);
CREATE OR REPLACE FUNCTION get_config_params(p_product_id INTEGER)
RETURNS TABLE (
    param_id INTEGER, code VARCHAR, name VARCHAR, type VARCHAR, unit VARCHAR, min_val NUMERIC, max_val NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT DISTINCT cp.id, cp.code, cp.name, cp.type, cp.unit, ccp.min_val, ccp.max_val
    FROM config_param cp
    JOIN config_class_param ccp ON ccp.param_id = cp.id
    JOIN product p ON p.class_id = ccp.class_id
    WHERE p.id = p_product_id;
END;
$$ LANGUAGE plpgsql;

-- =============================================
-- 5. ФУНКЦИЯ ПРОВЕРКИ ОГРАНИЧЕНИЙ
-- =============================================
DROP FUNCTION IF EXISTS check_variant_constraints(VARCHAR, JSONB);
CREATE OR REPLACE FUNCTION check_variant_constraints(
    p_class_code VARCHAR,
    p_params JSONB
) RETURNS TEXT AS $$
DECLARE
    v_adults INTEGER; v_children INTEGER; v_nights INTEGER; v_baby_beds INTEGER;
    v_customer VARCHAR; v_errors TEXT := '';
    v_area NUMERIC; v_max_guests INTEGER; v_total_people INTEGER; v_paid_guests NUMERIC;
BEGIN
    v_customer := p_params->>'CUSTOMER_NAME';
    v_adults := COALESCE((p_params->>'ADULTS')::INTEGER, -1);
    v_children := COALESCE((p_params->>'CHILDREN')::INTEGER, -1);
    v_nights := COALESCE((p_params->>'NIGHTS')::INTEGER, -1);
    v_baby_beds := COALESCE((p_params->>'BABY_BEDS')::INTEGER, -1);

    -- 1. Проверка имени (Имя и Фамилия, без цифр)
    -- Используем POSITION, чтобы не ломалось на кириллице
    IF v_customer IS NULL OR v_customer = '' OR POSITION(' ' IN v_customer) = 0 THEN
        v_errors := v_errors || E'• Ошибка: Имя должно состоять из двух слов (Имя и Фамилия).\n';
    END IF;
    IF v_customer ~ '[0-9]' THEN
        v_errors := v_errors || E'• Ошибка: Имя не должно содержать цифр.\n';
    END IF;

    -- 2. Отрицательные числа
    IF v_adults < 0 OR v_children < 0 OR v_nights < 0 OR v_baby_beds < 0 THEN
        v_errors := v_errors || E'• Ошибка: Все числовые параметры не могут быть отрицательными.\n';
    END IF;

    -- 3. Только целые числа (без дробей)
    IF (p_params->>'ADULTS') ~ '\.' OR (p_params->>'CHILDREN') ~ '\.' OR (p_params->>'NIGHTS') ~ '\.' OR (p_params->>'BABY_BEDS') ~ '\.' THEN
        v_errors := v_errors || E'• Ошибка: Все числовые параметры должны быть целыми числами.\n';
    END IF;

    -- 4. Проверка кода тарифа
    IF p_class_code NOT IN ('STD_FULL', 'STD_BF', 'STD_HK', 'STD_WIFI', 'LUXE_FULL', 'LUXE_ALL', 'APT_CLEAN', 'APT_KITCHEN', 'APT_TRANSFER', 'APT_NONE') THEN
        v_errors := v_errors || E'• Ошибка: Неизвестный код тарифа.\n';
    END IF;

    IF v_errors != '' THEN RETURN v_errors; END IF;

    -- 5. Защита от деления на ноль
    v_total_people := v_adults + v_children;
    IF v_total_people = 0 THEN
        v_errors := v_errors || E'• Ошибка: В номере должен быть хотя бы один гость.\n';
        RETURN v_errors;
    END IF;

    -- 6. Логика: Дети без взрослых и Кроватки
    IF v_children > 0 AND v_adults = 0 THEN
        v_errors := v_errors || E'• Ошибка: Нельзя заселить детей без взрослых.\n';
    END IF;
    IF v_baby_beds > v_children THEN
        v_errors := v_errors || E'• Ошибка: Количество детских кроваток не может превышать количество детей.\n';
    END IF;
    IF v_baby_beds > 0 AND v_children = 0 THEN
        v_errors := v_errors || E'• Ошибка: Детская кроватка заказана, но детей нет.\n';
    END IF;

    -- 7. Параметры тарифов (Площадь и лимиты)
    IF p_class_code LIKE 'STD%' THEN
        v_area := 25; v_max_guests := 2;
        IF p_class_code = 'STD_BF' OR p_class_code = 'STD_HK' THEN v_area := 30; END IF;
        
        IF v_baby_beds > 0 THEN
            v_errors := v_errors || E'• Ошибка: В номерах категории Стандарт нет места для детских кроваток.\n';
        END IF;
    ELSIF p_class_code LIKE 'LUXE%' THEN
        v_area := 40; v_max_guests := 3;
    ELSIF p_class_code LIKE 'APT%' THEN
        v_area := 50; v_max_guests := 5;
    END IF;

    -- 8. Арифметика: Площадь на гостя
    IF (v_area / v_total_people) < 10 THEN
        v_errors := v_errors || format(E'• Ошибка: Площадь на гостя меньше 10 кв.м. (Площадь: %s, Людей: %s).\n', v_area, v_total_people);
    END IF;

    -- 9. Функция: Платные гости
    v_paid_guests := v_adults + (0.5 * v_children);
    IF v_paid_guests > v_max_guests THEN
        v_errors := v_errors || format(E'• Ошибка: В этом тарифе максимум %s платных гостей.\n', v_max_guests);
    END IF;

    -- 10. Количество ночей
    IF v_nights < 1 OR v_nights > 30 THEN
        v_errors := v_errors || E'• Ошибка: Количество ночей должно быть от 1 до 30.\n';
    END IF;

    RETURN v_errors;
END;
$$ LANGUAGE plpgsql;

-- =============================================
-- 6. ФУНКЦИЯ СОЗДАНИЯ ЗАКАЗА
-- =============================================
DROP FUNCTION IF EXISTS create_custom_order(VARCHAR, VARCHAR, JSONB);
CREATE OR REPLACE FUNCTION create_custom_order(
    p_customer_name VARCHAR,
    p_class_code VARCHAR,
    p_params JSONB
) RETURNS INTEGER AS $$
DECLARE
    v_order_id INTEGER;
    v_variant_id INTEGER;
    v_class_id INTEGER;
    v_base_product_id INTEGER;
    v_errors TEXT;
    v_final_params JSONB;
BEGIN
    -- Добавляем имя в JSON перед проверкой
    v_final_params := jsonb_set(p_params, '{CUSTOMER_NAME}', to_jsonb(p_customer_name));

    -- Теперь проверяем ограничения
    v_errors := check_variant_constraints(p_class_code, v_final_params);
    IF v_errors != '' THEN
        RAISE EXCEPTION '%', v_errors;
    END IF;

    -- Дальше ищем класс
    SELECT id INTO v_class_id FROM classification_element WHERE class_code = p_class_code;
    SELECT id INTO v_base_product_id FROM product WHERE class_id = v_class_id AND is_modification = FALSE LIMIT 1;

    -- Создаем заказ
    INSERT INTO orders (order_number, customer_name)
    VALUES ('ORD-' || floor(random() * 100000)::text, p_customer_name)
    RETURNING id INTO v_order_id;

    -- Создаем вариант
    INSERT INTO product (name, short_name, class_id, base_product_id, is_modification)
    SELECT p.name || ' (Кастом)', p.short_name || '-V', p.class_id, p.id, TRUE
    FROM product p WHERE p.id = v_base_product_id
    RETURNING id INTO v_variant_id;

    -- Сохраняем параметры
    INSERT INTO config_variant_values (product_id, param_id, val_int, val_str)
    VALUES 
        (v_variant_id, (SELECT id FROM config_param WHERE code='ADULTS'), (v_final_params->>'ADULTS')::INTEGER, NULL),
        (v_variant_id, (SELECT id FROM config_param WHERE code='CHILDREN'), (v_final_params->>'CHILDREN')::INTEGER, NULL),
        (v_variant_id, (SELECT id FROM config_param WHERE code='NIGHTS'), (v_final_params->>'NIGHTS')::INTEGER, NULL),
        (v_variant_id, (SELECT id FROM config_param WHERE code='BABY_BEDS'), (v_final_params->>'BABY_BEDS')::INTEGER, NULL);

    -- Позиция заказа
    INSERT INTO order_positions (order_id, product_id, quantity)
    VALUES (v_order_id, v_variant_id, 1);

    RETURN v_order_id;
END;
$$ LANGUAGE plpgsql;

-- =============================================
-- 7. ФУНКЦИЯ ВЫВОДА ДОКУМЕНТА
-- =============================================
CREATE OR REPLACE FUNCTION get_order_details(p_order_id INTEGER)
RETURNS TABLE (
    order_id INTEGER, order_number VARCHAR, customer_name VARCHAR, order_date DATE,
    position_id INTEGER, product_name VARCHAR, quantity INTEGER, params_json JSONB
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        o.id, o.order_number, o.customer_name, o.order_date, op.id, p.name, op.quantity,
        (SELECT jsonb_object_agg(cp.name, COALESCE(cvv.val_int::text, cvv.val_str))
         FROM config_variant_values cvv
         JOIN config_param cp ON cp.id = cvv.param_id
         WHERE cvv.product_id = op.product_id)
    FROM orders o
    JOIN order_positions op ON op.order_id = o.id
    JOIN product p ON p.id = op.product_id
    WHERE o.id = p_order_id;
END;
$$ LANGUAGE plpgsql;

-- =============================================
-- 8. ФУНКЦИЯ ВЫВОДА ВСЕХ ЗАКАЗОВ
-- =============================================
CREATE OR REPLACE FUNCTION get_all_orders()
RETURNS TABLE (
    order_id INTEGER, order_number VARCHAR, customer_name VARCHAR, order_date DATE, status VARCHAR, total_items INTEGER, total_price NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT o.id, o.order_number, o.customer_name, o.order_date, o.status, COUNT(op.id)::INTEGER, 0::NUMERIC
    FROM orders o
    LEFT JOIN order_positions op ON op.order_id = o.id
    GROUP BY o.id, o.order_number, o.customer_name, o.order_date, o.status
    ORDER BY o.id DESC;
END;
$$ LANGUAGE plpgsql;

-- =============================================
-- 9. ТЕСТОВЫЕ ЗАКАЗЫ
-- =============================================
SELECT create_custom_order('Иванов Иван', 'LUXE_FULL', '{"ADULTS": 2, "CHILDREN": 1, "NIGHTS": 5, "BABY_BEDS": 1}'::jsonb);
SELECT create_custom_order('Петров Петр', 'APT_CLEAN', '{"ADULTS": 3, "CHILDREN": 1, "NIGHTS": 10, "BABY_BEDS": 0}'::jsonb);
SELECT create_custom_order('Сидоров Сидор', 'STD_FULL', '{"ADULTS": 1, "CHILDREN": 0, "NIGHTS": 2, "BABY_BEDS": 0}'::jsonb);