from itertools import islice, chain


def batch(iterable, size):
    """
    Taken from: http://code.activestate.com/recipes/303279-getting-items-in-batches/
    """

    sourceiter = iter(iterable)
    while True:
        batchiter = islice(sourceiter, size)
        yield chain([batchiter.next()], batchiter)
