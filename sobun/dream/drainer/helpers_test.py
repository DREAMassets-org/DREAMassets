import helpers


def test_batch():
    seq = [1, 2, 3]
    batches = helpers.batch(seq, 2)
    first, last = [list(batch) for batch in batches]
    assert first == [1, 2]
    assert last == [3]
