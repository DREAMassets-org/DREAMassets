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


def insert(row, cursor):
    sql = """
        INSERT OR IGNORE INTO measurements
        (
            batch_id,
            timestamp,
            tag_id,
            measurements,
            hci,
            rssi,
            synced
        )
        VALUES
        (
            :batch_id,
            :timestamp,
            :tag_id,
            :measurements,
            :hci,
            :rssi,
            :synced
        )
    """
    cursor.execute(sql, row)


USAGE = """
Usage: dream.batcher  [--reset]

Options:
    --reset     Reset the datebase
    -h --help   Show this screen.
"""

if __name__ == "__main__":
    from docopt import docopt

    args = docopt(USAGE)

    dbconn = sqlite3.connect('measurements.db')

    if args['--reset']:
        dbconn.execute('DROP TABLE measurements')
        dbconn.commit()
        create_schema(dbconn)
    else:
        row = {
                "batch_id": 1,
                "timestamp": 123,
                "tag_id": "abc",
                "measurements": 'abcdef',
                "rssi": -54,
                "hci": 0,
                "synced": False
                }
        cursor = dbconn.cursor()
        insert(row, cursor=cursor)
        dbconn.commit()
