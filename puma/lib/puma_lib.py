import yaml, boto, os
from boto.ec2.connection import EC2Connection


class Puma:
    def __init__(self):
        self.puma_dir = os.environ["HOME"] + "/puma"
    def parse_config(self):
        config_file = file(self.puma_dir + "/config.yml", "r")
        self.config = yaml.load(config_file)
        return self.config

    def connect(self):
        #TODO add some error handling
       self.conn = EC2Connection(self.config["access_id"], self.config["access_secret"])
       self.conn = EC2Connection()

    def image_list(self):
        self.images = self.conn.get_all_images

    def run_instance(self):
        #TODO loop through the list images and find the matching image
        image = self.images[0]
        image.run()
