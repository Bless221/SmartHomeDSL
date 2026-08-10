# SmartHomeDSL — база данных «Умный дом»
 
Проект: DSL (предметно-ориентированный язык) для управления умным домом на основе парадигмы потоков данных (Dataflow). Данный раздел — реляционная схема хранения состояния устройств, датчиков, правил автоматизации и истории событий.

## Стек

- СУБД: **PostgreSQL**
- Backend: **C# / .NET 8** (Npgsql)
- Файл инициализации БД: [`init.sql`](./init.sql)

## Помещения (6)

Прихожая, Гостиная, Спальня, Кухня, Ванная, Балкон.

## Состав базы

### Справочники
| Таблица | Назначение |
|---|---|
| `Rooms` | Помещения дома (6 шт.) |
| `DeviceTypes` | Типы устройств: Light, Climate, TV, Socket, Curtain, DoorLock, AirPurifier, Hood, Refrigerator, Oven, Dishwasher, Kettle, FloorHeating, Fan, Siren |
| `SensorTypes` | Типы датчиков: Temperature, Humidity, Motion, Door, Smoke, Gas, CO2, Leak, LightLevel |

### Основные сущности
| Таблица | Назначение |
|---|---|
| `Devices` | Устройства (26 шт.), привязаны к комнате и типу |
| `Sensors` | Датчики (18 шт.), привязаны к устройству и типу |
| `AutomationRules` | Правила автоматизации DSL (условие → действие) |

### История и Big Data (BIGINT PK, TIMESTAMPTZ, индексы по времени)
| Таблица | Назначение |
|---|---|
| `DeviceStateHistory` | История изменения состояний устройств |
| `SensorHistory` | История показаний датчиков |
| `Events` | События автоматизации (связаны с правилом и/или устройством) |
| `Logs` | Системные логи приложения (независимы от Events) |

## Связи

1. `Rooms` (1:N) `Devices`
2. `DeviceTypes` (1:N) `Devices`
3. `SensorTypes` (1:N) `Sensors`
4. `Devices` (1:N) `Sensors`
5. `Devices` (1:N) `DeviceStateHistory`
6. `Sensors` (1:N) `SensorHistory`
7. `AutomationRules` (1:N) `Events`
8. `Devices` (1:N) `Events`
9. `Logs` — независимая таблица системных логов, `Events` — таблица событий автоматизации

## ER-диаграмма

```mermaid
erDiagram
    ROOMS ||--o{ DEVICES : contains
    DEVICETYPES ||--o{ DEVICES : classifies
    DEVICES ||--o{ SENSORS : has
    SENSORTYPES ||--o{ SENSORS : classifies
    DEVICES ||--o{ DEVICESTATEHISTORY : logs
    SENSORS ||--o{ SENSORHISTORY : logs
    DEVICES ||--o{ EVENTS : triggers
    AUTOMATIONRULES ||--o{ EVENTS : generates

    ROOMS {
        int room_id PK
        varchar name
    }
    DEVICETYPES {
        int device_type_id PK
        varchar name
    }
    DEVICES {
        int device_id PK
        varchar name
        int device_type_id FK
        int room_id FK
        varchar state
        timestamptz created_at
    }
    SENSORTYPES {
        int sensor_type_id PK
        varchar name
        varchar unit
    }
    SENSORS {
        int sensor_id PK
        varchar name
        int sensor_type_id FK
        int device_id FK
        numeric current_value
        timestamptz updated_at
    }
    DEVICESTATEHISTORY {
        bigint history_id PK
        int device_id FK
        varchar old_state
        varchar new_state
        timestamptz changed_at
    }
    SENSORHISTORY {
        bigint history_id PK
        int sensor_id FK
        numeric value
        timestamptz recorded_at
    }
    AUTOMATIONRULES {
        int rule_id PK
        varchar name
        text condition_expr
        text action_expr
        boolean is_active
        timestamptz created_at
    }
    EVENTS {
        bigint event_id PK
        int automation_rule_id FK
        int device_id FK
        timestamptz event_time
        text description
    }
    LOGS {
        bigint log_id PK
        timestamptz log_time
        varchar level
        varchar source
        text message
    }
```

## Быстрый старт

```bash
psql -U postgres -d SmartHomeDB -f init.sql
```
