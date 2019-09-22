#!/usr/bin/python
import RPi.GPIO as GPIO
from time import sleep

# Setup the PI
GPIO.setmode(GPIO.BOARD)
GPIO.setwarnings(False)
GPIO.setup(11, GPIO.OUT)

# Toggle the reset pin
GPIO.output(11, True)
sleep(.25)
GPIO.output(11, False)

# Cleanup 
GPIO.cleanup()

