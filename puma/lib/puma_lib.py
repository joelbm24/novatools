import yaml, boto, os

class Puma:
    def __init__(self):
        self.puma_dir = os.environ["HOME"] + "/puma"
    def parse_config(self):
        config_file = file(self.puma_dir + "/config.yml", "r")
        config = yaml.load(config_file)
        return config
