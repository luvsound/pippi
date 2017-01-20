import os
from . import config

def init(name):
    path = os.getcwd()

    # create project directory
    if not os.path.exists(os.path.join(path, name)):
        os.mkdir(os.path.join(path, name))

    # create orc directory
    if not os.path.exists(os.path.join(path, name, 'orc')):
        os.mkdir(os.path.join(path, name, 'orc'))

    # create local config
    config_file = config.create_config(os.path.join(path, name))


