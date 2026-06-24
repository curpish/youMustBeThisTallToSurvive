# lists our explicit gameplay events to announce for other systems to react to

extends Node

signal fling
signal rider_lost
signal overheated
signal governor_priming  # screwdriver pulled; bypass arming
signal governor_overridden  # screwdriver seated; bypass actually engaged
signal big_stop
signal day_ended
signal ride_closed
