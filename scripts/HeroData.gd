class_name HeroData
extends Resource
## HeroData.gd — Custom Resource для работы с героями в Инспекторе Godot (.tres).

@export var id: String = ""
@export var name: String = ""
@export var role: String = ""
@export var primary_stat: String = "str"
@export var is_melee: bool = true

@export_group("Stats")
@export var base_str: float = 20.0
@export var base_agi: float = 20.0
@export var base_int: float = 20.0
@export var str_gain: float = 2.0
@export var agi_gain: float = 2.0
@export var int_gain: float = 2.0

@export_group("Combat")
@export var base_damage: float = 20.0
@export var armor: float = 2.0
@export var move_speed: float = 7.5

@export_group("Abilities")
@export var abilities: Array[Dictionary] = []
