# DREAM uses SQLite to pop payloads from the queue 
# and batch the payloads in groups of 20k before 
# publishing to Google PubSub
#
# Create the db schema


import sqlite3
# Note that SQLite allows many concurrent reads and but just 1 write at a time
# DREAM has different processes that write to the database (syncer and batcher)
# So we need to account for when the file is locked during a write. 

# open to the database file 
def dbconnect(name=None):
    if not name:
        # the default name for the SQLite database
        name = 'measurements.db'

    # Wait at most for 30 seconds for the lock to go away (rather than default of 5 seconds)
    conn = sqlite3.connect(name, timeout=30000)
    conn.row_factory = sqlite3.Row
    return conn


# Create a schema which defines a table called measurements
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


def insert(row_or_rows, cursor, many=False):
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
    if many:
        cursor.executemany(sql, row_or_rows)
    else:
        cursor.execute(sql, row_or_rows)

# We put payloads in a batch to reduce bandwidth costs on the cellular network 
# Mark which rows in the table are part of a batch with a batch_id
# We need to mark batches to handle the case when PubSub fails and we need to retry sending the batch 
def create_unique_batch(dbconn, batch_size=20000):
    cursor = dbconn.cursor()
    res = cursor.execute("SELECT count(*) FROM measurements WHERE batch_id = 0")
    count, = res.fetchone()
    if count > batch_size:
        sql = """
            UPDATE measurements SET batch_id = (SELECT MAX(batch_id)+1 from measurements)
            WHERE batch_id = 0
            ORDER BY timestamp
            LIMIT :batch_size
        """
        cursor.execute(sql, dict(batch_size=batch_size))
        print('batch created')
    else:
        print('{} more payloads are needed before the batch is ready to publish'.format(batch_size - count))


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
        ORDER BY tag_id
    """
    cursor = dbconn.cursor()
    rows = cursor.execute(sql, dict(batch_id=batch_id))
    lines = []
    last_tag_id = None
    for row in rows:
        timestamp, tag_id, measurements, hci, rssi = row
        if tag_id == last_tag_id:
            tag_id = ""
        else:
            last_tag_id = tag_id
        compacted_row = (timestamp, tag_id, measurements, hci, rssi)
        lines.append(",".join(map(str, compacted_row)))
    payload = "\n".join(lines)

    msg_id = send_batch(payload)
    if msg_id:
        dbconn.execute("DELETE FROM measurements WHERE batch_id = :batch_id", dict(batch_id=batch_id))
        dbconn.commit()


def publish_next_batch(dbconn):
    create_unique_batch(dbconn)
    dbconn.commit()

    cursor = dbconn.cursor()
    # store the result (res)
    res = cursor.execute("SELECT min(batch_id) FROM measurements WHERE batch_id > 0")
    batch_id, = res.fetchone()
    if batch_id:
        publish_batch(dbconn, batch_id)
        print("Published {}".format(batch_id))
    else:
        print("Nothing to batch yet")


def generate_sample_payloads(dbconn):
    cursor = dbconn.cursor()
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
            ?,
            ?,
            ?,
            ?,
            ?
        )
    """
    with open('fixtures/sample_rows.txt') as src:
        lines = src.readlines()
        rows = [row.strip().split(',') for row in lines]
        cursor.executemany(sql, rows)
    dbconn.commit()


USAGE = """
Usage: dream.batcher  [--reset|--set-batch-id|--next-batch|--genpayloads]

Options:
    --reset     Reset the datebase
    -h --help   Show this screen.
"""

# pristine.sh launches setup-sqlite-db.sh which runs this script in reset mode to create the db schema 
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
    elif args['--genpayloads']:
        for x in xrange(200):
            generate_sample_payloads(dbconn)


    dbconn.close()
