"""
This plugin hides all the messages related to the compilation inside
non writable files.
"""

import GPS
from gs_utils import hook
import os


@hook("compilation_finished")
def __on_compilation_finished(category, *args):
    for message in GPS.Message.list(category=category):
        if not os.access(message.get_file().name(), os.W_OK):
            message.remove()
