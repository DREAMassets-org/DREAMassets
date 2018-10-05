# this file is used for debugging
# we used this file to measure the upper limt of BLE advertising packets
# that the pi can receive, i.e., the "bandwidth"

from bluepy.btle import DefaultDelegate

from dream.sniffer import looper


class BandwidthDelegate(DefaultDelegate):
    uniqueDevices = set()
    discoveryCount = 0  #this is different from ScanEntry().updateCount bc it's for all devices

    def __init__(self):
        DefaultDelegate.__init__(self)

    def handleDiscovery(self, bleAdvertisement, isNewTag, isNewData):
        self.discoveryCount += 1
        self.uniqueDevices.add(bleAdvertisement.addr)


if __name__ == '__main__':

    hci = 0  # we set to 0 the BLE chip on the board; change to 1 for BLE USB dongle
    scantime = 100  #we set to 100 seconds by default

    delegate = BandwidthDelegate()
    scanner = Scanner(hci).withDelegate(delegate)
    scanner.scan(scantime)

    print "scan time %d" % scantime
    print "hci is %s" % hci_num
    print "discoveries per second %d" % (delegate.discoveryCount /
                                         (scantime - 1))
    print "uniqueDevices count: %d" % len(delegate.uniqueDevices)
    print "discoveryCount: %d" % delegate.discoveryCount
