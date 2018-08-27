#!/usr/bin/env python
# -*- coding: utf-8 -*-

# This script was designed to run on a RaspberryPi or Cassia X1000 system that has the `bluez`
# BLE listening software installed.
#
# When you run this software, it will listen to the Bluetooth traffic, filter out the Fujitsu
# packets, bundle those into CSVs and send them to Google Cloud Storage.
#
# Mike is editing this file in the mike_python_tweaks branch
# Mike added comments to the library and validated they worked by running them on setit
# Mike is now about to change the code
# why isn't this change catching in git status? because I was in setit, not on my laptop :)

# Note to Mike & Jon: let's distinguish external libraries (e.g., google) from internal (e.g., packet_decoder)
from __future__ import print_function
import argparse
import signal
import daemon
import lockfile
import sys
import os
import json
import re
import traceback
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

    def __init__(self, opts, processor, logger=None):
        btle.DefaultDelegate.__init__(self)
        self.opts = opts
        self.processor = processor
        self.logger = logger

    def handleDiscovery(self, packet, _unused_isNewDevice, _unused_isNewData):

        if packet.rssi < self.opts.sensitivity:
            # what is the sensitivity threshold we're using? why have a threshold at all?
            return

        # The data packets come from the Fujitsu tags and arrive in this format (without spaces).
        # Here's real sample data for three Fujitsu beacons (spaces added for readability):
        #  1               2                     3                         4   5    6    7   8
        # 043E2102010301 1C0CB35CBBD5 15 0201 04 11FF5900 0100 0300 0300 7F03 A503 C4FF A907 C3
        # 043E2102010301 F2461FBDA1D4 15 0201 04 11FF5900 0100 0300 0300 4C03 6100 BDFF 0F08 CA
        # 043E2102010301 71BF99DC8CF7 15 0201 04 11FF5900 0100 0300 0300 F904 8D00 5800 1E08 C4
        #
        # This is what you might see if you used `hcidump` to get the raw packet data.
        #
        # Here we're using `bluepy` which takes that data and does a bit of processing to give us
        # rssi, and tag_id (which it calls `addr`) and a slightly parsed version of the rest.
        # For details check out:
        # https://ianharvey.github.io/bluepy-doc/scanentry.html
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

        packet_payload = self.extract_packet_payload(packet)
        # if the packet matches a fujitsu packet, i.e., has the regex 010003000300
        if re.search(self.fujitsu_packet_regex, packet_payload):
            # We transform a `packet` with meaningless binary values (0x0123)
            # into a `measurement` with meaningful decimal values (72 degF)
            measurement = {
                'tag_id': packet.addr.replace(':', ''),
                'rssi': packet.rssi,
                'hub_id': env['host']
            }
            # Add acceleration/temperature data which we've decoded from payload to measurement
            measurement.update(packet_decoder.decode(packet_payload))
            # add measurement to our processor
            # why do we have a processor? what does it do exactly? why does it do the uploading?
            self.processor.addMeasurement(measurement)
            # if we're running in verbose mode -v, then output the json of the measurement
            if self.opts.verbose:
                print (json.dumps(measurement))

    def extract_packet_payload(self, packet):
        try:
            # extract all packet data
            scan_data_hash = {}
            for (sdid, desc, val) in packet.getScanData():
                scan_data_hash[desc] = val
            # return only the "Manufacturer" setting which is the data that
            # includes temp/acceleration (assuming it's a Fujitsu packet)
            return scan_data_hash.get('Manufacturer', '')
        except (UnicodeEncodeError, UnicodeDecodeError):
            # there's a bug where this error detector flags an unknown device for an unknown reason.
            # for now we're leaving it alone, but it might be important eventually
            msg = "Failed to extract packet data from device %s" % packet.addr
            self.logger and self.logger.error(msg)
            if self.opts.verbose:
               print(msg, file=sys.stderr)
            return ''


