# Gato — color morado — deformable y flexible, el más impredecible
extends "res://characters/base/ragdoll_character.gd"


func _ready() -> void:
	super._ready()
	# Masa ligera-media, ágil pero no frágil
	mass = 60.0
	# Velocidad buena, segundo más rápido del roster
	move_speed = 7.0
	# Salto alto, comportamiento acrobático
	jump_force = 9.0
	# Umbral medio-bajo: entra en ragdoll con cierta facilidad
	ragdoll_threshold = 12.0
	# Absorción moderada para comportamiento impredecible
	impulse_absorption = 0.35
	# Multiplicador moderado-alto para vuelos caóticos
	launch_multiplier = 1.3
	# Aplicar configuración de articulaciones flexibles al inicio
	configure_flexible_joints()
	print("Personaje: Gato (morado)")


func configure_flexible_joints() -> void:
	# Configurar articulaciones más sueltas para comportamiento más flexible
	if not has_node("Skeleton3D"):
		return
	for bone in $Skeleton3D.get_children():
		if bone is PhysicalBone3D:
			bone.joint_type = PhysicalBone3D.JOINT_TYPE_CONE_TWIST
