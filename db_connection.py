"""Database connection module for SmartHome ETL pipelines.

Provides utilities to connect to PostgreSQL database with credentials
from environment variables for security best practices.

Usage example:
    from db_connection import SmartHomeDBConnection

    with SmartHomeDBConnection() as conn:
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM sensors")
        rows = cursor.fetchall()
"""

import os
import psycopg2
from psycopg2.extras import RealDictCursor
from contextlib import contextmanager
from typing import Optional, Dict, Any


class SmartHomeDBConnection:
    """PostgreSQL connection wrapper for SmartHome database with environment-based credentials."""

    # Environment variable keys
    ENV_PASSWORD_KEY = "SMARTHOME_DB_PASSWORD"
    ENV_HOST_KEY = "SMARTHOME_DB_HOST"
    ENV_PORT_KEY = "SMARTHOME_DB_PORT"
    ENV_DATABASE_KEY = "SMARTHOME_DB_NAME"
    ENV_USER_KEY = "SMARTHOME_DB_USER"

    # Default values (matching C# configuration)
    DEFAULT_HOST = "localhost"
    DEFAULT_PORT = 5432
    DEFAULT_DATABASE = "SmartHomeDB"
    DEFAULT_USER = "postgres"

    def __init__(self):
        """Initialize connection parameters from environment variables."""
        self.host = os.getenv(self.ENV_HOST_KEY, self.DEFAULT_HOST)
        self.port = int(os.getenv(self.ENV_PORT_KEY, self.DEFAULT_PORT))
        self.database = os.getenv(self.ENV_DATABASE_KEY, self.DEFAULT_DATABASE)
        self.user = os.getenv(self.ENV_USER_KEY, self.DEFAULT_USER)
        self.password = os.getenv(self.ENV_PASSWORD_KEY)

        if not self.password:
            raise ValueError(
                f"Database password not found. "
                f"Set environment variable: {self.ENV_PASSWORD_KEY}"
            )

        self.connection = None

    def connect(self) -> psycopg2.extensions.connection:
        """Establish connection to PostgreSQL database.

        Returns:
            psycopg2 connection object

        Raises:
            psycopg2.Error: If connection fails
        """
        try:
            self.connection = psycopg2.connect(
                host=self.host,
                port=self.port,
                database=self.database,
                user=self.user,
                password=self.password,
                connect_timeout=5
            )
            print(f"✓ Connected to {self.user}@{self.host}:{self.port}/{self.database}")
            return self.connection
        except psycopg2.Error as e:
            raise ConnectionError(f"Failed to connect to database: {e}")

    def disconnect(self):
        """Close database connection."""
        if self.connection:
            self.connection.close()
            print("✓ Database connection closed")

    def __enter__(self):
        """Context manager entry - establishes connection."""
        return self.connect()

    def __exit__(self, exc_type, exc_val, exc_tb):
        """Context manager exit - closes connection."""
        self.disconnect()

    @staticmethod
    def get_dict_cursor(connection: psycopg2.extensions.connection):
        """Get cursor that returns results as dictionaries instead of tuples.

        Args:
            connection: psycopg2 connection object

        Returns:
            RealDictCursor object
        """
        return connection.cursor(cursor_factory=RealDictCursor)


def execute_query(query: str, params: Optional[tuple] = None) -> list:
    """Execute SELECT query and return results.

    Args:
        query: SQL SELECT query
        params: Query parameters tuple (for parameterized queries)

    Returns:
        List of dictionaries with query results

    Example:
        results = execute_query(
            "SELECT * FROM sensors WHERE sensor_type_id = %s",
            (1,)
        )
    """
    with SmartHomeDBConnection() as conn:
        cursor = SmartHomeDBConnection.get_dict_cursor(conn)
        cursor.execute(query, params or ())
        results = cursor.fetchall()
        cursor.close()
        return results


def execute_update(query: str, params: Optional[tuple] = None) -> int:
    """Execute INSERT, UPDATE, or DELETE query.

    Args:
        query: SQL DML query
        params: Query parameters tuple

    Returns:
        Number of affected rows

    Example:
        affected = execute_update(
            "UPDATE devices SET state = %s WHERE device_id = %s",
            ("ON", 1)
        )
    """
    with SmartHomeDBConnection() as conn:
        cursor = conn.cursor()
        cursor.execute(query, params or ())
        conn.commit()
        affected_rows = cursor.rowcount
        cursor.close()
        return affected_rows


def fetch_sensor_value(sensor_id: int) -> Optional[float]:
    """Get the latest recorded value for a sensor.

    Args:
        sensor_id: ID of the sensor

    Returns:
        Latest sensor value or None if no data exists
    """
    query = """
        SELECT value FROM sensorhistory
        WHERE sensor_id = %s
        ORDER BY recorded_at DESC
        LIMIT 1;
    """
    results = execute_query(query, (sensor_id,))
    return results[0]['value'] if results else None


def get_device_state(device_id: int) -> Optional[str]:
    """Get current state of a device.

    Args:
        device_id: ID of the device

    Returns:
        Device state (ON/OFF) or None if device not found
    """
    query = "SELECT state FROM devices WHERE device_id = %s LIMIT 1;"
    results = execute_query(query, (device_id,))
    return results[0]['state'] if results else None


def update_device_state(device_id: int, new_state: str) -> bool:
    """Update device state and log to history.

    Args:
        device_id: ID of the device
        new_state: New state (ON/OFF)

    Returns:
        True if update was successful
    """
    try:
        # Get current state
        old_state = get_device_state(device_id) or "OFF"

        # Update device state
        update_query = """
            UPDATE devices SET state = %s WHERE device_id = %s;
        """
        execute_update(update_query, (new_state, device_id))

        # Log to history
        history_query = """
            INSERT INTO devicestatehistory (device_id, old_state, new_state, changed_at)
            VALUES (%s, %s, %s, NOW());
        """
        execute_update(history_query, (device_id, old_state, new_state))

        return True
    except Exception as e:
        print(f"Error updating device state: {e}")
        return False


if __name__ == "__main__":
    # Test connection
    try:
        db = SmartHomeDBConnection()
        conn = db.connect()
        print("Database connection test: SUCCESS")

        # Test query
        cursor = SmartHomeDBConnection.get_dict_cursor(conn)
        cursor.execute("SELECT COUNT(*) as count FROM sensors;")
        result = cursor.fetchone()
        print(f"Number of sensors: {result['count']}")

        db.disconnect()
    except Exception as e:
        print(f"Database connection test: FAILED - {e}")
