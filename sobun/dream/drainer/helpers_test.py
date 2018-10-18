import helpers


def test_batch():
    seq = [1, 2, 3]
    batches = helpers.batch(seq, 2)
    first, last = [list(batch) for batch in batches]
    assert first == [1, 2]
    assert last == [3]


def test_row_from_payloads():
    with open('payloads.txt') as src:
        lines = src.read()
        rows = helpers.rows_from_payloads(lines, "ruya")
        tag_ids = [row[0] for row in rows]
        uniq_tag_ids = set(tag_ids)
        assert uniq_tag_ids == set(['tag1', 'tag2', 'tag3'])
