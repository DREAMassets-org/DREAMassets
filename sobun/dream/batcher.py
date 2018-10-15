# Create the db scheame

import sqlite3


conn = sqlite3.connect('measurements.db')

def create_schema():
    SCHEMA = """
    CREATE TABLE IF NOT EXISTS measurements(
        batch_id integer,
        tag_id text,
        timestamp integer,
        payload text,
        synced boolean,
        primary key (tag_id, timestamp)
    )

    """

    conn.execute(SCHEMA)
    conn.commit()
