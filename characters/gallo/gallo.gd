# Gallo — color rojo — difícil de derribar, combate directo
extends "res://characters/base/ragdoll_character.gd"


func _ready() -> void:
	super._ready()
	# Masa media-alta para resistencia al derribo
	mass = 75.0
	# Velocidad de movimiento moderada-alta
	move_speed = 6.0
	# Salto moderado
	jump_force = 7.5
	# Umbral alto antes de entrar en ragdoll
	ragdoll_threshold = 20.0
	# Absorbe bien los impactos
	impulse_absorption = 0.4
	# Poco multiplicador de lanzamiento, difícil de volar
	launch_multiplier = 0.7
	print("Personaje: Gallo (rojo)")
