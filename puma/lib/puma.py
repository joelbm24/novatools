#! /usr/bin/python

import yaml, boto, os
from boto.ec2.regioninfo import RegionInfo

class Puma:
    def __init__(self):
        self.puma_dir = os.environ["HOME"] + "/.puma"
    def config(self):
        config_file = file(self.puma_dir + "/config.yml", "r")
        return yaml.load(config_file)

    def connect(self):
        #TODO add some error handling
        return boto.connect_ec2(aws_access_key_id=self.config["access_id"],
                                aws_secret_access_key=self.config["access_secret"],
                                is_secure=False,
                                region=RegionInfo(None, 'nova', "10.255.24.10"),
                                port=8773,
                                path='/services/Cloud')

    def image_list(self):
        self.images = self.connect.get_all_images()

    def run_instance(self, image_name):
        #TODO loop through the list images and find a matching user specified image
        image = self.images[0]
        #image.run()

