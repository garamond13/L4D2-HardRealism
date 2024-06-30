# L4D2 HardRealism

HardRealism is a Left 4 Death 2 mod, a SourceMod plugin.

The goal is to achieve a balance between Realism Expert and Hard Eight (mutation). It's made to be non configurable for consistency and efficiency reasons.

IMPORTANT NOTE: HardRealism mode is designed for Realism Expert ("mp_gamemode realism" and "z_difficulty Impossible").

## Compilation

Depends on (required) [Actions](https://forums.alliedmods.net/showthread.php?p=2771520#post2771520).  
Idealy compile with SourceMod version 1.12.  

If you don't know how to compile it into SourceMod plugin (.smx) see https://wiki.alliedmods.net/Compiling_SourceMod_Plugins

## Special contributors

[Osvaldatore](https://steamcommunity.com/id/Osvaldatore)

## Known issues

- If alive bot gets kicked alive survivors will not get recounted. To resolve this you can trigger recount by going IDLE.

## Changelog

Version scheme: MAJOR (gameplay change).MINOR.PATCH

Version 29.0.2
- Rework friendly damage on charger carry fix.

Version 29.0.1
- Minor change.

Version 29.0.0
- Fix common infected shove direction.
- Fix special infected insta attack after shove.
- Fix friendly damage on charger carry.
- Fix smoker insta grab.
- Revert some bot improvements.
- Various minor changes.

Version 28.2.1
- Micro optimization.

Version 28.2.0
- Auto switch mod to Normal on server hibernation (Requires min SourceMod v1.12.0.7132).

Version 28.1.0
- In the hr_switchmod message show the client name.

Version 28.0.1
- Fix message on mod switch not showing to all clients.
- Reorganize code.

Version 28.0.0
- Add MaxedOut mod.
- Add hr_getmod command.
- Add hr_switchmod command.

Version 27.0.0
- Buff snipers against uncommon infected.

Version 26.0.0
- Reduce jockey health.

Version 25.0.0
- Rescale tank health.
- Turn float check is not zero into stock function.

Version 24.0.1
- Optimize clamp function.

Version 24.0.0
- Clamp alive survivors between 2 and 4.

Version 23.0.1
- Micro optimizations.

Version 23.0.0
- If tank is aggroed on survivors, tanks will be added to total SI count.

Version 22.0.0
- Revert horde max spawn time reduction.

Version 21.3.0
- Optimize special infected spawning.

Version 21.2.0
- Increase minimum spawn delay.

Version 21.1.0
- Optimize on take damage.

Version 21.0.0
- Revert special infected health changes.
- Revert weapon damage changes.
- Rework sniper damage against common and uncommon infected.

Version 20.0.0
- SMG increased damage.
- SCAR increased damage.

Version 19.0.0
- Reduce tank health.

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
