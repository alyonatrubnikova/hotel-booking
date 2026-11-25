-- 019_order_config_functions.up.sql

-- 1. Функция проверки ограничений (Усложненная)
CREATE OR REPLACE FUNCTION check_variant_constraints(
    p_class_id INTEGER,
    p_params JSONB
) RETURNS BOOLEAN AS $$
DECLARE
    v_guests INTEGER;
    v_category VARCHAR;
    v_food VARCHAR;
    v_area NUMERIC;
BEGIN
    v_guests := (p_params->>'GUESTS')::INTEGER;
    v_category := p_params->>'CATEGORY';
    v_food := p_params->>'FOOD';
    
    -- Определяем площадь (для теста)
    IF v_category = 'STANDARD' THEN v_area := 25; 
    ELSIF v_category = 'LUXE' THEN v_area := 40; 
    ELSE v_area := 50; END IF;

    -- 1. Проверка питания (Логика)
    IF v_category = 'STANDARD' AND v_food = 'ALL_INCLUSIVE' THEN
        RAISE EXCEPTION 'Нарушено ограничение (Логика): Тариф Всё включено недоступен для Стандарта';
    END IF;

    -- 2. Проверка площади (Арифметика). Специально ставим её ПЕРЕД проверкой гостей!
    IF (v_area / v_guests) < 10 THEN
        RAISE EXCEPTION 'Нарушено ограничение (Арифметика): Площадь на гостя меньше 10 кв.м. (Площадь: %, Гостей: %)', v_area, v_guests;
    END IF;

    -- 3. Проверка вместимости (Логика)
    IF v_category = 'STANDARD' AND v_guests > 2 THEN
        RAISE EXCEPTION 'Нарушено ограничение (Логика): В номере Стандарт могут жить максимум 2 гостя';
    END IF;
    
    IF v_category = 'LUXE' AND v_guests > 3 THEN
        RAISE EXCEPTION 'Нарушено ограничение (Логика): В Люксе могут жить максимум 3 гостя';
    END IF;

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- 2. Функция создания заказа с вариантом
CREATE OR REPLACE FUNCTION create_custom_order(
    p_customer_name VARCHAR,
    p_base_product_id INTEGER,
    p_quantity INTEGER,
    p_params JSONB
) RETURNS INTEGER AS $$
DECLARE
    v_order_id INTEGER;
    v_variant_id INTEGER;
    v_class_id INTEGER;
BEGIN
    -- Узнаем класс базового изделия
    SELECT class_id INTO v_class_id FROM product WHERE id = p_base_product_id;

    -- 1. Проверяем ограничения
    PERFORM check_variant_constraints(v_class_id, p_params);

    -- 2. Создаем заказ
    INSERT INTO orders (order_number, customer_name)
    VALUES ('ORD-' || floor(random() * 100000)::text, p_customer_name)
    RETURNING id INTO v_order_id;

    -- 3. Создаем Вариант исполнения (как модификацию базового)
    INSERT INTO product (name, short_name, class_id, base_product_id, is_modification)
    SELECT p.name || ' (Кастом)', p.short_name || '-V', p.class_id, p.id, TRUE
    FROM product p WHERE p.id = p_base_product_id
    RETURNING id INTO v_variant_id;

    -- 4. Сохраняем параметры
    INSERT INTO config_variant_values (product_id, param_id, val_int, val_str)
    VALUES 
        (v_variant_id, (SELECT id FROM config_param WHERE code='GUESTS'), (p_params->>'GUESTS')::INTEGER, NULL),
        (v_variant_id, (SELECT id FROM config_param WHERE code='CATEGORY'), NULL, p_params->>'CATEGORY'),
        (v_variant_id, (SELECT id FROM config_param WHERE code='FOOD'), NULL, p_params->>'FOOD');

    -- 5. Добавляем в позицию заказа
    INSERT INTO order_positions (order_id, product_id, quantity)
    VALUES (v_order_id, v_variant_id, p_quantity);

    RETURN v_order_id;
END;
$$ LANGUAGE plpgsql;