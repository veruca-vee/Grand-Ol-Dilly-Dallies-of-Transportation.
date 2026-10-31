class_name Economy
extends RefCounted

# ENGINE CORE — money/score state and the combo rule: consecutive
# scoring events inside a time window build a multiplier,
# min(cap, 1 + count * 0.5); the window and cap are game config
# (from the game's data file — G.O.D.O.T: data's combo block,
# window 120 frames, cap 5).
#
# Extracted from gate3d_main.gd in the Engine Core gate (step 4).
# award() applies the exact int(base * mult) truncation the source
# rules use — scoring math is identical, only its home moved.

var cash: int = 0
var score: int = 0
var combo_count: int = 0
var combo_frames: int = 0
var combo_window: int = 120
var combo_cap: float = 5.0

func setup(combo_cfg: Dictionary) -> void:
	combo_window = int(combo_cfg.get("window_frames", 120))

func combo_mult_now() -> float:
	if combo_count > 1:
		return minf(combo_cap, 1.0 + combo_count * 0.5)
	return 1.0

# Register a scoring event; returns the multiplier to pay out at.
func add_combo() -> float:
	combo_count += 1
	combo_frames = combo_window
	return combo_mult_now()

# Per-physics-frame combo decay.
func tick_combo() -> void:
	if combo_frames > 0:
		combo_frames -= 1
		if combo_frames <= 0:
			combo_count = 0

func award(base_cash: float, base_score: float, mult: float) -> void:
	cash += int(base_cash * mult)
	score += int(base_score * mult)

func add_cash(n: int) -> void:
	cash += n

func add_score(n: int) -> void:
	score += n
