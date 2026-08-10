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
    unit            VARCHAR(20)
);

-- =========================================================
-- 2. CORE TABLES
-- =========================================================

CREATE TABLE Devices (
    device_id       SERIAL PRIMARY KEY,
    name            VARCHAR(100) NOT NULL,
    device_type_id  INT NOT NULL REFERENCES DeviceTypes(device_type_id),
    room_id         INT NOT NULL REFERENCES Rooms(room_id),
    state           VARCHAR(20) NOT NULL DEFAULT 'OFF',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE Sensors (
    sensor_id       SERIAL PRIMARY KEY,
    name            VARCHAR(100) NOT NULL,
    sensor_type_id  INT NOT NULL REFERENCES SensorTypes(sensor_type_id),
    device_id       INT NOT NULL REFERENCES Devices(device_id),
    current_value   NUMERIC(10,2),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE AutomationRules (
    rule_id         SERIAL PRIMARY KEY,
    name            VARCHAR(150) NOT NULL,
    condition_expr  TEXT NOT NULL, -- DSL-условие, например: WHEN temperature > 25
    action_expr     TEXT NOT NULL, -- DSL-действие, например: turn_off heater
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- =========================================================
-- 3. BIG DATA / HISTORY TABLES (BIGINT PK + TIMESTAMPTZ)
-- =========================================================

CREATE TABLE DeviceStateHistory (
    history_id  BIGSERIAL PRIMARY KEY,
    device_id   INT NOT NULL REFERENCES Devices(device_id),
    old_state   VARCHAR(20),
    new_state   VARCHAR(20) NOT NULL,
    changed_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE SensorHistory (
    history_id  BIGSERIAL PRIMARY KEY,
    sensor_id   INT NOT NULL REFERENCES Sensors(sensor_id),
    value       NUMERIC(10,2) NOT NULL,
    recorded_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE Events (
    event_id            BIGSERIAL PRIMARY KEY,
    automation_rule_id  INT REFERENCES AutomationRules(rule_id) ON DELETE SET NULL,
    device_id           INT REFERENCES Devices(device_id) ON DELETE SET NULL,
    event_time          TIMESTAMPTZ NOT NULL DEFAULT now(),
    description         TEXT NOT NULL
);

CREATE TABLE Logs (
    log_id      BIGSERIAL PRIMARY KEY,
    log_time    TIMESTAMPTZ NOT NULL DEFAULT now(),
    level       VARCHAR(20) NOT NULL, -- INFO / WARNING / ERROR
    source      VARCHAR(100),
    message     TEXT NOT NULL
);

-- =========================================================
-- 4. INDEXES (Big Data optimization on time columns)
-- =========================================================

CREATE INDEX idx_devicestatehistory_changed_at ON DeviceStateHistory (changed_at);
CREATE INDEX idx_sensorhistory_recorded_at     ON SensorHistory (recorded_at);
CREATE INDEX idx_events_event_time             ON Events (event_time);
CREATE INDEX idx_logs_log_time                 ON Logs (log_time);

-- дополнительные индексы по FK для ускорения выборок по устройствам/датчикам
CREATE INDEX idx_devicestatehistory_device_id ON DeviceStateHistory (device_id);
CREATE INDEX idx_sensorhistory_sensor_id      ON SensorHistory (sensor_id);
CREATE INDEX idx_events_device_id             ON Events (device_id);
CREATE INDEX idx_events_rule_id               ON Events (automation_rule_id);

-- =========================================================
-- 5. SEED DATA: Rooms
-- =========================================================

INSERT INTO Rooms (name) VALUES
('Прихожая'),
('Гостиная'),
('Спальня'),
('Кухня'),
('Ванная'),
('Балкон');

-- =========================================================
-- 6. SEED DATA: DeviceTypes
-- =========================================================

INSERT INTO DeviceTypes (name) VALUES
('Light'), ('Climate'), ('TV'), ('Socket'), ('Curtain'),
('DoorLock'), ('AirPurifier'), ('Hood'), ('Refrigerator'), ('Oven'),
('Dishwasher'), ('Kettle'), ('FloorHeating'), ('Fan'), ('Siren');

-- =========================================================
-- 7. SEED DATA: SensorTypes
-- =========================================================

INSERT INTO SensorTypes (name, unit) VALUES
('Temperature', '°C'),
('Humidity', '%'),
('Motion', 'bool'),
('Door', 'bool'),
('Smoke', 'bool'),
('Gas', 'ppm'),
('CO2', 'ppm'),
('Leak', 'bool'),
('LightLevel', 'lux');

-- =========================================================
-- 8. SEED DATA: Devices (26 шт, распределены по 6 комнатам)
-- =========================================================

-- Прихожая (room_id=1): 3
INSERT INTO Devices (name, device_type_id, room_id, state) VALUES
('Входная лампа',            (SELECT device_type_id FROM DeviceTypes WHERE name='Light'),    1, 'OFF'),
('Умный замок входной двери',(SELECT device_type_id FROM DeviceTypes WHERE name='DoorLock'), 1, 'LOCKED'),
('Сирена охранная',          (SELECT device_type_id FROM DeviceTypes WHERE name='Siren'),    1, 'OFF');

-- Гостиная (room_id=2): 7
INSERT INTO Devices (name, device_type_id, room_id, state) VALUES
('Люстра в гостиной',    (SELECT device_type_id FROM DeviceTypes WHERE name='Light'),       2, 'ON'),
('Телевизор гостиной',   (SELECT device_type_id FROM DeviceTypes WHERE name='TV'),          2, 'OFF'),
('Кондиционер гостиной', (SELECT device_type_id FROM DeviceTypes WHERE name='Climate'),     2, 'ON'),
('Розетка у дивана',     (SELECT device_type_id FROM DeviceTypes WHERE name='Socket'),      2, 'ON'),
('Шторы электронные',    (SELECT device_type_id FROM DeviceTypes WHERE name='Curtain'),     2, 'CLOSED'),
('Вентилятор напольный', (SELECT device_type_id FROM DeviceTypes WHERE name='Fan'),         2, 'OFF'),
('Очиститель воздуха',   (SELECT device_type_id FROM DeviceTypes WHERE name='AirPurifier'), 2, 'ON');

-- Спальня (room_id=3): 5
INSERT INTO Devices (name, device_type_id, room_id, state) VALUES
('Лампа у кровати',    (SELECT device_type_id FROM DeviceTypes WHERE name='Light'),        3, 'OFF'),
('Кондиционер спальни',(SELECT device_type_id FROM DeviceTypes WHERE name='Climate'),      3, 'ON'),
('Шторы блэкаут',      (SELECT device_type_id FROM DeviceTypes WHERE name='Curtain'),      3, 'CLOSED'),
('Теплый пол спальня', (SELECT device_type_id FROM DeviceTypes WHERE name='FloorHeating'), 3, 'ON'),
('Розетка зарядная',   (SELECT device_type_id FROM DeviceTypes WHERE name='Socket'),       3, 'ON');

-- Кухня (room_id=4): 6
INSERT INTO Devices (name, device_type_id, room_id, state) VALUES
('Подсветка кухни',          (SELECT device_type_id FROM DeviceTypes WHERE name='Light'),        4, 'ON'),
('Холодильник',              (SELECT device_type_id FROM DeviceTypes WHERE name='Refrigerator'), 4, 'ON'),
('Духовка встроенная',       (SELECT device_type_id FROM DeviceTypes WHERE name='Oven'),         4, 'OFF'),
('Посудомоечная машина',     (SELECT device_type_id FROM DeviceTypes WHERE name='Dishwasher'),   4, 'OFF'),
('Чайник умный',             (SELECT device_type_id FROM DeviceTypes WHERE name='Kettle'),       4, 'OFF'),
('Вытяжка кухонная',         (SELECT device_type_id FROM DeviceTypes WHERE name='Hood'),         4, 'OFF');

-- Ванная (room_id=5): 3
INSERT INTO Devices (name, device_type_id, room_id, state) VALUES
('Лампа ванной',      (SELECT device_type_id FROM DeviceTypes WHERE name='Light'),        5, 'ON'),
('Теплый пол ванная', (SELECT device_type_id FROM DeviceTypes WHERE name='FloorHeating'), 5, 'ON'),
('Розетка для фена',  (SELECT device_type_id FROM DeviceTypes WHERE name='Socket'),       5, 'OFF');

-- Балкон (room_id=6): 2
INSERT INTO Devices (name, device_type_id, room_id, state) VALUES
('Лампа балкона',        (SELECT device_type_id FROM DeviceTypes WHERE name='Light'),   6, 'OFF'),
('Шторы/жалюзи балкон',  (SELECT device_type_id FROM DeviceTypes WHERE name='Curtain'), 6, 'OPEN');

-- =========================================================
-- 9. SEED DATA: Sensors (18 шт, привязаны к устройствам)
-- =========================================================

INSERT INTO Sensors (name, sensor_type_id, device_id, current_value) VALUES
('Датчик температуры гостиной',   (SELECT sensor_type_id FROM SensorTypes WHERE name='Temperature'), (SELECT device_id FROM Devices WHERE name='Кондиционер гостиной'), 23.5),
('Датчик влажности гостиной',     (SELECT sensor_type_id FROM SensorTypes WHERE name='Humidity'),    (SELECT device_id FROM Devices WHERE name='Кондиционер гостиной'), 45.0),
('Датчик CO2 гостиной',           (SELECT sensor_type_id FROM SensorTypes WHERE name='CO2'),         (SELECT device_id FROM Devices WHERE name='Очиститель воздуха'),   650.0),
('Датчик движения прихожей',      (SELECT sensor_type_id FROM SensorTypes WHERE name='Motion'),      (SELECT device_id FROM Devices WHERE name='Входная лампа'),        0.0),
('Датчик открытия входной двери', (SELECT sensor_type_id FROM SensorTypes WHERE name='Door'),        (SELECT device_id FROM Devices WHERE name='Умный замок входной двери'), 0.0),
('Датчик дыма прихожей',          (SELECT sensor_type_id FROM SensorTypes WHERE name='Smoke'),       (SELECT device_id FROM Devices WHERE name='Сирена охранная'),      0.0),
('Датчик температуры спальни',    (SELECT sensor_type_id FROM SensorTypes WHERE name='Temperature'), (SELECT device_id FROM Devices WHERE name='Кондиционер спальни'),  21.0),
('Датчик влажности спальни',      (SELECT sensor_type_id FROM SensorTypes WHERE name='Humidity'),    (SELECT device_id FROM Devices WHERE name='Кондиционер спальни'),  40.0),
('Датчик освещенности спальни',   (SELECT sensor_type_id FROM SensorTypes WHERE name='LightLevel'),  (SELECT device_id FROM Devices WHERE name='Лампа у кровати'),      120.0),
('Датчик газа кухни',             (SELECT sensor_type_id FROM SensorTypes WHERE name='Gas'),         (SELECT device_id FROM Devices WHERE name='Вытяжка кухонная'),     0.2),
('Датчик дыма кухни',             (SELECT sensor_type_id FROM SensorTypes WHERE name='Smoke'),       (SELECT device_id FROM Devices WHERE name='Духовка встроенная'),   0.0),
('Датчик температуры холодильника',(SELECT sensor_type_id FROM SensorTypes WHERE name='Temperature'),(SELECT device_id FROM Devices WHERE name='Холодильник'),          4.0),
('Датчик утечки воды посудомойки',(SELECT sensor_type_id FROM SensorTypes WHERE name='Leak'),        (SELECT device_id FROM Devices WHERE name='Посудомоечная машина'), 0.0),
('Датчик утечки воды ванной',     (SELECT sensor_type_id FROM SensorTypes WHERE name='Leak'),        (SELECT device_id FROM Devices WHERE name='Розетка для фена'),     0.0),
('Датчик влажности ванной',       (SELECT sensor_type_id FROM SensorTypes WHERE name='Humidity'),    (SELECT device_id FROM Devices WHERE name='Теплый пол ванная'),    65.0),
('Датчик температуры ванной',     (SELECT sensor_type_id FROM SensorTypes WHERE name='Temperature'), (SELECT device_id FROM Devices WHERE name='Теплый пол ванная'),    26.0),
('Датчик освещенности балкона',   (SELECT sensor_type_id FROM SensorTypes WHERE name='LightLevel'),  (SELECT device_id FROM Devices WHERE name='Лампа балкона'),        300.0),
('Датчик температуры балкона',    (SELECT sensor_type_id FROM SensorTypes WHERE name='Temperature'), (SELECT device_id FROM Devices WHERE name='Шторы/жалюзи балкон'),  15.0);

-- =========================================================
-- 10. SEED DATA: AutomationRules (12 шт)
-- =========================================================

INSERT INTO AutomationRules (name, condition_expr, action_expr, is_active) VALUES
('Выключить кондиционер при похолодании',   'WHEN temperature < 20',  'turn_off climate',      TRUE),
('Включить обогрев спальни',                'WHEN temperature < 18',  'turn_on floor_heating', TRUE),
('Проветривание при высоком CO2',           'WHEN co2 > 800',         'turn_on air_purifier',  TRUE),
('Свет при движении в прихожей',            'WHEN motion = true',     'turn_on light',         TRUE),
('Сигнал тревоги при дыме',                 'WHEN smoke = true',      'turn_on siren',         TRUE),
('Закрыть шторы вечером',                   'WHEN time = 21:00',      'close curtain',         TRUE),
('Открыть шторы утром',                     'WHEN time = 07:00',      'open curtain',          TRUE),
('Отключить вытяжку при низком газе',       'WHEN gas < 0.1',         'turn_off hood',         TRUE),
('Уведомление при утечке воды',             'WHEN leak = true',       'notify user',           TRUE),
('Выключить свет ночью',                    'WHEN time = 00:00',      'turn_off light',        TRUE),
('Включить теплый пол в ванной утром',      'WHEN time = 06:30',      'turn_on floor_heating', TRUE),
('Блокировка двери при уходе',              'WHEN mode = away',       'lock doorlock',         FALSE);

-- =========================================================
-- 11. SEED DATA: DeviceStateHistory (15 строк)
-- =========================================================

INSERT INTO DeviceStateHistory (device_id, old_state, new_state, changed_at) VALUES
((SELECT device_id FROM Devices WHERE name='Входная лампа'),            'OFF', 'ON',     now() - interval '10 hours'),
((SELECT device_id FROM Devices WHERE name='Входная лампа'),            'ON',  'OFF',    now() - interval '9 hours'),
((SELECT device_id FROM Devices WHERE name='Люстра в гостиной'),        'OFF', 'ON',     now() - interval '8 hours'),
((SELECT device_id FROM Devices WHERE name='Телевизор гостиной'),       'OFF', 'ON',     now() - interval '7 hours'),
((SELECT device_id FROM Devices WHERE name='Кондиционер гостиной'),     'OFF', 'ON',     now() - interval '6 hours'),
((SELECT device_id FROM Devices WHERE name='Кондиционер спальни'),      'ON',  'OFF',    now() - interval '6 hours'),
((SELECT device_id FROM Devices WHERE name='Шторы блэкаут'),            'OPEN','CLOSED', now() - interval '5 hours'),
((SELECT device_id FROM Devices WHERE name='Теплый пол спальня'),       'OFF', 'ON',     now() - interval '5 hours'),
((SELECT device_id FROM Devices WHERE name='Духовка встроенная'),       'OFF', 'ON',     now() - interval '4 hours'),
((SELECT device_id FROM Devices WHERE name='Посудомоечная машина'),     'OFF', 'ON',     now() - interval '3 hours'),
((SELECT device_id FROM Devices WHERE name='Чайник умный'),             'OFF', 'ON',     now() - interval '2 hours'),
((SELECT device_id FROM Devices WHERE name='Лампа ванной'),             'OFF', 'ON',     now() - interval '2 hours'),
((SELECT device_id FROM Devices WHERE name='Теплый пол ванная'),        'OFF', 'ON',     now() - interval '1 hours'),
((SELECT device_id FROM Devices WHERE name='Лампа балкона'),            'OFF', 'ON',     now() - interval '30 minutes'),
((SELECT device_id FROM Devices WHERE name='Шторы/жалюзи балкон'),      'CLOSED','OPEN', now() - interval '15 minutes');

-- =========================================================
-- 12. SEED DATA: SensorHistory (15 строк)
-- =========================================================

INSERT INTO SensorHistory (sensor_id, value, recorded_at) VALUES
((SELECT sensor_id FROM Sensors WHERE name='Датчик температуры гостиной'),    22.8, now() - interval '10 hours'),
((SELECT sensor_id FROM Sensors WHERE name='Датчик температуры гостиной'),    23.5, now() - interval '5 hours'),
((SELECT sensor_id FROM Sensors WHERE name='Датчик влажности гостиной'),      44.0, now() - interval '9 hours'),
((SELECT sensor_id FROM Sensors WHERE name='Датчик CO2 гостиной'),            720.0, now() - interval '8 hours'),
((SELECT sensor_id FROM Sensors WHERE name='Датчик CO2 гостиной'),            850.0, now() - interval '4 hours'),
((SELECT sensor_id FROM Sensors WHERE name='Датчик движения прихожей'),       1.0,  now() - interval '10 hours'),
((SELECT sensor_id FROM Sensors WHERE name='Датчик открытия входной двери'),  1.0,  now() - interval '10 hours'),
((SELECT sensor_id FROM Sensors WHERE name='Датчик дыма прихожей'),           0.0,  now() - interval '9 hours'),
((SELECT sensor_id FROM Sensors WHERE name='Датчик температуры спальни'),     19.5, now() - interval '7 hours'),
((SELECT sensor_id FROM Sensors WHERE name='Датчик влажности спальни'),       41.0, now() - interval '6 hours'),
((SELECT sensor_id FROM Sensors WHERE name='Датчик газа кухни'),              0.1,  now() - interval '4 hours'),
((SELECT sensor_id FROM Sensors WHERE name='Датчик дыма кухни'),              0.0,  now() - interval '4 hours'),
((SELECT sensor_id FROM Sensors WHERE name='Датчик температуры холодильника'),4.2,  now() - interval '3 hours'),
((SELECT sensor_id FROM Sensors WHERE name='Датчик утечки воды посудомойки'), 0.0,  now() - interval '3 hours'),
((SELECT sensor_id FROM Sensors WHERE name='Датчик освещенности балкона'),    280.0, now() - interval '30 minutes');

-- =========================================================
-- 13. SEED DATA: Events (12 строк)
-- =========================================================

INSERT INTO Events (automation_rule_id, device_id, event_time, description) VALUES
((SELECT rule_id FROM AutomationRules WHERE name='Свет при движении в прихожей'),        (SELECT device_id FROM Devices WHERE name='Входная лампа'),        now() - interval '10 hours', 'Свет включен по датчику движения'),
((SELECT rule_id FROM AutomationRules WHERE name='Выключить кондиционер при похолодании'),(SELECT device_id FROM Devices WHERE name='Кондиционер спальни'),  now() - interval '6 hours',  'Кондиционер выключен: температура ниже нормы'),
((SELECT rule_id FROM AutomationRules WHERE name='Включить обогрев спальни'),             (SELECT device_id FROM Devices WHERE name='Теплый пол спальня'),   now() - interval '5 hours',  'Теплый пол включен по датчику температуры'),
((SELECT rule_id FROM AutomationRules WHERE name='Проветривание при высоком CO2'),        (SELECT device_id FROM Devices WHERE name='Очиститель воздуха'),   now() - interval '4 hours',  'Очиститель включен: уровень CO2 превышен'),
((SELECT rule_id FROM AutomationRules WHERE name='Закрыть шторы вечером'),                (SELECT device_id FROM Devices WHERE name='Шторы блэкаут'),        now() - interval '5 hours',  'Шторы закрыты по расписанию'),
(NULL, (SELECT device_id FROM Devices WHERE name='Духовка встроенная'),                                                                        now() - interval '4 hours',  'Ручное включение духовки пользователем'),
(NULL, (SELECT device_id FROM Devices WHERE name='Посудомоечная машина'),                                                                      now() - interval '3 hours',  'Ручной запуск посудомоечной машины'),
((SELECT rule_id FROM AutomationRules WHERE name='Уведомление при утечке воды'),          (SELECT device_id FROM Devices WHERE name='Посудомоечная машина'), now() - interval '3 hours',  'Проверка датчика утечки: протечек не обнаружено'),
((SELECT rule_id FROM AutomationRules WHERE name='Включить теплый пол в ванной утром'),   (SELECT device_id FROM Devices WHERE name='Теплый пол ванная'),    now() - interval '1 hours',  'Теплый пол включен по расписанию'),
(NULL, (SELECT device_id FROM Devices WHERE name='Лампа балкона'),                                                                             now() - interval '30 minutes','Ручное включение лампы балкона'),
((SELECT rule_id FROM AutomationRules WHERE name='Открыть шторы утром'),                  (SELECT device_id FROM Devices WHERE name='Шторы/жалюзи балкон'),  now() - interval '15 minutes','Шторы балкона открыты по расписанию'),
((SELECT rule_id FROM AutomationRules WHERE name='Отключить вытяжку при низком газе'),    (SELECT device_id FROM Devices WHERE name='Вытяжка кухонная'),     now() - interval '4 hours',  'Вытяжка выключена: уровень газа в норме');

-- =========================================================
-- 14. SEED DATA: Logs (12 строк)
-- =========================================================

INSERT INTO Logs (log_time, level, source, message) VALUES
(now() - interval '10 hours', 'INFO',    'AutomationEngine', 'Правило "Свет при движении в прихожей" сработало успешно'),
(now() - interval '9 hours',  'INFO',    'DeviceManager',    'Устройство "Входная лампа" перешло в состояние OFF'),
(now() - interval '8 hours',  'INFO',    'DeviceManager',    'Устройство "Люстра в гостиной" перешло в состояние ON'),
(now() - interval '7 hours',  'WARNING', 'SensorService',    'Задержка ответа датчика температуры спальни: 2.3с'),
(now() - interval '6 hours',  'INFO',    'AutomationEngine', 'Правило "Выключить кондиционер при похолодании" сработало успешно'),
(now() - interval '5 hours',  'INFO',    'AutomationEngine', 'Правило "Закрыть шторы вечером" сработало успешно'),
(now() - interval '4 hours',  'ERROR',   'SensorService',    'Потеряна связь с датчиком газа кухни на 15 секунд'),
(now() - interval '4 hours',  'INFO',    'AutomationEngine', 'Правило "Проветривание при высоком CO2" сработало успешно'),
(now() - interval '3 hours',  'INFO',    'DeviceManager',    'Устройство "Посудомоечная машина" перешло в состояние ON'),
(now() - interval '2 hours',  'WARNING', 'DeviceManager',    'Устройство "Чайник умный" превысило ожидаемое время работы'),
(now() - interval '1 hours',  'INFO',    'AutomationEngine', 'Правило "Включить теплый пол в ванной утром" сработало успешно'),
(now() - interval '15 minutes','INFO',   'DeviceManager',    'Устройство "Шторы/жалюзи балкон" перешло в состояние OPEN');