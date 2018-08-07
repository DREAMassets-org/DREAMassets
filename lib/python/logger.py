import os
import logging


class Logger(object):

    LOGGING_DIR = "./logs"

    def __init__(self, name, level=None):
        name = name.replace('.log', '')
        logger = logging.getLogger('dream_assets.%s' % name)
        logger.setLevel(level)
        if not logger.handlers:
            file_name = os.path.join(self.LOGGING_DIR, '%s.log' % name)
            handler = logging.FileHandler(file_name)
            formatter = logging.Formatter('[%(asctime)s] %(levelname)5s -- : %(message)s')
            handler.setFormatter(formatter)
            handler.setLevel(level or logging.DEBUG)
            logger.addHandler(handler)
        self._logger = logger

    def get(self):
        return self._logger


class DreamAssetsLogger(Logger):
    def __init__(self, level=None):
        log_level = {
            'DEBUG': logging.DEBUG,
            'INFO': logging.INFO,
            'WARN': logging.WARN,
            'ERROR': logging.ERROR,
            'FATAL': logging.FATAL
        }[level]
        Logger.__init__(self, "dream_assets", log_level)
