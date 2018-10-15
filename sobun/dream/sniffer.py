# this is sniffer.py, a python script to gather BLE data from Tags and push the data into a queue
#
# Data structure:
#   Overall:   BLE ADVERTISEMENT -> PACKET -> PAYLOAD
#
#   sniffer.py BLE ADVERTISEMENT -> PACKET
#              gathers a BLE advertisement
#              extracts a packet from the BLE advertisement
#              pushes the packet into the queue
#
#   syncer.py  PACKET -> PAYLOAD
#              pops packet from the queue
#              extracts a payload from the packet
#              publishes payload to cloud

# get libraries for print, regular expression, file system, and interrupt signals
from __future__ import print_function
import re
import sys
import signal
from time import time as now

# Get the bluepy library
from bluepy.btle import Scanner, DefaultDelegate

# sniffer.py pushes data into a queue that syncer.py pops
# syncer runs the celery worker using the redis queue: https://celery.readthedocs.io/en/latest/getting-started/first-steps-with-celery.html#first-steps
from dream.syncer import batch


def extract_packet_from_bleAdvertisement(bleAdvertisement):
    try:
        # get the tag_id (MAC address) and rssi from the BLE advertisement
        # since the MAC address comes with colons, remove them.
        tag_id = bleAdvertisement.addr.replace(':', '')
        rssi = bleAdvertisement.rssi

        # getScanData returns a tripple from the ScanEntry object
        # the tripple has the advertising type, description and value (adtype, desc, value)
        triples = bleAdvertisement.getScanData()

        # Bluetooth defines AD types https://ianharvey.github.io/bluepy-doc/scanentry.html
        # DREAM only wants adtype = 0xff (0d255) for manufacturer data
        # values is a list where the last element is the manufacturer data
        values = [value for (adtype, desc, value) in triples if adtype == 255]
        if len(values):
            return {
                # return this packet
                "tag_id": tag_id,
                "rssi": rssi,
                "timestamp": int(now()),
                "mfr_data": values[-1],
            }
        return None

    except (UnicodeEncodeError, UnicodeDecodeError):
        # If there's a unicode error, disregard it since it isn't a Fujitsu Tag
        return None


# define the regular expression (regex) for Fujitsu  
FUJITSU_PACKET_REGEX = re.compile(r'010003000300')

# evaluate whether a packet has mfr_data matching fujitsu 
def is_fujitsu_tag(packet):
    return re.search(FUJITSU_PACKET_REGEX, packet['mfr_data'])


# The PushDelegate receives BLE advertisements from the scanner
class PushDelegate(DefaultDelegate):
    def __init__(self, hci=0):
        DefaultDelegate.__init__(self)
        self.hci = hci

    # When this script "discovers" a new BLE advertisement, do this:
    def handleDiscovery(self, bleAdvertisement, _unused_isNewTag_,
                        _unused_isNewData_):
        # _unused_isNewTag_ and _unused_isNewData_ arent' relevant for DREAM
        packet = extract_packet_from_bleAdvertisement(bleAdvertisement)
        if packet:
            if is_fujitsu_tag(packet):
                #push the packet into the redis broker queue for a celery worker to handle asynchronously
                # push.delay(packet, self.hci)
                batch.delay(packet, self.hci)
                print('push packet from HCI {hci} to the celery queue'.format(hci=self.hci))


# scan continuously
def looper(scanner):

    # define how to stop the scan on an interrupt
    def stop_scan(signum, frame):
        scanner.stop()
        sys.exit(0)

    signal.signal(signal.SIGHUP, stop_scan)
    signal.signal(signal.SIGINT, stop_scan)
    signal.signal(signal.SIGTERM, stop_scan)
    signal.signal(signal.SIGTSTP, stop_scan)

    # start the scan and run forever
    scanner.clear()
    scanner.start()
    while True:
        scanner.process()


# This is for docopt.
# The "<hci>" means something to docopt, it's not just text
USAGE = """
Usage: dream.sniffer <hci>

Options:
    <hci>       The integer of the Bluetooth interface
    -h --help   Show this screen.
"""

# this is the entry point to the code.
# __name and __main are the python hooks to run the code
if __name__ == '__main__':
    from docopt import docopt

    # get the argument for which BLE to use. hci0 is BLE built into RasPi. hci1 is BLE USB dongle.
    # ??? can we add a default value 0?
    args = docopt(USAGE)
    hci = args['<hci>']

    # this delegate will receive the BLE advertisemnts from the scanner
    delegate = PushDelegate(hci)

    # the scanner receives the BLE advertising packets and delivers them to the delegate
    scanner = Scanner(hci).withDelegate(delegate)

    # looper just scans forever and ever, amen.
    looper(scanner)
