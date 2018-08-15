#!/usr/bin/env python

# This script was built and used to test the GoogleCloud hookup on a Mac (without the BLE listening hardware and software)
# It expects an input file that is a list of JSON objects (like you would get from the scanner).
# It reads that file in and bundles it into a CSV and sends it to Google Cloud Storage
#
# Given a file like
# `packets.json`
#
# {"z_acc": -0.99169921875, "temperature": 73.67096774193548, "hub_id": "ubuntu", "rssi": -53, "y_acc": -0.01318359375, "x_acc": 0.02685546875, "tag_id": "f814d580fa46"}
# {"z_acc": 0.048828125, "temperature": 72.5819211070177, "hub_id": "ubuntu", "rssi": -42, "y_acc": 0.017578125, "x_acc": 1.0439453125, "tag_id": "c4663179cedf"}
# {"z_acc": 1.01611328125, "temperature": 73.22887950399857, "hub_id": "ubuntu", "rssi": -35, "y_acc": 0.14208984375, "x_acc": 0.05859375, "tag_id": "d0d7ca18963f"}
#
# You can upload these using this script:
#
# bin/dream_tester.py -f packets.json -b 10
#
#


from __future__ import print_function
import argparse
import sys
import json
import pdb
sys.path.insert(0, 'lib/python')

from google_cloud import GoogleCsvUploader
from fujitsu_packet_processor import FujitsuPacketProcessor
from logger import DreamAssetsLogger
import dream_environment

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('-f', '--file', type=argparse.FileType('r'), default="-",
                        help='Specify the file tha contains the sample measurements.  Assumes 1 JSON object per line that contains the measurement (e.g. {"z_acc": -0.99169921875, "temperature": 73.67096774193548, "hub_id": "ubuntu", "rssi": -53, "y_acc": -0.01318359375, "x_acc": 0.02685546875, "tag_id": "f814d580fa46"}.  Default is stdin')
    parser.add_argument('-b', '--bundle-size', type=int,
                        help='Number of measurements to send in each bundle', default=10)
    parser.add_argument('-l', '--log-level', action="store", help="Specify logging level (DEBUG, INFO, WARN, ERROR, FATAL)", default="INFO")
    parser.add_argument('-v', '--verbose', action='store_true',
                        help='Increase output verbosity')
    arg = parser.parse_args(sys.argv[1:])

    env = dream_environment.fetch()

    logger = DreamAssetsLogger(arg.log_level).get()

    logger.info("Running with args: %s" % arg)
    logger.info("Current Environment: %s" % env)

    if arg.verbose:
        print("Command-line Arguments: ", arg)
        print("Environment:")
        print(repr(env))
        print

    logger.info("Start reading packets")
    print("Reading Fujitsu Packets from file...")

    uploader = GoogleCsvUploader(
        env['project_id'],
        env['credentials'],
        env['host'],
        env['bucket'],
        env['directory'],
        env['bq_dataset'],
        env['bq_table'],
        logger=logger)
    processor = FujitsuPacketProcessor(arg, uploader, logger=logger)

    for line in arg.file:
        try:
            data = json.loads(line)
            processor.addMeasurement(data)
        except ValueError:
            # skip if we can't decode
            logger.warn("Unable to parse input line [%s]", line)
            pass

    processor.flush()
    logger.info("Done")


if __name__ == "__main__":
    main()
