# L4D2 HardRealism

HardRealism is a Left 4 Death 2 mod, a SourceMod plugin.

The goal is to achieve a balance between Realism Expert and Hard Eight (mutation). It's made to be non configurable for consistency and efficiency reasons.

## Important note

HardRealism mode is designed for `mp_gamemode "realism"` and `z_difficulty "Impossible"` (realism expert).

## Special contributors

[Osvaldatore](https://steamcommunity.com/id/Osvaldatore)

## Changelog

Version scheme: MAJOR (gameplay change).MINOR.PATCH

Version 18.1.0
- Improved bots behavior.

Version 18.0.0
- Many changes to special infected health.
- Many changes to special infected damage.
- Melee damage to tank is set to 400.
- Horde max spawn time reduced to 120.
- Improve debug.
- Additional small changes.

Version 17.0.0
- Reduced jockey leap range.

Version 16.0.0
- Decrease tank health.
- Increase max spawn time.

Version 15.0.0
- Use new formula for tank health.

Version 14.0.0
- Limit max tank health.

Version 13.0.0
- Increase the minimum special infected spawn size.
- Reorganize code.
  
Version 12.0.0
- Decrease max spawn time.

Version 11.1.2
- Improve debug.

Version 11.1.1
- Micro optimizations.

Version 11.1.0
- Optimizations.

Version 11.0.0
- Revert spawn safety range change.
- Reduce shotgun effectiveness against commons.

Version 10.0.0
- Spawn safety range increased.
- Shotguns are more effective against commons.
- Removed gamemode and difficulty guard.

Version 9.0.0
- Reduce charger health.

Version 8.1.0
- Small change.

Version 8.0.1
- Micro optimizations.

Version 8.0.0
- Reduce charger health.

Version 7.0.0
- Rework and rebalance values relative to the alive survivors.

Version 6.0.0
- Rebalance spawn times.

Version 5.0.1
- Small change.

Version 5.0.0
- Rebalance special infected spawn weights.
- Reduce jockey claw damage by 50%.
- Reduce spawn times on 1 alive survivor.
- Fix hunter pounce damage.

Version 4.2.1
- Small change.

Version 4.2.0
- Reduce max spawn delay.
- Check client validity on tank spawn.
- Micro optimizations.
  
Version 4.1.0
- Add gamemode and difficulty guard. Allow only Realism Expert.

Version 4.0.0
- Increase special infected spawn times on 4 alive survivors.

Version 3.0.0
- Tank's hp is not randomized anymore.

Version 2.0.1
- Micro optimizations.

Version 2.0.0
- General rework and gameplay changes.
- Fix miscount of alive survivors on idle.
- Micro optimizations.
- Improve debug.

Version 1.2.2
- Fix oversight.

Version 1.2.1
- Optimizations.

Version 1.2.0
- Change the way tank hp is set.
- Additional small changes.
- Note: The old range [3200, 16000] was referring to z_tank_health values.

Version 1.1.1
- Small change, has no effect.

Version 1.1.0
- Remove gamemode guard.
- Improve debug.
- Round tmp weights to nearest.
