""" FIXME: this is a dumb way to do config
"""

import os
import shutil

default_path = os.path.dirname(os.path.abspath(__file__)) + '/default.config'

keys = [
    'device', 
    'bpm', 
    'key', 
    'ratios', 
    'a4'
]

def parse(config_file):
    default_config = {}
    execfile(default_path, default_config)
    if not os.path.isfile(config_file):
        return default_config

    config = {}
    execfile(config_file, config)

    parsed = {}
    for key in keys:
        if key not in config:
            parsed[key] = default_config[key]
        else:
            parsed[key] = config[key]

    return parsed

def create_config(path):
    path = os.path.join(path, 'pippi.config')
    if not os.path.isfile(path):
        shutil.copy(default_path, path)

    config = {}
    execfile(path, config)
    return config

def init():
    """ Look for a config file and load into dict, otherwise load defaults
    """
    config = None
    user_config_path = os.path.expanduser('~')
    local_config_path = os.getcwd()

    # look for a local config file
    if os.path.isfile(os.path.join(user_config_path, 'pippi.config')):
        config = parse(user_config_path)

    if os.path.isfile(os.path.join(local_config_path, 'pippi.config')):
        config = parse(local_config_path)

    if config is None:
        config = create_config(user_config_path)

    return config

