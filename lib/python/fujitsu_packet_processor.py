import re
import time

# This class processes measurements by collecting them in 
# bundle and when the bundle is the right size, upload them via the 
# uploader (which is passed in when we construct the instance of the
# processor)
class FujitsuPacketProcessor():
    fujitsu_packet_regex = re.compile(r'010003000300')
    def __init__(self, opts, uploader, logger):
        self.bundle = []
        self.opts = opts
        self.uploader = uploader
        self.logger = logger

    def addMeasurement(self, measurement):
        measurement.update({'timestamp': time.time()})
        self.bundle.append(measurement)
        if (len(self.bundle) >= self.opts.bundle_size):
            self.upload_and_reset()

    def flush(self):
        self.upload_and_reset()

    def upload_and_reset(self):
        if (len(self.bundle) > 0):
            self.uploader.package_and_upload(self.bundle)
            self.bundle = []
