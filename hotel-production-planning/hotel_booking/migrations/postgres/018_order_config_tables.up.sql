-- 018_order_config_tables.up.sql

-- 1. Справочник параметров конфигурации (Гости, Питание, Категория)
CREATE TABLE IF NOT EXISTS config_param (
    id SERIAL PRIMARY KEY,
    code VARCHAR(32) NOT NULL UNIQUE,
    name VARCHAR(128) NOT NULL,
    type VARCHAR(20) NOT NULL CHECK (type IN ('INT', 'ENUM', 'BOOL', 'NUMERIC')),
    unit VARCHAR(16)
);

-- 2. Ограничения (Логические, Арифметические, Функции)
CREATE TABLE IF NOT EXISTS config_constraint (
    id SERIAL PRIMARY KEY,
    class_id INTEGER NOT NULL REFERENCES classification_element(id) ON DELETE CASCADE,
    name VARCHAR(128) NOT NULL,
    constraint_type VARCHAR(20) NOT NULL CHECK (constraint_type IN ('LOGIC', 'ARITHMETIC', 'FUNCTION')),
    expression TEXT NOT NULL,
    error_msg VARCHAR(255) NOT NULL
);

-- 3. Заказы
CREATE TABLE IF NOT EXISTS orders (
    id SERIAL PRIMARY KEY,
    order_number VARCHAR(50) NOT NULL UNIQUE,
    order_date DATE NOT NULL DEFAULT CURRENT_DATE,
    customer_name VARCHAR(255) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'Черновик'
);

-- 4. Позиции заказа
CREATE TABLE IF NOT EXISTS order_positions (
    id SERIAL PRIMARY KEY,
    order_id INTEGER NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    product_id INTEGER NOT NULL REFERENCES product(id),
    quantity INTEGER NOT NULL DEFAULT 1 CHECK (quantity > 0)
);

-- 5. Значения параметров для конкретного варианта
CREATE TABLE IF NOT EXISTS config_variant_values (
    product_id INTEGER NOT NULL REFERENCES product(id) ON DELETE CASCADE,
    param_id INTEGER NOT NULL REFERENCES config_param(id) ON DELETE CASCADE,
    val_int INTEGER,
    val_str VARCHAR(128),
    PRIMARY KEY (product_id, param_id)
);