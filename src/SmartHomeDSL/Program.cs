using System;
using System.Text.RegularExpressions;
using Npgsql;

namespace SmartHomeDSL
{
    class Program
    {
        private static readonly string ConnectionString = BuildConnectionString();

private static string BuildConnectionString()
{
    string password = Environment.GetEnvironmentVariable("SMARTHOME_DB_PASSWORD");
    if (string.IsNullOrEmpty(password))
    {
        throw new InvalidOperationException(
            "Environment variable SMARTHOME_DB_PASSWORD is not set. " +
            "Please set it before running the application.");
    }

    return $"Host=localhost;Database=SmartHomeDB;Username=postgres;Password={password};";
}

        private static readonly Regex DslPattern = new Regex(
            @"^IF\s+(?<sensor>\w+)\s*>\s*(?<threshold>[\d.]+)\s+THEN\s+SET\s+(?<device>\w+)\s*=\s*(?<state>ON|OFF)$",
            RegexOptions.IgnoreCase | RegexOptions.Compiled);

        static void Main(string[] args)
        {
            Console.WriteLine("SmartHomeDSL Interpreter");
            Console.WriteLine("Пример: IF Sensor_Temperature > 25 THEN SET Device_Light = ON  или  IF 1 > 25 THEN SET 2 = ON");
            string input = Console.ReadLine();

            if (string.IsNullOrWhiteSpace(input))
            {
                Console.WriteLine("Пустая команда.");
                return;
            }

            var match = DslPattern.Match(input.Trim());
            if (!match.Success)
            {
                Console.WriteLine("Ошибка: команда не соответствует синтаксису DSL.");
                return;
            }

            string sensorRaw = match.Groups["sensor"].Value.ToLower();
            double threshold = double.Parse(match.Groups["threshold"].Value, System.Globalization.CultureInfo.InvariantCulture);
            string deviceRaw = match.Groups["device"].Value.ToLower();
            bool targetState = string.Equals(match.Groups["state"].Value, "ON", StringComparison.OrdinalIgnoreCase);

            try
            {
                ExecuteRule(sensorRaw, threshold, deviceRaw, targetState);
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Ошибка выполнения: {ex.Message}");
            }
        }

        private static void ExecuteRule(string sensorRaw, double threshold, string deviceRaw, bool targetState)
        {
            using var connection = new NpgsqlConnection(ConnectionString);
            connection.Open();

            int? sensorId = ResolveSensorId(connection, sensorRaw);
            if (sensorId == null)
            {
                Console.WriteLine($"[ERROR] Датчик не найден: {sensorRaw}");
                return;
            }

            double? lastValue = GetLastSensorValue(connection, sensorId.Value);
            if (lastValue == null)
            {
                Console.WriteLine($"[ERROR] Нет данных в sensorhistory для sensor_id={sensorId}");
                return;
            }

            Console.WriteLine($"[LOG] Датчик '{sensorRaw}' (sensor_id={sensorId}) -> значение: {lastValue:F2}");
            Console.WriteLine($"[LOG] Порог: {threshold:F2}");

            if (lastValue.Value > threshold)
            {
                Console.WriteLine($"[LOG] Условие выполнено: {lastValue:F2} > {threshold}");

                int? deviceId = ResolveDeviceId(connection, deviceRaw);
                if (deviceId == null)
                {
                    Console.WriteLine($"[ERROR] Устройство не найдено: {deviceRaw}");
                    return;
                }

                string oldState = GetCurrentDeviceState(connection, deviceId.Value);
                string newState = targetState ? "ON" : "OFF";

                UpdateDeviceState(connection, deviceId.Value, newState);
                InsertDeviceHistory(connection, deviceId.Value, oldState, newState);

                Console.WriteLine($"[SUCCESS] Устройство '{deviceRaw}' (device_id={deviceId}) переведено: {oldState} -> {newState}");
            }
            else
            {
                Console.WriteLine($"[LOG] Условие НЕ выполнено: {lastValue:F2} <= {threshold}");
                Console.WriteLine("[INFO] Действие не требуется");
            }
        }

        private static string StripPrefix(string raw, string prefix)
        {
            return raw.StartsWith(prefix + "_", StringComparison.OrdinalIgnoreCase)
                ? raw.Substring(prefix.Length + 1)
                : raw;
        }

