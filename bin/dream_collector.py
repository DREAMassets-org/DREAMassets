#!/usr/bin/env python

# This script was designed to run on a RaspberryPi or Cassia X1000 system that has the `bluez`
# BLE listening software installed.  
#
# When you run this software, it will listen to the Bluetooth traffic, filter out the Fujitsu
# packets, bundle those into CSVs and send them to Google Cloud Storage.
#
#

from __future__ import print_function
import argparse
import sys
import json
import re

from bluepy import btle

sys.path.insert(0, 'lib/python')

from google_cloud import GoogleCsvUploader
from fujitsu_packet_processor import FujitsuPacketProcessor
from logger import DreamAssetsLogger
import packet_decoder
import dream_environment

env = dream_environment.fetch()


class ScanFujitsu(btle.DefaultDelegate):
    fujitsu_packet_regex = re.compile(r'010003000300')

    def __init__(self, opts, processor):
        btle.DefaultDelegate.__init__(self)
        self.opts = opts
        self.processor = processor

    def handleDiscovery(self, packet, _unused_isNewDevice, _unused_isNewData):

        if packet.rssi < self.opts.sensitivity:
            return

        # The data packets come from the Fujitsu tags and arrive in this format (without spaces).
        # Here's real sample data for three Fujitsu beacons:
        #  1               2                     3                         4   5    6    7   8
        # 043E2102010301 1C0CB35CBBD5 15 0201 04 11FF5900 0100 0300 0300 7F03 A503 C4FF A907 C3
        # 043E2102010301 F2461FBDA1D4 15 0201 04 11FF5900 0100 0300 0300 4C03 6100 BDFF 0F08 CA
        # 043E2102010301 71BF99DC8CF7 15 0201 04 11FF5900 0100 0300 0300 F904 8D00 5800 1E08 C4
        # 
        # This is what you might see if you used `hcidump` to get the raw packet data.
        #
        # Here we're using `bluepy` which takes that data and does a bit of processing to give us
        # rssi, and tag_id (which it calls `addr`) and a slightly parsed version of the rest.
        # Check out https://ianharvey.github.io/bluepy-doc/scanentry.html for details
        # 
        # For the first packet listed above as a python ScanEntry() class (from bluepy) 
        # you might see something like the following
        #
        # > packet.addr
        # u'd5:bb:5c:b3:0c:1c
        # > packet.rssi
        # -66 
        # > packet.getScanData()
        # [(1, 'Flags', '04'), (255, 'Manufacturer', '59000100030003007F03A503C4FFA907')]
        #                                             
        # NOTE: the rssi number comes from C3 but -66 is probably not the real value.  I don't know
        # the math that bluepy does to compute that number.  When we get it from bluepy, it is
        # in dBm's
        
        packet_payload = extract_packet_payload(packet)
        # if the packet matches a fujitsu packet
        if re.search(self.fujitsu_packet_regex, packet_payload):
            measurement = {
                'tag_id': packet.addr.replace(':', ''),
                'rssi': packet.rssi,
                'hub_id': env['host']
            }
            # Add acceleration/temperature data which we've decoded from payload to measurement
            measurement.update(packet_decoder.decode(packet_payload)) 
            # add measurement to our processor
            self.processor.addMeasurement(measurement)
            if self.opts.verbose:
                print (json.dumps(measurement))

    def extract_packet_payload(self, packet)
        # extract all packet data
        scan_data_hash = {}
        for (sdid, desc, val) in dev.getScanData():
            scan_data_hash[desc] = val
        # return only the "Manufacturer" setting which is the data that 
        # includes temp/acceleration (assuming it's a Fujitsu packet)
        return scan_data_hash.get('Manufacturer', '')

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('-i', '--hci', action='store', type=int, default=0,
                        help='Interface number for scan')
    parser.add_argument('-t', '--timeout', action='store', type=int, default=0,
                        help='Scan delay, 0 for continuous')
    parser.add_argument('-s', '--sensitivity', action='store', type=int, default=-500,
                        help='dBm value for filtering far devices')
    parser.add_argument('-b', '--bundle-size', type=int,
                        help='Number of measurements to send in each bundle', default=100)
    parser.add_argument('-l', '--log-level', action="store", help="Specify logging level (DEBUG, INFO, WARN, ERROR, FATAL)", default="INFO")
    parser.add_argument('-v', '--verbose', action='store_true',
                        help='Increase output verbosity')
    arg = parser.parse_args(sys.argv[1:])

    logger = DreamAssetsLogger(arg.log_level).get()

    logger.info("Running with args: %s" % arg)
    logger.info("Current Environment: %s" % env)

    if arg.verbose:
        print("Command-line arguments:")
        print(repr(arg))
        print
        print("Environment:")
        print(repr(env))
        print

    uploader = GoogleCsvUploader(env['project_id'], env['credentials'], env['host'], env['bucket'], env['directory'], logger)
    processor = FujitsuPacketProcessor(arg, uploader, logger)
    fujitsu_listener = ScanFujitsu(arg, processor)
    scanner = btle.Scanner(arg.hci).withDelegate(fujitsu_listener)

    logger.info("Start scanning")
    print("Scanning for Fujitsu Packets...")

    # The code below `scanner.scan()` is very much like
    #
    # while packet = scan_for_packet
    #    ScanFujitsu.handleDiscovery(packet)
    # end
    #
    # expect bluepy built it using eventing and callbacks
    scanner.scan(arg.timeout)

    logger.info("Flush remaining packets")
    processor.flush()
    logger.info("Done scanning")


if __name__ == "__main__":
    main()
