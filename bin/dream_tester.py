#!/usr/bin/env python

from __future__ import print_function
import argparse
import sys
import json

sys.path.insert(0, 'lib/python')

from google_cloud import GoogleCsvUploader
from fujitsu_packet_processor import FujitsuPacketProcessor
from logger import DreamAssetsLogger
import dream_environment

env = dream_environment.fetch()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('-F', '--format', action="store", help="Specify avro or csv for the file format to upload")
    parser.add_argument('-f', '--file', type=argparse.FileType('r'), default="-",
                        help='Specify the file tha contains the sample measurements.  Assumes 1 JSON object per line that contains the measurement (e.g. {"z_acc": -0.99169921875, "temperature": 73.67096774193548, "hub_id": "ubuntu", "rssi": -53, "y_acc": -0.01318359375, "x_acc": 0.02685546875, "tag_id": "f814d580fa46"}.  Default is stdin')
    parser.add_argument('-b', '--bundle-size', type=int,
                        help='Number of measurements to send in each bundle', default=10)
    parser.add_argument('-L', '--log-file-name', action="store", help="Specify the log file name", default="logs/dream_tester.log")
    parser.add_argument('-l', '--log-level', action="store", help="Specify logging level (DEBUG, INFO, WARN, ERROR, FATAL)", default="INFO")
    parser.add_argument('-v', '--verbose', action='store_true',
                        help='Increase output verbosity')
    arg = parser.parse_args(sys.argv[1:])

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

    uploader = GoogleCsvUploader(env['project_id'], env['credentials'], env['host'], env['bucket'], env['directory'], logger)
    processor = FujitsuPacketProcessor(arg, uploader, logger)

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