        private static int? ResolveSensorId(NpgsqlConnection connection, string sensorRaw)
        {
            if (int.TryParse(sensorRaw, out int directId))
                return SensorExists(connection, directId) ? directId : (int?)null;

            string typeName = StripPrefix(sensorRaw, "sensor");

            const string sql = @"
                select s.sensor_id
                from sensors s
                join sensortypes st on s.sensor_type_id = st.sensor_type_id
                where lower(st.name) = lower(@type_name)
                order by s.updated_at desc
                limit 1;";

            using var cmd = new NpgsqlCommand(sql, connection);
            cmd.Parameters.AddWithValue("type_name", typeName);

            var result = cmd.ExecuteScalar();
            return result == null || result == DBNull.Value ? (int?)null : Convert.ToInt32(result);
        }

        private static bool SensorExists(NpgsqlConnection connection, int sensorId)
        {
            const string sql = "select 1 from sensors where sensor_id = @sensor_id limit 1;";
            using var cmd = new NpgsqlCommand(sql, connection);
            cmd.Parameters.AddWithValue("sensor_id", sensorId);
            return cmd.ExecuteScalar() != null;
        }

        private static double? GetLastSensorValue(NpgsqlConnection connection, int sensorId)
        {
            const string sql = @"
                select value
                from sensorhistory
                where sensor_id = @sensor_id
                order by recorded_at desc
                limit 1;";

            using var cmd = new NpgsqlCommand(sql, connection);
            cmd.Parameters.AddWithValue("sensor_id", sensorId);

            var result = cmd.ExecuteScalar();
            return result == null || result == DBNull.Value ? (double?)null : Convert.ToDouble(result);
        }

        private static int? ResolveDeviceId(NpgsqlConnection connection, string deviceRaw)
        {
            if (int.TryParse(deviceRaw, out int directId))
                return DeviceExists(connection, directId) ? directId : (int?)null;

            string typeName = StripPrefix(deviceRaw, "device");

            const string sql = @"
                select d.device_id
                from devices d
                join devicetypes dt on d.device_type_id = dt.device_type_id
                where lower(dt.name) = lower(@type_name)
                order by d.created_at desc
                limit 1;";

            using var cmd = new NpgsqlCommand(sql, connection);
            cmd.Parameters.AddWithValue("type_name", typeName);

            var result = cmd.ExecuteScalar();
            return result == null || result == DBNull.Value ? (int?)null : Convert.ToInt32(result);
        }

        private static bool DeviceExists(NpgsqlConnection connection, int deviceId)
        {
            const string sql = "select 1 from devices where device_id = @device_id limit 1;";
            using var cmd = new NpgsqlCommand(sql, connection);
            cmd.Parameters.AddWithValue("device_id", deviceId);
            return cmd.ExecuteScalar() != null;
        }

        private static string GetCurrentDeviceState(NpgsqlConnection connection, int deviceId)
        {
            const string sql = "select state from devices where device_id = @device_id limit 1;";
            using var cmd = new NpgsqlCommand(sql, connection);
            cmd.Parameters.AddWithValue("device_id", deviceId);
            var result = cmd.ExecuteScalar();
            return result == null || result == DBNull.Value ? "OFF" : result.ToString();
        }

        private static void UpdateDeviceState(NpgsqlConnection connection, int deviceId, string newState)
        {
            const string sql = @"
                update devices
                set state = @new_state
                where device_id = @device_id;";

            using var cmd = new NpgsqlCommand(sql, connection);
            cmd.Parameters.AddWithValue("new_state", newState);
            cmd.Parameters.AddWithValue("device_id", deviceId);
            cmd.ExecuteNonQuery();
        }

        private static void InsertDeviceHistory(NpgsqlConnection connection, int deviceId, string oldState, string newState)
        {
            const string sql = @"
                insert into devicestatehistory (device_id, old_state, new_state, changed_at)
                values (@device_id, @old_state, @new_state, @changed_at);";

            using var cmd = new NpgsqlCommand(sql, connection);
            cmd.Parameters.AddWithValue("device_id", deviceId);
            cmd.Parameters.AddWithValue("old_state", oldState);
            cmd.Parameters.AddWithValue("new_state", newState);
            cmd.Parameters.AddWithValue("changed_at", DateTime.UtcNow);
            cmd.ExecuteNonQuery();
        }
    }
}
