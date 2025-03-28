--[[
    DamageFormulas.lua
    
    PURPOSE:
    Documents the damage calculation formulas used in the combat system.
    Serves as reference for designers and developers.
    
    This is a documentation-only module and does not contain executable code.
]]

--[[
============================================================================
DAMAGE CALCULATION SYSTEM
============================================================================

The combat system uses a stat-based damage calculation system that accounts
for attacker power, target defense, critical hits, level differences, and 
other modifiers.

============================================================================
1. BASE FORMULA
============================================================================

The general damage formula is:

Final Damage = Base Damage × Power Multiplier × Critical Multiplier × Level Scaling × Defense Mitigation

Where:
- Base Damage: The raw damage amount specified in the ability or effect
- Power Multiplier: Scaling based on attacker's Power or Focus stat
- Critical Multiplier: Additional damage from critical hits (based on Ferocity)
- Level Scaling: Adjustment based on level difference between attacker and target
- Defense Mitigation: Reduction based on target's Defense stat

============================================================================
2. POWER SCALING
============================================================================

Power Multiplier = 1 + (Power × 0.01)

Where:
- Power is the attacker's Power stat for direct damage
- Focus is used instead of Power for damage-over-time effects

Examples:
- Power of 10 gives a 1.1× multiplier (10% increase)
- Power of 50 gives a 1.5× multiplier (50% increase)
- Power of 100 gives a 2× multiplier (100% increase)

============================================================================
3. CRITICAL HITS
============================================================================

Critical hits are determined by the attacker's Precision stat:

Critical Chance = Precision ÷ 100

When a critical hit occurs, damage is multiplied by the Ferocity multiplier:

Critical Multiplier = Ferocity ÷ 100

Examples:
- Default Ferocity of 150 gives a 1.5× multiplier (50% more damage)
- Ferocity of 200 gives a 2× multiplier (100% more damage)

Note: Periodic damage (DoT) effects do not critically hit.

============================================================================
4. LEVEL SCALING
============================================================================

Damage is adjusted based on the level difference between attacker and target:

Level Scaling Factor = 1 + [Level Difference × DAMAGE_FACTOR_PER_LEVEL]

The scaling factor is capped at MAX_LEVEL_MODIFIER in both directions.

Examples with DAMAGE_FACTOR_PER_LEVEL = 0.05 and MAX_LEVEL_MODIFIER = 0.5:
- Same level (diff = 0): 1.0× multiplier (no change)
- Attacker 5 levels higher (diff = +5): 1.25× multiplier (25% more damage)
- Attacker 10+ levels higher (diff = +10): 1.5× multiplier (capped at 50% more)
- Attacker 5 levels lower (diff = -5): 0.75× multiplier (25% less damage)
- Attacker 10+ levels lower (diff = -10): 0.5× multiplier (capped at 50% less)

============================================================================
5. DEFENSE MITIGATION
============================================================================

Defense reduces incoming damage using a diminishing returns formula:

Defense Mitigation = Defense ÷ (Defense + K × Target Level)

Where K is the DEFENSE_DENOMINATOR_BASE (default: 50).

The calculated mitigation is capped at MAX_DEFENSE_MITIGATION (default: 75%).

Final Defense Multiplier = (1 - Defense Mitigation)

Examples at level 1:
- Defense of 10 gives mitigation of 10 ÷ (10 + 50) = 16.7% (multiplier of 0.833)
- Defense of 50 gives mitigation of 50 ÷ (50 + 50) = 50% (multiplier of 0.5)
- Defense of 150 gives mitigation of 150 ÷ (150 + 50) = 75% (capped, multiplier of 0.25)

For level 10:
- Defense of 50 gives mitigation of 50 ÷ (50 + 500) = 9.1% (multiplier of 0.909)
- Defense of 250 gives mitigation of 250 ÷ (250 + 500) = 33.3% (multiplier of 0.667)
- Defense of 1500 gives mitigation of 1500 ÷ (1500 + 500) = 75% (capped, multiplier of 0.25)

Level Difference Effect on Defense:
When the target is higher level than the attacker, the target's defense is more effective:
Defense Effectiveness = 1 + [-Level Difference × DEFENSE_FACTOR_PER_LEVEL]
(capped at MAX_LEVEL_MODIFIER)

============================================================================
6. CONDITION DAMAGE (DOT)
============================================================================

For damage over time effects:

- Focus is used instead of Power for the Power Multiplier
- Critical hits do not apply
- Expertise increases tick frequency (decreases time between ticks)

Tick Interval = Base Tick Rate ÷ Expertise

Where:
- Base Tick Rate is defined in the condition (default 1 second)
- Expertise is divided by 100 (e.g., 150 Expertise = 1.5× multiplier)

============================================================================
7. HEALING CALCULATION
============================================================================

Healing follows a similar formula to damage:

Final Healing = Base Healing × Healing Power Multiplier × Critical Multiplier × Level Scaling

Where:
- Base Healing: The raw healing amount specified in the ability or effect
- Healing Power Multiplier: 1 + (Healing Power × 0.01)
- Critical Multiplier: Additional healing from critical heals (based on Ferocity)
- Level Scaling: Adjustment based on level difference (half effect compared to damage)

============================================================================
8. STAT LEVEL SCALING
============================================================================

Base stats scale with entity level:

Scaled Stat = Base Stat × (1 + (Level - 1) × STAT_MULTIPLIER_PER_LEVEL)

With STAT_MULTIPLIER_PER_LEVEL = 0.1:
- Level 1: Base value (no scaling)
- Level 10: 1.9× base value (90% increase)
- Level 20: 2.9× base value (190% increase)
- Level 50: 5.9× base value (490% increase)

Scalable stats include:
- Power
- Defense
- Focus
- Healing Power
- Max Health
- Max Energy

============================================================================
9. STAT RATINGS AND DIMINISHING RETURNS
============================================================================

Rating-based stats (Precision, Ferocity, Expertise) use diminishing returns:

Precision:
- Base value: 5% critical chance
- Rating per 1%: 20 at level 1, scales with level
- Soft cap: 50% critical chance
- Hard cap: 75% critical chance

Ferocity:
- Base value: 150% critical damage multiplier
- Rating per 1%: 15 at level 1, scales with level

Expertise:
- Base value: 100% condition effectiveness
- Rating per 1%: 10 at level 1, scales with level

The rating formula includes level scaling:
Rating per 1% = Base Rating × (1 + (Level - 1) × RATING_INCREASE_PER_LEVEL)

With RATING_INCREASE_PER_LEVEL = 0.1:
- Level 1: Base rating requirement
- Level 10: 1.9× base rating requirement
- Level 20: 2.9× base rating requirement
- Level 50: 5.9× base rating requirement

============================================================================
10. TUNABLE VALUES
============================================================================

The following values can be adjusted in Constants.lua:

Level Scaling constants:
- STAT_MULTIPLIER_PER_LEVEL: 0.1 (10% stat increase per level)
- DAMAGE_FACTOR_PER_LEVEL: 0.05 (5% damage increase/decrease per level difference)
- DEFENSE_FACTOR_PER_LEVEL: 0.05 (5% defense effectiveness per level difference)
- MAX_LEVEL_MODIFIER: 0.5 (50% maximum level effect)
- RATING_INCREASE_PER_LEVEL: 0.1 (10% more rating needed per level)
- DEFENSE_DENOMINATOR_BASE: 50 (base value in defense formula denominator)
- MAX_DEFENSE_MITIGATION: 0.75 (75% maximum damage reduction from defense)
]]

-- This module is for documentation only and does not need to return anything
return {}
