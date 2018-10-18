from itertools import islice, chain


def batch(iterable, size):
    """
    Taken from: http://code.activestate.com/recipes/303279-getting-items-in-batches/
    """

    sourceiter = iter(iterable)
    while True:
        batchiter = islice(sourceiter, size)
        try:
            batch = chain([next(batchiter)], batchiter)
            yield batch
        except StopIteration as e:
            break


def rows_from_payloads(payloads, hub_id):
    lines = payloads.split('\n')
    rows = []
    last_tag_id = None
    for line in lines:
        if line.strip() == "":
            continue
        row = line.split(',')
        timestamp, tag_id, measurements, hci, rssi = row
        if tag_id == "":
            tag_id = last_tag_id
        else:
            last_tag_id = tag_id
        bigquery_row = (tag_id, measurements, hub_id, int(timestamp), int(rssi), int(hci))
        rows.append(bigquery_row)
    return rows
