# this file was used for development purposes

from mock import Mock
from dream.core import PacketBundler


def test_packet_bundler():
    cleaner = Mock()
    bundle_size = 100
    bundler = PacketBundler(cleaner, bundle_size=bundle_size, hci=1)
    for packet in xrange(bundle_size):
        bundler.append(packet)

    cleaner.delay.assert_called_once_with(list(xrange(100)), 1)
    assert bundler.bundle == []