class DreamCollector():

    def __init__(self, options, env, **kwargs):
        self.options = options
        self.uploader = None
        self.logger = kwargs.get('logger', None)
        if not options.scan_only:
            self.uploader = GoogleCsvUploader(
                env['project_id'],
                env['credentials'],
                env['host'],
                env['bucket'],
                env['directory'],
                env['bq_dataset'],
                env['bq_table'],
                big_query_update=options.big_query_update,
                logger=self.logger)
        self.processor = FujitsuPacketProcessor(options, self.uploader, logger=self.logger)
        self.fujitsu_listener = ScanFujitsu(options, self.processor, self.logger)
        self.scanner = btle.Scanner(options.hci).withDelegate(self.fujitsu_listener)


    def shutdown(self, sig, frame):
        self.logger.debug("Caught signal {}".format(sig))
        self.processor and self.processor.flush()
        sys.exit(0)

    def timed_scan_and_flush(self, scan_time):
        self.logger.debug("Scan for %d seconds..." % scan_time)
        # The code below `scanner.scan()` is very much like
        #
        # while packet = scan_for_packet
        #    ScanFujitsu.handleDiscovery(packet)
        # end
        #
        # expect bluepy built it using eventing and callbacks
        self.scanner.scan(scan_time)
        self.logger.debug("done")
        self.logger.debug("Flushing packets...")
        self.processor.flush()

    def run(self):
        uploader = None

        self.logger.info("Start scanning")
        print("Scanning for Fujitsu Packets...")

        scan_time = self.options.time_per_scan
        try:
            self.logger.debug("Sanity check scan for 10 seconds...")
            self.timed_scan_and_flush(10)
            while True:
                self.timed_scan_and_flush(scan_time)
        except btle.BTLEException as ex:
            # What does this mean? "with exception"?
            backtrace = traceback.format_exc()
            msg = "Scanning failed with exception"
            print(msg, file=sys.stderr)
            print(backtrace, file=sys.stderr)
            self.logger.fatal(msg)
            self.logger.fatal(backtrace)
        finally:
            self.logger.info("Flushing remaining measurements")
            self.processor.flush()
        self.logger.info("Done scanning")

def main():
    parser = argparse.ArgumentParser()
    # the -i argument specifies the HCI (Host Controller Interface)
    # the project uses hci0 and hci1 (???)
    # https://www.jaredwolff.com/blog/get-started-with-bluetooth-low-energy/
    parser.add_argument('-i', '--hci', action='store', type=int, default=0,
                        help='Interface number for scan')
    # how does timeout work? is it a timer that ends or a time period that repeats?
    parser.add_argument('-t', '--time-per-scan', action='store', type=int, default=10,
                        help='Number of seconds to scan in between sending/bundling data')
    #how does sensitivity work? -500 seems like a fine default
    parser.add_argument('-s', '--sensitivity', action='store', type=int, default=-500,
                        help='dBm value for filtering far devices')
    #maybe increase the default bundle size to 1000?
    parser.add_argument('-b', '--bundle-size', type=int,
                        help='Number of measurements to send in each bundle', default=100)
    # always leave this off
    parser.add_argument('--big-query-update', action='store_true', help="Enable the BigQuery update notification after new data has been sent to Google. Default: false")
    # scan-only is useful in debugging. Must be used with verbose -v mode so you can see the output
    parser.add_argument('-S', '--scan-only', action='store_true', help="Scan only.  Don't upload any data.  Should be used with -v option")
    # log level is useful in debugging
    parser.add_argument('-l', '--log-level', action="store", help="Specify logging level (DEBUG, INFO, WARN, ERROR, FATAL)", default="INFO")
    # in steady-state operation, be sure to daemonize the process so that it doesn't fail
    # daemonizing allows the script to run in the background. to see it's running:
    # ps -ef | grep python
    parser.add_argument('-d', '--daemonize', action='store_true',
                        help='Run as a daemon in the background')
    # verbose mode shows the output on the terminal screen. super helpful.
    parser.add_argument('-v', '--verbose', action='store_true',
                        help='Increase output verbosity')
    arg = parser.parse_args(sys.argv[1:])

    logging_system = DreamAssetsLogger(arg.log_level)
    logger = logging_system.get()

    logger.info("Running with args: %s" % arg)
    logger.info("Current Environment: %s" % env)

    if arg.time_per_scan < 5:
        print("***", file=sys.stderr)
        print("*** Your time-per-scan must be at least 5 seconds", file=sys.stderr)
        print("***", file=sys.stderr)
        parser.print_help()
        exit(1);

    if arg.verbose:
        print("Command-line arguments:")
        print(repr(arg))
        print
        print("Environment:")
        print(repr(env))
        print

    collector = DreamCollector(arg, env, logger=logger)
    if arg.daemonize:
        logger.info("Daemonizing the collector 😈")

        with daemon.DaemonContext(
                working_directory=".",
                files_preserve=logging_system.file_descriptors(),
                signal_map={
                    signal.SIGINT: collector.shutdown,
                    signal.SIGHUP: collector.shutdown,
                    signal.SIGTERM: collector.shutdown,
                    signal.SIGTSTP: collector.shutdown
                },
                pidfile=lockfile.FileLock('dream_collector.pid')):
            collector.run()
    else:
        # register interrupt handler
        signal.signal(signal.SIGINT, collector.shutdown)
        signal.signal(signal.SIGHUP, collector.shutdown)
        signal.signal(signal.SIGTERM, collector.shutdown)
        signal.signal(signal.SIGTSTP, collector.shutdown)

        collector.run()

# what does this do?
if __name__ == "__main__":
    main()
