import re
import time

class FujitsuPacketProcessor():
    fujitsu_packet_regex = re.compile(r'010003000300')

    def __init__(self, opts, uploader):
        self.collected = []
        self.opts = opts
        self.uploader = uploader

    def addMeasurement(self, measurement):
        measurement.update({ 'timestamp': time.time() })
        self.collected.append(measurement)
        if (len(self.collected) > self.opts.bundle_size):
            self.upload_and_reset()

    def flush(self):
        self.upload_and_reset()

    def upload_and_reset(self):
        if (len(self.collected) > 0):
            self.uploader.package_and_upload(self.collected)
            self.collected = []
