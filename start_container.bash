#!/bin/bash

docker run -p 80:80 -p 5060:5060/udp -p 5061:5061/udp -p 11000-11010/udp -v ~/freepbx-test/backup:/backup -it freepbx-test

