# Caballo — color azul — el más pesado, lento pero devastador
extends "res://characters/base/ragdoll_character.gd"


func _ready() -> void:
	super._ready()
	# Masa máxima del roster, muy difícil de mover
	mass = 110.0
	# Movimiento lento por su gran peso
	move_speed = 4.5
	# Salto limitado por la masa
	jump_force = 6.0
	# Umbral muy alto, casi imposible de derribar
	ragdoll_threshold = 25.0
	# Mínima absorción: los golpes que recibe se sienten
	impulse_absorption = 0.2
	# Lanzamiento muy reducido, no sale volando fácilmente
	launch_multiplier = 0.5
	print("Personaje: Caballo (azul)")
