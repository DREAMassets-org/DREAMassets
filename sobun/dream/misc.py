def main():

    delegate = BandwidthDelegate()
    scanner = Scanner(int(hci_num)).withDelegate(delegate)
    scantime = 110
    scanner.scan(scantime)
    print "scan time %d" % scantime
    print "hci is %s" % hci_num
    print "discoveries per second %d" % (delegate.discoveryCount / (scantime - 1))
    print "uniqueDevices count: %d" % len(delegate.uniqueDevices)
    print "discoveryCount: %d" % delegate.discoveryCount
