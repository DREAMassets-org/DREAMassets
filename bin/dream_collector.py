#!/usr/bin/env python

from __future__ import print_function
import argparse
import binascii
import os
import imp
import sys
import json
import re

from bluepy import btle

import sys
sys.path.insert(0, 'lib/python')

from google_cloud_storage import GoogleCsvUploader
from fujitsu_packet_processor import FujitsuPacketProcessor
import packet_decoder
import dream_environment

env = dream_environment.fetch()

if os.getenv('C', '1') == '0':
    ANSI_RED = ''
    ANSI_GREEN = ''
    ANSI_YELLOW = ''
    ANSI_CYAN = ''
    ANSI_WHITE = ''
    ANSI_OFF = ''
else:
    ANSI_CSI = "\033["
    ANSI_RED = ANSI_CSI + '31m'
    ANSI_GREEN = ANSI_CSI + '32m'
    ANSI_YELLOW = ANSI_CSI + '33m'
    ANSI_CYAN = ANSI_CSI + '36m'
    ANSI_WHITE = ANSI_CSI + '37m'
    ANSI_OFF = ANSI_CSI + '0m'

class ScanFujitsu(btle.DefaultDelegate):
    fujitsu_packet_regex = re.compile(r'010003000300')

    def __init__(self, opts, processor):
        btle.DefaultDelegate.__init__(self)
        self.opts = opts
        self.processor = processor

    def handleDiscovery(self, dev, _isNewDev, _isNewData):

        if dev.rssi < self.opts.sensitivity:
            return

        measurement = {
            'tag_id': dev.addr.replace(':', ''),
            'rssi': dev.rssi,
            'hub_id': env['host']
        }
        scan_data = dev.getScanData()
        scan_data_hash = {}
        for (sdid, desc, val) in dev.getScanData():
            scan_data_hash[desc] = val
        packet_data = scan_data_hash.get('Manufacturer', '')
        if re.search(self.fujitsu_packet_regex, packet_data):
            measurement.update(packet_decoder.decode(val))
            self.processor.addMeasurement(measurement)
            if self.opts.verbose:
                print (json.dumps(measurement))

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('-i', '--hci', action='store', type=int, default=0,
                        help='Interface number for scan')
    parser.add_argument('-t', '--timeout', action='store', type=int, default=4,
                        help='Scan delay, 0 for continuous')
    parser.add_argument('-s', '--sensitivity', action='store', type=int, default=-200,
                        help='dBm value for filtering far devices')
    parser.add_argument('-b', '--bundle-size', type=int,
                        help='Number of measurements to send in each bundle', default=100)
    parser.add_argument('-v', '--verbose', action='store_true',
                        help='Increase output verbosity')
    arg = parser.parse_args(sys.argv[1:])

    from bluepy import btle

    if arg.verbose:
        print("Environment:")
        print(repr(env))
        print

    uploader = GoogleCsvUploader(env['project_id'], env['credentials'], env['host'], env['bucket'], env['directory'])
    processor = FujitsuPacketProcessor(arg, uploader)
    fujitsu_listener = ScanFujitsu(arg, processor)
    scanner = btle.Scanner(arg.hci).withDelegate(fujitsu_listener)

    print (ANSI_RED + "Scanning for Fujitsu Packets..." + ANSI_OFF)
    _devices = scanner.scan(arg.timeout)


if __name__ == "__main__":
    main()
