import re
import time

# This class processes measurements by collecting them in
# bundle and when the bundle is the right size, upload them via the
# uploader (which is passed in when we construct the instance of the
# processor)
#
# kwargs means keyword argument
class FujitsuPacketProcessor():
    fujitsu_packet_regex = re.compile(r'010003000300')
    # re.compile compiles a regular expression pattern into a regular expression object
    # https://docs.python.org/2/library/re.html
    # kwargs means keyword argument
    def __init__(self, opts, uploader, **kwargs):
        self.bundle = []
        self.opts = opts
        self.uploader = uploader
        self.logger = kwargs.get('logger', None)

    def addMeasurement(self, measurement):
        measurement.update({'timestamp': time.time()})
        self.bundle.append(measurement)

    def flush(self):
        self.upload_and_reset()

    def upload_and_reset(self):
        if (len(self.bundle) > 0):
            self.uploader and self.uploader.package_and_upload(self.bundle)
            self.bundle = []
        else:
            self.logger.warn("Nothing to upload")
