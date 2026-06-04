# Mapache — color verde — pequeño y ligero, vuela lejos, escapa por física
extends "res://characters/base/ragdoll_character.gd"


func _ready() -> void:
	super._ready()
	# Masa muy baja, el más ligero del roster
	mass = 45.0
	# Movimiento muy rápido gracias a su ligereza
	move_speed = 8.5
	# Salto alto, casi acrobático
	jump_force = 10.0
	# Umbral bajo: entra en ragdoll con muy poco impacto
	ragdoll_threshold = 8.0
	# Casi nula absorción: cualquier golpe lo afecta de lleno
	impulse_absorption = 0.1
	# Multiplicador alto: sale disparado con cada impacto
	launch_multiplier = 2.0
	print("Personaje: Mapache (verde)")
