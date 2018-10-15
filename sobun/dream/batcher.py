# Create the db scheame

import sqlite3


def create_schema(dbconn):
    SCHEMA = """
    CREATE TABLE IF NOT EXISTS measurements(
        batch_id integer,
        timestamp integer,
        tag_id text,
        measurements text,
        hci integer,
        rssi integer,
        synced boolean
    )

    """

    dbconn.execute(SCHEMA)
    dbconn.commit()


def insert(packet, cursor=None):
    sql = """
        INSERT OR IGNORE INTO measurements
        (
            batch_id,
            tag_id,
            timestamp,
            payload,
            synced
        )
        VALUES
        (
            :batch_id,
            :tag_id,
            :timestamp,
            :payload,
            :synced
        )
    """
    cursor.execute(sql, packet)


USAGE = """
Usage: dream.batcher  [--reset]

Options:
    --reset     Reset the datebase
    -h --help   Show this screen.
"""

if __name__ == "__main__":
    from docopt import docopt

    args = docopt(USAGE)

    if args['--reset']:
        dbconn = sqlite3.connect('measurements.db')

        dbconn.execute('DROP TABLE measurements')
        dbconn.commit()

        create_schema(dbconn)
    else:
        dbconn = sqlite3.connect('measurements.db')
        payload = {
                "batch_id": 1,
                "tag_id": "abc",
                "timestamp": 123,
                "payload": 'abcdef',
                "synced": False
                }
        cursor = dbconn.cursor()
        insert(payload, cursor=cursor)
        conn.commit()
