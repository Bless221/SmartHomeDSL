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

            string sensorId = match.Groups["sensor"].Value.ToLower();
            double threshold = double.Parse(match.Groups["threshold"].Value, System.Globalization.CultureInfo.InvariantCulture);
            string deviceId = match.Groups["device"].Value.ToLower();
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
                Console.WriteLine($"[ERROR] Датчик не найден: {sensorId}");
                return;
            }

            Console.WriteLine($"[LOG] Датчик '{sensorId}' -> Текущее значение: {lastValue:F2}");
            Console.WriteLine($"[LOG] Пороговое значение: {threshold:F2}");

            if (lastValue.Value > threshold)
            {
                Console.WriteLine($"[LOG] Условие выполнено: {lastValue:F2} > {threshold}");
                UpdateDeviceState(connection, deviceId, targetState);
                InsertDeviceHistory(connection, deviceId, targetState, lastValue.Value, sensorId, threshold);
                Console.WriteLine($"[SUCCESS] Устройство '{deviceId}' переведено в состояние {(targetState ? "ON" : "OFF")}");
            }
            else
            {
                Console.WriteLine($"[LOG] Условие НЕ выполнено: {lastValue:F2} <= {threshold}");
                Console.WriteLine($"[INFO] Действие не требуется");
            }
        }

        private static double? GetLastSensorValue(NpgsqlConnection connection, string sensorId)
        {
            const string sql = @"
                SELECT ""value""
                FROM ""sensorhistory""
                WHERE ""sensorid"" = @sensorId
                ORDER BY ""timestamp"" DESC
                LIMIT 1;";

            using var cmd = new NpgsqlCommand(sql, connection);
            cmd.Parameters.AddWithValue("sensorId", sensorId);

            var result = cmd.ExecuteScalar();
            return result == null || result == DBNull.Value ? (double?)null : Convert.ToDouble(result);
        }

        private static void UpdateDeviceState(NpgsqlConnection connection, string deviceId, bool isActive)
        {
            const string sql = @"
                UPDATE ""devices""
                SET ""is_active"" = @isActive
                WHERE ""deviceid"" = @deviceId;";

            using var cmd = new NpgsqlCommand(sql, connection);
            cmd.Parameters.AddWithValue("isActive", isActive);
            cmd.Parameters.AddWithValue("deviceId", deviceId);
            cmd.ExecuteNonQuery();
        }

        private static void InsertDeviceHistory(NpgsqlConnection connection, string deviceId, bool isActive, double sensorValue, string sensorId, double threshold)
        {
            const string sql = @"
                INSERT INTO ""devicestatehistory"" (""deviceid"", ""isactive"", ""changedat"", ""reason"")
                VALUES (@deviceId, @isActive, @changedAt, @reason);";

            string reason = $"Sensor {sensorId} value {sensorValue:F2} exceeded threshold {threshold:F2}";

            using var cmd = new NpgsqlCommand(sql, connection);
            cmd.Parameters.AddWithValue("deviceId", deviceId);
            cmd.Parameters.AddWithValue("isActive", isActive);
            cmd.Parameters.AddWithValue("changedAt", DateTime.UtcNow);
            cmd.Parameters.AddWithValue("reason", reason);
            cmd.ExecuteNonQuery();
        }
    }
}
