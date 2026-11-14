class_name Tuning
extends RefCounted
## ALL difficulty / feel numbers live here, one clearly named constant each.
## Pairs named *_NORMAL / *_HARD are picked at runtime with GameSettings.pick_f / pick_i / pick_b.
## Edit a number, press Play. Nothing else needs to change.

# ---- Stamina (running) -------------------------------------------------------------------
const STAMINA_MAX: float = 100.0
const STAMINA_DRAIN_NORMAL: float = 3.5         # points per second while running
const STAMINA_DRAIN_HARD: float = 7.0
const STAMINA_REGEN_NORMAL: float = 30.0        # points per second when not running
const STAMINA_REGEN_HARD: float = 18.0
const STAMINA_REGEN_DELAY_NORMAL: float = 0.6   # seconds after running before regen starts
const STAMINA_REGEN_DELAY_HARD: float = 1.3
const STAMINA_STILL_REGEN_MULT: float = 1.6     # regen multiplier while standing still
const STAMINA_RECOVER_AT_NORMAL: float = 15.0   # tired state ends when stamina reaches this
const STAMINA_RECOVER_AT_HARD: float = 30.0
const TIRED_SPEED_MULT_NORMAL: float = 0.85     # walking speed multiplier while tired
const TIRED_SPEED_MULT_HARD: float = 0.70
const TIRED_JUMP_MULT_NORMAL: float = 0.9
const TIRED_JUMP_MULT_HARD: float = 0.75
const JUMP_STAMINA_COST_NORMAL: float = 1.5
const JUMP_STAMINA_COST_HARD: float = 4.0

# ---- Deep water --------------------------------------------------------------------------
const WATER_SURFACE_Y: float = 0.0              # sea level (ocean mesh is at y = 0)
const WATER_WADE_LIMIT_NORMAL: float = 1.3      # metres of water depth you can not wade past
const WATER_WADE_LIMIT_HARD: float = 0.9
const WATER_CURRENT_START_NORMAL: float = 0.45  # depth where the current starts pushing back
const WATER_CURRENT_START_HARD: float = 0.30
const WATER_CURRENT_PUSH_NORMAL: float = 5.0    # m/s^2 towards the shore at the wade limit
const WATER_CURRENT_PUSH_HARD: float = 9.0
const WATER_SLOW_MAX_NORMAL: float = 0.40       # fraction of speed lost at the wade limit
const WATER_SLOW_MAX_HARD: float = 0.60
const WATER_NOTICE_COOLDOWN: float = 6.0        # seconds between "the current is too strong" notices

# ---- Slippery slopes ---------------------------------------------------------------------
const SLIP_START_DEG_NORMAL: float = 32.0       # floor angle where sliding begins
const SLIP_START_DEG_HARD: float = 26.0
const SLIP_ACCEL_NORMAL: float = 9.0            # m/s^2 downhill at the steepest allowed slope
const SLIP_ACCEL_HARD: float = 16.0
const SLIP_MAX_SPEED: float = 7.5
const SLIP_UPHILL_PENALTY_NORMAL: float = 0.45  # fraction of speed lost climbing the steepest slope
const SLIP_UPHILL_PENALTY_HARD: float = 0.75

# ---- Falling rocks (hidden path to the ruins) ----------------------------------------------
const ROCKFALL_ON_NORMAL: bool = false
const ROCKFALL_ON_HARD: bool = false
const ROCKFALL_INTERVAL_NORMAL: float = 6.5     # seconds between rocks while you are in the zone
const ROCKFALL_INTERVAL_HARD: float = 3.4
const ROCKFALL_WARNING_NORMAL: float = 1.9      # seconds between the red warning disc and the hit
const ROCKFALL_WARNING_HARD: float = 1.2
const ROCKFALL_HIT_RADIUS_NORMAL: float = 1.3
const ROCKFALL_HIT_RADIUS_HARD: float = 1.9
const ROCKFALL_KNOCKBACK_NORMAL: float = 5.0
const ROCKFALL_KNOCKBACK_HARD: float = 8.0
const ROCKFALL_STAMINA_PENALTY_NORMAL: float = 25.0
const ROCKFALL_STAMINA_PENALTY_HARD: float = 45.0
const ROCKFALL_STUN_NORMAL: float = 0.4         # seconds you cannot steer after a hit
const ROCKFALL_STUN_HARD: float = 0.8
const ROCKFALL_ZONE_RADIUS: float = 6.0
const ROCKFALL_AIM_AT_PLAYER_CHANCE: float = 0.6

# ---- Symbol puzzle -----------------------------------------------------------------------
const PUZZLE_PILLARS_NORMAL: int = 3            # also the number of inscription fragments
const PUZZLE_PILLARS_HARD: int = 5
const PUZZLE_SHUFFLE_NORMAL: bool = false       # random solution order per playthrough
const PUZZLE_SHUFFLE_HARD: bool = true
const PUZZLE_LOCKOUT_NORMAL: float = 3.0        # seconds the pillars stay dead after a wrong order
const PUZZLE_LOCKOUT_HARD: float = 12.0

# ---- Guide beacons and glows -------------------------------------------------------------
const HIDE_BEACONS_NORMAL: bool = false         # floating gold diamonds above story objects
const HIDE_BEACONS_HARD: bool = true
const TREE_SIGIL_ENERGY_NORMAL: float = 2.5
const TREE_SIGIL_ENERGY_HARD: float = 0.9
const TREE_INTERACT_RADIUS_NORMAL: float = 3.4
const TREE_INTERACT_RADIUS_HARD: float = 2.4

# ---- Sanctum darkness (Hard only) --------------------------------------------------------
const SANCTUM_DARK_ON_NORMAL: bool = false
const SANCTUM_DARK_ON_HARD: bool = true
const SANCTUM_DARK_MAX_ALPHA: float = 0.97      # screen vignette strength inside the unlit sanctum
const SANCTUM_DARK_FADE_SPEED: float = 1.6

# ---- First cave (Phase 1): door puzzle, darkness, pantham (torch) ----------------------------
const CAVE_DARK_NO_TORCH: float = 0.97          # screen vignette inside the cave before you hold the pantham
const CAVE_DARK_TORCH_NORMAL: float = 0.50      # vignette strength once the pantham burns
const CAVE_DARK_TORCH_HARD: float = 0.72
const CAVE_TORCH_RANGE_NORMAL: float = 11.0     # metres the pantham light reaches
const CAVE_TORCH_RANGE_HARD: float = 7.5
const CAVE_TORCH_ENERGY_NORMAL: float = 2.2
const CAVE_TORCH_ENERGY_HARD: float = 1.7
const CAVE_LOCKOUT_NORMAL: float = 3.0          # seconds the door sockets stay dead after a wrong order
const CAVE_LOCKOUT_HARD: float = 10.0
