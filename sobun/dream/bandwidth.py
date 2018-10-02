from bluepy.btle import DefaultDelegate

class BandwidthDelegate(DefaultDelegate):
    uniqueDevices = set()
    discoveryCount = 0

    def __init__(self):
        DefaultDelegate.__init__(self)

    def handleDiscovery(self, bleAdvertisement, isNewTag, isNewData):
        self.discoveryCount += 1
        self.uniqueDevices.add(bleAdvertisement.addr)
