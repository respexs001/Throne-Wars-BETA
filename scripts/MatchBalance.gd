class_name MatchBalance
extends RefCounted
## Alpha pacing is separate from display and user preferences.
const VERSION: String = preload("res://scripts/AppVersion.gd").VERSION
const PRIMARY_HEROES: Array[String] = ["titan", "pyro", "ranger", "smugr"]
const WAVE_INTERVAL: float = 25.0
const FIRST_WAVE: float = 3.0
const MAX_LANE_CREEPS_PER_TEAM: int = 14

static func wave_size(seconds: float) -> int:
    return 5 if seconds < 300.0 else (6 if seconds < 600.0 else 7)
const PASSIVE_GOLD: float = 3.0
const TOWER_HP: float = 2100.0
const TOWER_HP_PER_TIER: float = 220.0
const THRONE_HP: float = 6400.0
const TOWER_DAMAGE: float = 115.0
const TOWER_ARMOR: float = 5.0
const BACKDOOR_REGEN: float = 3.0
const GUARDIAN_FIRST: float = 180.0
const GUARDIAN_RESPAWN: float = 180.0
const GUARDIAN_HP: float = 3000.0
const GUARDIAN_DAMAGE: float = 65.0
const MASTERY_THRESHOLDS: Array[int] = [300, 900, 1800]

static func creep_pressure(seconds: float) -> float:
    return 1.0 + clampf((seconds - 480.0) / 120.0, 0.0, 2.0)
