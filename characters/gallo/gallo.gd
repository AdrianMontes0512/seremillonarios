# Gallo — color rojo — difícil de derribar, combate directo
extends "res://characters/base/ragdoll_character.gd"


func _ready() -> void:
	# Masa media-alta: cuesta tumbarlo
	mass = 75.0
	# Movimiento moderado-alto
	move_force = 6.5
	jump_force = 6.0
	# El más estable: se endereza fuerte y resiste el derribo
	balance_strength = 20.0
	hover_strength = 38.0
	ragdoll_threshold = 20.0
	launch_multiplier = 0.7
	stun_time = 1.1
	super._ready()
	print("Personaje: Gallo (rojo) — active ragdoll")
