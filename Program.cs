using System;
using System.Text.RegularExpressions;
using Npgsql;

namespace SmartHomeDSL
{
    class Program
    {
        private const string ConnectionString =
            "Host=localhost;Database=SmartHomeDB;Username=postgres;Password=[2201];";

        // Пример: IF Sensor_1 > 25.0 THEN SET Device_2 = ON
        private static readonly Regex DslPattern = new Regex(
            @"^IF\s+(?<sensor>\w+)\s*>\s*(?<threshold>[\d.]+)\s+THEN\s+SET\s+(?<device>\w+)\s*=\s*(?<state>ON|OFF)$",
            RegexOptions.IgnoreCase | RegexOptions.Compiled);

        static void Main(string[] args)
        {
            Console.WriteLine("SmartHomeDSL Interpreter");
            Console.WriteLine("Введите команду DSL (например: IF Sensor_1 > 25.0 THEN SET Device_2 = ON):");
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

            string sensorId = match.Groups["sensor"].Value;
            double threshold = double.Parse(match.Groups["threshold"].Value, System.Globalization.CultureInfo.InvariantCulture);
            string deviceId = match.Groups["device"].Value;
            bool targetState = string.Equals(match.Groups["state"].Value, "ON", StringComparison.OrdinalIgnoreCase);

            try
            {
                ExecuteRule(sensorId, threshold, deviceId, targetState);
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Ошибка выполнения: {ex.Message}");
            }
        }

        private static void ExecuteRule(string sensorId, double threshold, string deviceId, bool targetState)
        {
            using var connection = new NpgsqlConnection(ConnectionString);
            connection.Open();

            double? lastValue = GetLastSensorValue(connection, sensorId);
            if (lastValue == null)
            {
                Console.WriteLine($"Нет данных для датчика {sensorId}.");
                return;
            }

            Console.WriteLine($"Последнее значение {sensorId}: {lastValue}");

            if (lastValue.Value > threshold)
            {
                UpdateDeviceState(connection, deviceId, targetState);
                InsertDeviceHistory(connection, deviceId, targetState, lastValue.Value, sensorId, threshold);
                Console.WriteLine($"Устройство {deviceId} переведено в состояние {(targetState ? "ON" : "OFF")}.");
            }
            else
            {
                Console.WriteLine("Условие не выполнено, действие не требуется.");
            }
        }

        private static double? GetLastSensorValue(NpgsqlConnection connection, string sensorId)
        {
            const string sql = @"
                SELECT ""Value""
                FROM ""SensorHistory""
                WHERE ""SensorId"" = @sensorId
                ORDER BY ""Timestamp"" DESC
                LIMIT 1;";

            using var cmd = new NpgsqlCommand(sql, connection);
            cmd.Parameters.AddWithValue("sensorId", sensorId);

            var result = cmd.ExecuteScalar();
            return result == null || result == DBNull.Value ? (double?)null : Convert.ToDouble(result);
        }

        private static void UpdateDeviceState(NpgsqlConnection connection, string deviceId, bool isActive)
        {
            const string sql = @"
                UPDATE ""Devices""
                SET is_active = @isActive
                WHERE ""DeviceId"" = @deviceId;";

            using var cmd = new NpgsqlCommand(sql, connection);
            cmd.Parameters.AddWithValue("isActive", isActive);
            cmd.Parameters.AddWithValue("deviceId", deviceId);
            cmd.ExecuteNonQuery();
        }

        private static void InsertDeviceHistory(NpgsqlConnection connection, string deviceId, bool isActive, double sensorValue, string sensorId, double threshold)
        {
            const string sql = @"
                INSERT INTO ""DeviceStateHistory"" (""DeviceId"", ""IsActive"", ""ChangedAt"", ""Reason"")
                VALUES (@deviceId, @isActive, @changedAt, @reason);";

            string reason = $"Sensor {sensorId} value {sensorValue} exceeded threshold {threshold}";

            using var cmd = new NpgsqlCommand(sql, connection);
            cmd.Parameters.AddWithValue("deviceId", deviceId);
            cmd.Parameters.AddWithValue("isActive", isActive);
            cmd.Parameters.AddWithValue("changedAt", DateTime.UtcNow);
            cmd.Parameters.AddWithValue("reason", reason);
            cmd.ExecuteNonQuery();
        }
    }
}
