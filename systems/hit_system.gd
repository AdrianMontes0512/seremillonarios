extends Node

# ============================================================
# Sistema de golpes — funciones estáticas de validación y cálculo
# Usado por NetworkManager para autoridad del host y por el cliente
# para predicción local (client-side prediction)
# ============================================================

const HIT_RANGE: float = 1.5
const BASE_HIT_POWER: float = 12.0


# Encuentra el objetivo más cercano al atacante dentro del rango de golpe
# Retorna {"steam_id": int, "node": Node} o {} si no hay nadie en rango
static func find_closest_target(attacker_pos: Vector3, all_characters: Dictionary, exclude_steam_id: int) -> Dictionary:
	var closest_dist: float = HIT_RANGE
	var closest: Dictionary = {}
	for steam_id in all_characters:
		if steam_id == exclude_steam_id:
			continue
		var c: Node = all_characters[steam_id]
		var dist: float = attacker_pos.distance_to(c.global_position)
		if dist <= closest_dist:
			closest_dist = dist
			closest = {"steam_id": steam_id, "node": c}
	return closest


# Calcula la fuerza del golpe en dirección al objetivo, sumando el impulso acumulado
static func calculate_hit_force(attacker_pos: Vector3, target_pos: Vector3, accumulated_impulse: Vector3) -> Vector3:
	var direction: Vector3 = (target_pos - attacker_pos).normalized()
	return direction * BASE_HIT_POWER + accumulated_impulse


# Valida si el golpe es posible según la distancia entre atacante y objetivo
static func is_hit_valid(attacker_pos: Vector3, target_pos: Vector3) -> bool:
	return attacker_pos.distance_to(target_pos) <= HIT_RANGE
