# Simulator — what it is in this project

Not a second game. A headless run of the real game logic, no graphics,
so balance is tested before art exists:

1. **Wanted escalation sim:** scripted crime rate (kills/destroys per
   minute) → plot stars over time, active enemies vs. the cap table in
   `data/enemies_world_wanted.json`, time-to-clear at decay 600 frames.
   This is where the fractional-wanted fix gets verified.
2. **Economy sim:** cash/minute from peds (10/15), cars (25), cop 20 /
   SWAT 40 / tank 100, combo multiplier min(5, 1+combo*0.5), against
   upgrade costs floor(base * 1.4^level) → runs-to-afford each upgrade.
3. **Traffic / ped density sim:** 18 cars (50% AI) + 50 peds in a
   3600-unit, 340-block / 100-road grid → collision and flee behaviour
   with no player input, checking the city doesn't gridlock or empty.
4. **Combat sim:** each weapon in `data/weapons.json` vs. cop/SWAT/tank
   HP → time-to-kill table. (Expect SNIPER/ROCKET outliers by design.)

Runs in-engine once an engine is picked, reading the same `data/*.json`
the game reads — one source of truth, no re-typed numbers.
