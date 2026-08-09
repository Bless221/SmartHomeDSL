-- =========================================================
-- SmartHomeDB init.sql
-- PostgreSQL schema + seed data for SmartHomeDSL project
-- =========================================================

-- =========================================================
-- 1. REFERENCE TABLES
-- =========================================================

CREATE TABLE Rooms (
    room_id     SERIAL PRIMARY KEY,
    name        VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE DeviceTypes (
    device_type_id  SERIAL PRIMARY KEY,
    name            VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE SensorTypes (
    sensor_type_id  SERIAL PRIMARY KEY,
    name            VARCHAR(50) NOT NULL UNIQUE,
    unit            VARCHAR(20) -- единица измерения (C, %, ppm, bool и т.д.)
);

-- =========================================================
-- 2. CORE TABLES
-- =========================================================

CREATE TABLE Devices (
    device_id       SERIAL PRIMARY KEY,
    name            VARCHAR(100) NOT NULL,
    room_id         INT NOT NULL REFERENCES Rooms(room_id),
    device_type_id  INT NOT NULL REFERENCES DeviceTypes(device_type_id),
    state           VARCHAR(20) NOT NULL DEFAULT 'OFF',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE Sensors (
    sensor_id       SERIAL PRIMARY KEY,
    name            VARCHAR(100) NOT NULL,
    device_id       INT NOT NULL REFERENCES Devices(device_id),
    sensor_type_id  INT NOT NULL REFERENCES SensorTypes(sensor_type_id),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE AutomationRules (
    rule_id         SERIAL PRIMARY KEY,
    name            VARCHAR(150) NOT NULL,
    condition_expr  TEXT NOT NULL,   -- условие DSL, например "temperature > 25"
    action_expr     TEXT NOT NULL,   -- действие DSL, например "turn_off heater"
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- =========================================================
-- 3. HISTORY / BIG DATA TABLES (BIGINT PK, TIMESTAMPTZ)
-- =========================================================

CREATE TABLE DeviceStateHistory (
    history_id  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    device_id   INT NOT NULL REFERENCES Devices(device_id),
    old_state   VARCHAR(20),
    new_state   VARCHAR(20) NOT NULL,
    changed_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE SensorHistory (
    history_id  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    sensor_id   INT NOT NULL REFERENCES Sensors(sensor_id),
    value       NUMERIC(10,2) NOT NULL,
    recorded_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE Events (
    event_id    BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    rule_id     INT REFERENCES AutomationRules(rule_id),
    device_id   INT NOT NULL REFERENCES Devices(device_id),
    description TEXT NOT NULL,
    event_time  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE Logs (
    log_id      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    level       VARCHAR(10) NOT NULL, -- INFO / WARNING / ERROR
    source      VARCHAR(100) NOT NULL, -- модуль-источник (Interpreter, DB, API...)
    message     TEXT NOT NULL,
    logged_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- =========================================================
-- 4. INDEXES (Big Data optimization on time fields)
-- =========================================================

CREATE INDEX idx_devicestatehistory_changed_at ON DeviceStateHistory(changed_at);
CREATE INDEX idx_sensorhistory_recorded_at    ON SensorHistory(recorded_at);
CREATE INDEX idx_events_event_time            ON Events(event_time);
CREATE INDEX idx_logs_logged_at               ON Logs(logged_at);

-- дополнительные индексы по внешним ключам для истории
CREATE INDEX idx_devicestatehistory_device_id ON DeviceStateHistory(device_id);
CREATE INDEX idx_sensorhistory_sensor_id      ON SensorHistory(sensor_id);
CREATE INDEX idx_events_device_id             ON Events(device_id);
CREATE INDEX idx_events_rule_id               ON Events(rule_id);

-- =========================================================
-- 5. SEED DATA
-- =========================================================

-- 5.1 Rooms (6)
INSERT INTO Rooms (name) VALUES
('Прихожая'),
('Гостиная'),
('Спальня'),
('Кухня'),
('Ванная'),
('Балкон');

-- 5.2 DeviceTypes (15)
INSERT INTO DeviceTypes (name) VALUES
('Light'),
('Climate'),
('TV'),
('Socket'),
('Curtain'),
('DoorLock'),
('AirPurifier'),
('Hood'),
('Refrigerator'),
('Oven'),
('Dishwasher'),
('Kettle'),
('FloorHeating'),
('Fan'),
('Siren');

-- 5.3 SensorTypes (9)
INSERT INTO SensorTypes (name, unit) VALUES
('Temperature', 'C'),
('Humidity', '%'),
('Motion', 'bool'),
('Door', 'bool'),
('Smoke', 'bool'),
('Gas', 'ppm'),
('CO2', 'ppm'),
('Leak', 'bool'),
('LightLevel', 'lux');

-- 5.4 Devices (26), распределены по комнатам:
-- Прихожая(3): Light, DoorLock, Siren
-- Гостиная(6): Light, Climate, TV, Curtain, Socket, AirPurifier
-- Спальня(5): Light, Climate, Curtain, Socket, Fan
-- Кухня(7): Light, Hood, Refrigerator, Oven, Dishwasher, Kettle, Socket
-- Ванная(3): Light, FloorHeating, Socket
-- Балкон(2): Light, Curtain
INSERT INTO Devices (name, room_id, device_type_id, state) VALUES
-- Прихожая (room_id=1)
('Прихожая - Свет', 1, (SELECT device_type_id FROM DeviceTypes WHERE name='Light'), 'OFF'),
('Прихожая - Замок двери', 1, (SELECT device_type_id FROM DeviceTypes WHERE name='DoorLock'), 'LOCKED'),
('Прихожая - Сирена', 1, (SELECT device_type_id FROM DeviceTypes WHERE name='Siren'), 'OFF'),
-- Гостиная (room_id=2)
('Гостиная - Свет', 2, (SELECT device_type_id FROM DeviceTypes WHERE name='Light'), 'ON'),
('Гостиная - Кондиционер', 2, (SELECT device_type_id FROM DeviceTypes WHERE name='Climate'), 'OFF'),
('Гостиная - Телевизор', 2, (SELECT device_type_id FROM DeviceTypes WHERE name='TV'), 'OFF'),
('Гостиная - Шторы', 2, (SELECT device_type_id FROM DeviceTypes WHERE name='Curtain'), 'CLOSED'),
('Гостиная - Розетка', 2, (SELECT device_type_id FROM DeviceTypes WHERE name='Socket'), 'ON'),
('Гостиная - Очиститель воздуха', 2, (SELECT device_type_id FROM DeviceTypes WHERE name='AirPurifier'), 'OFF'),
-- Спальня (room_id=3)
('Спальня - Свет', 3, (SELECT device_type_id FROM DeviceTypes WHERE name='Light'), 'OFF'),
('Спальня - Кондиционер', 3, (SELECT device_type_id FROM DeviceTypes WHERE name='Climate'), 'ON'),
('Спальня - Шторы', 3, (SELECT device_type_id FROM DeviceTypes WHERE name='Curtain'), 'OPEN'),
('Спальня - Розетка', 3, (SELECT device_type_id FROM DeviceTypes WHERE name='Socket'), 'OFF'),
('Спальня - Вентилятор', 3, (SELECT device_type_id FROM DeviceTypes WHERE name='Fan'), 'OFF'),
-- Кухня (room_id=4)
('Кухня - Свет', 4, (SELECT device_type_id FROM DeviceTypes WHERE name='Light'), 'ON'),
('Кухня - Вытяжка', 4, (SELECT device_type_id FROM DeviceTypes WHERE name='Hood'), 'OFF'),
('Кухня - Холодильник', 4, (SELECT device_type_id FROM DeviceTypes WHERE name='Refrigerator'), 'ON'),
('Кухня - Духовка', 4, (SELECT device_type_id FROM DeviceTypes WHERE name='Oven'), 'OFF'),
('Кухня - Посудомойка', 4, (SELECT device_type_id FROM DeviceTypes WHERE name='Dishwasher'), 'OFF'),
('Кухня - Чайник', 4, (SELECT device_type_id FROM DeviceTypes WHERE name='Kettle'), 'OFF'),
('Кухня - Розетка', 4, (SELECT device_type_id FROM DeviceTypes WHERE name='Socket'), 'ON'),
-- Ванная (room_id=5)
('Ванная - Свет', 5, (SELECT device_type_id FROM DeviceTypes WHERE name='Light'), 'OFF'),
('Ванная - Теплый пол', 5, (SELECT device_type_id FROM DeviceTypes WHERE name='FloorHeating'), 'ON'),
('Ванная - Розетка', 5, (SELECT device_type_id FROM DeviceTypes WHERE name='Socket'), 'OFF'),
-- Балкон (room_id=6)
('Балкон - Свет', 6, (SELECT device_type_id FROM DeviceTypes WHERE name='Light'), 'OFF'),
('Балкон - Шторы', 6, (SELECT device_type_id FROM DeviceTypes WHERE name='Curtain'), 'CLOSED');

-- 5.5 Sensors (18), привязаны к устройствам
INSERT INTO Sensors (name, device_id, sensor_type_id) VALUES
-- Прихожая
('Датчик движения - Прихожая', (SELECT device_id FROM Devices WHERE name='Прихожая - Свет'), (SELECT sensor_type_id FROM SensorTypes WHERE name='Motion')),
('Датчик двери - Прихожая', (SELECT device_id FROM Devices WHERE name='Прихожая - Замок двери'), (SELECT sensor_type_id FROM SensorTypes WHERE name='Door')),
-- Гостиная
('Датчик температуры - Гостиная', (SELECT device_id FROM Devices WHERE name='Гостиная - Кондиционер'), (SELECT sensor_type_id FROM SensorTypes WHERE name='Temperature')),
('Датчик влажности - Гостиная', (SELECT device_id FROM Devices WHERE name='Гостиная - Кондиционер'), (SELECT sensor_type_id FROM SensorTypes WHERE name='Humidity')),
('Датчик CO2 - Гостиная', (SELECT device_id FROM Devices WHERE name='Гостиная - Очиститель воздуха'), (SELECT sensor_type_id FROM SensorTypes WHERE name='CO2')),
('Датчик освещенности - Гостиная', (SELECT device_id FROM Devices WHERE name='Гостиная - Свет'), (SELECT sensor_type_id FROM SensorTypes WHERE name='LightLevel')),
-- Спальня
('Датчик температуры - Спальня', (SELECT device_id FROM Devices WHERE name='Спальня - Кондиционер'), (SELECT sensor_type_id FROM SensorTypes WHERE name='Temperature')),
('Датчик движения - Спальня', (SELECT device_id FROM Devices WHERE name='Спальня - Свет'), (SELECT sensor_type_id FROM SensorTypes WHERE name='Motion')),
-- Кухня
('Датчик газа - Кухня', (SELECT device_id FROM Devices WHERE name='Кухня - Духовка'), (SELECT sensor_type_id FROM SensorTypes WHERE name='Gas')),
('Датчик дыма - Кухня', (SELECT device_id FROM Devices WHERE name='Кухня - Духовка'), (SELECT sensor_type_id FROM SensorTypes WHERE name='Smoke')),
('Датчик температуры - Холодильник', (SELECT device_id FROM Devices WHERE name='Кухня - Холодильник'), (SELECT sensor_type_id FROM SensorTypes WHERE name='Temperature')),
('Датчик протечки - Посудомойка', (SELECT device_id FROM Devices WHERE name='Кухня - Посудомойка'), (SELECT sensor_type_id FROM SensorTypes WHERE name='Leak')),
('Датчик CO2 - Кухня', (SELECT device_id FROM Devices WHERE name='Кухня - Вытяжка'), (SELECT sensor_type_id FROM SensorTypes WHERE name='CO2')),
-- Ванная
('Датчик влажности - Ванная', (SELECT device_id FROM Devices WHERE name='Ванная - Теплый пол'), (SELECT sensor_type_id FROM SensorTypes WHERE name='Humidity')),
('Датчик температуры - Ванная', (SELECT device_id FROM Devices WHERE name='Ванная - Теплый пол'), (SELECT sensor_type_id FROM SensorTypes WHERE name='Temperature')),
('Датчик протечки - Ванная', (SELECT device_id FROM Devices WHERE name='Ванная - Розетка'), (SELECT sensor_type_id FROM SensorTypes WHERE name='Leak')),
-- Балкон
('Датчик температуры - Балкон', (SELECT device_id FROM Devices WHERE name='Балкон - Свет'), (SELECT sensor_type_id FROM SensorTypes WHERE name='Temperature')),
('Датчик освещенности - Балкон', (SELECT device_id FROM Devices WHERE name='Балкон - Свет'), (SELECT sensor_type_id FROM SensorTypes WHERE name='LightLevel')),
('Датчик двери - Балкон', (SELECT device_id FROM Devices WHERE name='Балкон - Шторы'), (SELECT sensor_type_id FROM SensorTypes WHERE name='Door'));

-- 5.6 AutomationRules (5 правил для демонстрации)
INSERT INTO AutomationRules (name, condition_expr, action_expr, is_active) VALUES
('Авто-отключение кондиционера', 'temperature > 25', 'turn_off climate', TRUE),
('Свет по движению в прихожей', 'motion == true AND time BETWEEN 18:00 AND 23:00', 'turn_on light', TRUE),
('Сирена при дыме на кухне', 'smoke == true', 'turn_on siren', TRUE),
('Закрытие штор ночью', 'time == 22:00', 'close curtain', TRUE),
('Оповещение о протечке', 'leak == true', 'send_notification', TRUE);

-- 5.7 DeviceStateHistory (12 строк)
INSERT INTO DeviceStateHistory (device_id, old_state, new_state, changed_at) VALUES
((SELECT device_id FROM Devices WHERE name='Гостиная - Свет'), 'OFF', 'ON', now() - INTERVAL '5 hours'),
((SELECT device_id FROM Devices WHERE name='Гостиная - Кондиционер'), 'OFF', 'ON', now() - INTERVAL '4 hours 50 minutes'),
((SELECT device_id FROM Devices WHERE name='Спальня - Кондиционер'), 'OFF', 'ON', now() - INTERVAL '4 hours 30 minutes'),
((SELECT device_id FROM Devices WHERE name='Кухня - Чайник'), 'OFF', 'ON', now() - INTERVAL '4 hours'),
((SELECT device_id FROM Devices WHERE name='Кухня - Чайник'), 'ON', 'OFF', now() - INTERVAL '3 hours 55 minutes'),
((SELECT device_id FROM Devices WHERE name='Прихожая - Замок двери'), 'LOCKED', 'UNLOCKED', now() - INTERVAL '3 hours'),
((SELECT device_id FROM Devices WHERE name='Прихожая - Замок двери'), 'UNLOCKED', 'LOCKED', now() - INTERVAL '2 hours 55 minutes'),
((SELECT device_id FROM Devices WHERE name='Гостиная - Телевизор'), 'OFF', 'ON', now() - INTERVAL '2 hours'),
((SELECT device_id FROM Devices WHERE name='Ванная - Теплый пол'), 'OFF', 'ON', now() - INTERVAL '1 hour 30 minutes'),
((SELECT device_id FROM Devices WHERE name='Кухня - Духовка'), 'OFF', 'ON', now() - INTERVAL '1 hour'),
((SELECT device_id FROM Devices WHERE name='Кухня - Духовка'), 'ON', 'OFF', now() - INTERVAL '30 minutes'),
((SELECT device_id FROM Devices WHERE name='Балкон - Шторы'), 'CLOSED', 'OPEN', now() - INTERVAL '10 minutes');

-- 5.8 SensorHistory (15 строк)
INSERT INTO SensorHistory (sensor_id, value, recorded_at) VALUES
((SELECT sensor_id FROM Sensors WHERE name='Датчик температуры - Гостиная'), 23.5, now() - INTERVAL '5 hours'),
((SELECT sensor_id FROM Sensors WHERE name='Датчик температуры - Гостиная'), 24.1, now() - INTERVAL '4 hours'),
((SELECT sensor_id FROM Sensors WHERE name='Датчик температуры - Гостиная'), 26.3, now() - INTERVAL '3 hours'),
((SELECT sensor_id FROM Sensors WHERE name='Датчик влажности - Гостиная'), 45.0, now() - INTERVAL '5 hours'),
((SELECT sensor_id FROM Sensors WHERE name='Датчик влажности - Гостиная'), 47.2, now() - INTERVAL '3 hours'),
((SELECT sensor_id FROM Sensors WHERE name='Датчик температуры - Спальня'), 21.0, now() - INTERVAL '4 hours'),
((SELECT sensor_id FROM Sensors WHERE name='Датчик температуры - Спальня'), 22.4, now() - INTERVAL '2 hours'),
((SELECT sensor_id FROM Sensors WHERE name='Датчик газа - Кухня'), 0.02, now() - INTERVAL '1 hour'),
((SELECT sensor_id FROM Sensors WHERE name='Датчик дыма - Кухня'), 1.0, now() - INTERVAL '55 minutes'),
((SELECT sensor_id FROM Sensors WHERE name='Датчик температуры - Холодильник'), 4.2, now() - INTERVAL '3 hours'),
((SELECT sensor_id FROM Sensors WHERE name='Датчик протечки - Посудомойка'), 0.0, now() - INTERVAL '2 hours'),
((SELECT sensor_id FROM Sensors WHERE name='Датчик влажности - Ванная'), 65.0, now() - INTERVAL '1 hour 30 minutes'),
((SELECT sensor_id FROM Sensors WHERE name='Датчик температуры - Ванная'), 26.5, now() - INTERVAL '1 hour'),
((SELECT sensor_id FROM Sensors WHERE name='Датчик температуры - Балкон'), 12.0, now() - INTERVAL '20 minutes'),
((SELECT sensor_id FROM Sensors WHERE name='Датчик освещенности - Балкон'), 350.0, now() - INTERVAL '10 minutes');

-- 5.9 Events (12 строк, привязаны к правилам и устройствам)
INSERT INTO Events (rule_id, device_id, description, event_time) VALUES
((SELECT rule_id FROM AutomationRules WHERE name='Авто-отключение кондиционера'), (SELECT device_id FROM Devices WHERE name='Гостиная - Кондиционер'), 'Кондиционер выключен: температура превысила 25C', now() - INTERVAL '3 hours'),
((SELECT rule_id FROM AutomationRules WHERE name='Свет по движению в прихожей'), (SELECT device_id FROM Devices WHERE name='Прихожая - Свет'), 'Свет включен по датчику движения', now() - INTERVAL '2 hours 50 minutes'),
((SELECT rule_id FROM AutomationRules WHERE name='Сирена при дыме на кухне'), (SELECT device_id FROM Devices WHERE name='Прихожая - Сирена'), 'Сирена активирована: обнаружен дым', now() - INTERVAL '55 minutes'),
((SELECT rule_id FROM AutomationRules WHERE name='Закрытие штор ночью'), (SELECT device_id FROM Devices WHERE name='Гостиная - Шторы'), 'Шторы закрыты по расписанию', now() - INTERVAL '2 hours'),
((SELECT rule_id FROM AutomationRules WHERE name='Оповещение о протечке'), (SELECT device_id FROM Devices WHERE name='Кухня - Посудомойка'), 'Обнаружена протечка воды', now() - INTERVAL '1 hour 45 minutes'),
(NULL, (SELECT device_id FROM Devices WHERE name='Кухня - Чайник'), 'Ручное включение чайника пользователем', now() - INTERVAL '4 hours'),
(NULL, (SELECT device_id FROM Devices WHERE name='Гостиная - Телевизор'), 'Ручное включение телевизора', now() - INTERVAL '2 hours'),
((SELECT rule_id FROM AutomationRules WHERE name='Авто-отключение кондиционера'), (SELECT device_id FROM Devices WHERE name='Спальня - Кондиционер'), 'Кондиционер выключен: температура превысила 25C', now() - INTERVAL '1 hour 20 minutes'),
(NULL, (SELECT device_id FROM Devices WHERE name='Ванная - Теплый пол'), 'Теплый пол включен вручную', now() - INTERVAL '1 hour 30 minutes'),
(NULL, (SELECT device_id FROM Devices WHERE name='Кухня - Духовка'), 'Духовка включена вручную', now() - INTERVAL '1 hour'),
((SELECT rule_id FROM AutomationRules WHERE name='Свет по движению в прихожей'), (SELECT device_id FROM Devices WHERE name='Спальня - Свет'), 'Свет включен по датчику движения', now() - INTERVAL '30 minutes'),
(NULL, (SELECT device_id FROM Devices WHERE name='Балкон - Шторы'), 'Шторы открыты вручную', now() - INTERVAL '10 minutes');

-- 5.10 Logs (12 строк системных логов)
INSERT INTO Logs (level, source, message, logged_at) VALUES
('INFO', 'Interpreter', 'DSL-скрипт успешно загружен', now() - INTERVAL '6 hours'),
('INFO', 'DB', 'Подключение к PostgreSQL установлено', now() - INTERVAL '5 hours 55 minutes'),
('INFO', 'RuleEngine', 'Правило "Авто-отключение кондиционера" активировано', now() - INTERVAL '3 hours'),
('WARNING', 'SensorService', 'Задержка получения данных с датчика температуры (Гостиная)', now() - INTERVAL '2 hours 45 minutes'),
('INFO', 'RuleEngine', 'Правило "Свет по движению в прихожей" активировано', now() - INTERVAL '2 hours 50 minutes'),
('ERROR', 'DeviceService', 'Не удалось получить статус устройства: Кухня - Посудомойка', now() - INTERVAL '2 hours 10 minutes'),
('WARNING', 'SensorService', 'Обнаружена протечка воды, отправлено уведомление', now() - INTERVAL '1 hour 45 minutes'),
('INFO', 'API', 'Запрос на включение устройства: Кухня - Духовка', now() - INTERVAL '1 hour'),
('INFO', 'RuleEngine', 'Правило "Сирена при дыме на кухне" активировано', now() - INTERVAL '55 minutes'),
('ERROR', 'Interpreter', 'Синтаксическая ошибка в DSL-скрипте: строка 12', now() - INTERVAL '40 minutes'),
('INFO', 'DeviceService', 'Устройство Балкон - Шторы обновлено', now() - INTERVAL '10 minutes'),
('INFO', 'DB', 'Плановое резервное копирование выполнено', now() - INTERVAL '5 minutes');
