#!/usr/bin/env python

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

    def handleDiscovery(self, dev, _isNewDev, _isNewData):

        if dev.rssi < self.opts.sensitivity:
            return

        measurement = {
            'tag_id': dev.addr.replace(':', ''),
            'rssi': dev.rssi,
            'hub_id': env['host']
        }
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
    parser.add_argument('-t', '--timeout', action='store', type=int, default=0,
                        help='Scan delay, 0 for continuous')
    parser.add_argument('-s', '--sensitivity', action='store', type=int, default=-200,
                        help='dBm value for filtering far devices')
    parser.add_argument('-b', '--bundle-size', type=int,
                        help='Number of measurements to send in each bundle', default=100)
    parser.add_argument('-L', '--log-file-name', action="store", help="Specify the log file name", default="logs/dream_tester.log")
    parser.add_argument('-l', '--log-level', action="store", help="Specify logging level (DEBUG, INFO, WARN, ERROR, FATAL)", default="INFO")
    parser.add_argument('-v', '--verbose', action='store_true',
                        help='Increase output verbosity')
    arg = parser.parse_args(sys.argv[1:])

    from bluepy import btle

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
    scanner.scan(arg.timeout)
    logger.info("Flush remaining packets")
    processor.flush()
    logger.info("Done scanning")


if __name__ == "__main__":
    main()
