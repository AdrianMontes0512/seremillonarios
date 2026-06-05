extends Node
class_name GrabController

# ============================================================================
# GRAB CONTROLLER — se adjunta a CADA mano/brazo (uno por brazo).
# Si el jugador MANTIENE el botón de agarre y la mano está tocando otro cuerpo
# físico, crea un PinJoint3D por código que ata la mano al objeto. Al soltar,
# destruye el joint.
#
# Asignar:
#   hand_body  = el RigidBody3D del brazo (o un RigidBody "mano" si lo separas)
#   action     = "grab_left" o "grab_right"
# La mano debe tener contact_monitor=true y max_contacts_reported>0 (lo fuerza
# este script en _ready) para que dispare body_entered/body_exited.
# ============================================================================

@export var hand_body: RigidBody3D
@export var action: String = "grab_left"

# Cuerpos que la mano está tocando ahora mismo (candidatos a agarrar).
var _touching: Array[Node3D] = []
# Joint activo del agarre (null si no hay agarre).
var _grab_joint: PinJoint3D = null
var _grabbed: Node3D = null


func _ready() -> void:
	if hand_body == null:
		push_error("GrabController: asigna hand_body")
		return
	hand_body.contact_monitor = true
	if hand_body.max_contacts_reported < 4:
		hand_body.max_contacts_reported = 4
	hand_body.body_entered.connect(_on_body_entered)
	hand_body.body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node) -> void:
	# Solo cuerpos físicos agarrables (RigidBody3D); evita el propio personaje.
	if body is RigidBody3D and body != hand_body and not _is_own_skeleton(body):
		if not _touching.has(body):
			_touching.append(body)


func _on_body_exited(body: Node) -> void:
	_touching.erase(body)


func _physics_process(_delta: float) -> void:
	var holding := Input.is_action_pressed(action)

	if holding and _grab_joint == null and not _touching.is_empty():
		# Agarrar el primer cuerpo en contacto.
		_create_grab(_touching[0])
	elif not holding and _grab_joint != null:
		# Soltar.
		_release_grab()


# Crea el PinJoint3D que une la mano con el objeto, en la posición de la mano.
func _create_grab(target: Node3D) -> void:
	if not is_instance_valid(target):
		return
	_grab_joint = PinJoint3D.new()
	# El joint vive en el mundo; lo posicionamos en el punto de la mano.
	get_tree().current_scene.add_child(_grab_joint)
	_grab_joint.global_position = hand_body.global_position
	# node_a / node_b son NodePaths RELATIVOS al propio PinJoint3D.
	_grab_joint.node_a = _grab_joint.get_path_to(hand_body)
	_grab_joint.node_b = _grab_joint.get_path_to(target)
	_grabbed = target


func _release_grab() -> void:
	if is_instance_valid(_grab_joint):
		_grab_joint.queue_free()
	_grab_joint = null
	_grabbed = null


# Evita agarrarse a sí mismo: ignora hermanos bajo el mismo Player raíz.
func _is_own_skeleton(body: Node) -> bool:
	var my_root := hand_body.owner
	return my_root != null and my_root.is_ancestor_of(body)
