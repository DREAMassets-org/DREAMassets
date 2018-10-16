# Create the db scheame

import sqlite3


def dbconnect(name=None):
    if not name:
        name = 'measurements.db'

    conn = sqlite3.connect(name)
    conn.row_factory = sqlite3.Row
    return conn


def create_schema(dbconn):
    SCHEMA = """
    CREATE TABLE IF NOT EXISTS measurements(
        batch_id integer default 0,
        timestamp integer,
        tag_id text,
        measurements text,
        hci integer,
        rssi integer
    )
    """
    dbconn.execute(SCHEMA)

    dbconn.execute("CREATE INDEX IF NOT EXISTS timestamp_idx on measurements (timestamp)")
    dbconn.execute("CREATE INDEX IF NOT EXISTS batched_idx on measurements (batch_id)")
    dbconn.execute("CREATE INDEX IF NOT EXISTS tag_idx on measurements (tag_id)")
    dbconn.commit()


def insert(row, cursor):
    sql = """
        INSERT OR IGNORE INTO measurements
        (
            timestamp,
            tag_id,
            measurements,
            hci,
            rssi
        )
        VALUES
        (
            :timestamp,
            :tag_id,
            :measurements,
            :hci,
            :rssi
        )
    """
    cursor.execute(sql, row)


def create_unique_batch(dbconn, batch_size=20000):
    cursor = dbconn.cursor()
    sql = """
        UPDATE measurements SET batch_id = (SELECT MAX(batch_id)+1 from measurements)
        WHERE batch_id = 0
        ORDER BY timestamp
        LIMIT :batch_size
    """
    cursor.execute(sql, dict(batch_size=batch_size))
    print('batch created')


def publish_batch(dbconn, batch_id):
    from dream.gpub import send_batch

    sql = """
        SELECT
            timestamp,
            tag_id,
            measurements,
            hci,
            rssi
        FROM measurements
        WHERE batch_id = :batch_id
        ORDER BY timestamp
    """
    cursor = dbconn.cursor()
    rows = cursor.execute(sql, dict(batch_id=batch_id))
    lines = []
    for row in rows:
        lines.append(",".join(map(str, row)))
    payload = "\n".join(lines)

    msg_id = send_batch(payload)
    if msg_id:
        dbconn.execute("DELETE FROM measurements WHERE batch_id = :batch_id", dict(batch_id=batch_id))
        dbconn.commit()


def publish_next_batch(dbconn):
    cursor = dbconn.cursor()
    res = cursor.execute("SELECT min(batch_id) FROM measurements WHERE batch_id > 0")
    batch_id, = res.fetchone()
    publish_batch(dbconn, batch_id)
    print(batch_id)


USAGE = """
Usage: dream.batcher  [--reset|--set-batch-id|--next-batch]

Options:
    --reset     Reset the datebase
    -h --help   Show this screen.
"""

if __name__ == "__main__":
    from docopt import docopt

    args = docopt(USAGE)

    dbconn = dbconnect()

    if args['--reset']:
        dbconn.execute('DROP TABLE IF EXISTS measurements')
        dbconn.commit()
        create_schema(dbconn)
    elif args['--set-batch-id']:
        create_unique_batch(dbconn)
        dbconn.commit()
    elif args['--next-batch']:
        publish_next_batch(dbconn)
    else:
        row = {
                "batch_id": 1,
                "timestamp": 123,
                "tag_id": "abc",
                "measurements": 'abcdef',
                "rssi": -54,
                "hci": 0
                }
        # cursor = dbconn.cursor()
        # insert(row, cursor=cursor)
        # dbconn.commit()

        # batch_id = 1
        # publish_batch(dbconn, batch_id)

    dbconn.close()
