class PacketBundler(object):

    def __init__(self, cleaner, bundle_size=100, hci=0):
        self.cleaner = cleaner
        self.bundle_size = bundle_size
        self.hci = hci
        self.bundle = []


    def append(self, packet):
        self.bundle.append(packet)

        if len(self.bundle) == self.bundle_size:
            self.push_to_queue()


    def push_to_queue(self):
        self.cleaner.delay(self.bundle, self.hci)
        self.bundle = []
