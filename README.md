# L4D2 HardRealism

HardRealism is a Left 4 Death 2 mod, a SourceMod plugin.

The goal is to achieve a balance between Realism Expert and Hard Eight (mutation). It's made to be non configurable for consistency and efficiency reasons.

IMPORTANT NOTE: Put the game data l4d2_hard_realism.txt file into "sourcemod/gamedata" folder.  
IMPORTANT NOTE: HardRealism mode is designed for (based on) Realism Expert ("mp_gamemode realism" and "z_difficulty Impossible").

Brief description:
- Difficulties: Normal and Extreme.
- Get active difficulty with hr_getdifficulty command.
- Cycle between difficulties with hr_switchdifficulty command.
- Number of alive survivors is clamped to max 4.
- Special Infected size limits are relative to the active difficulty.
- Special Infected min spawn size is 2.
- Special Infected max spawn size is 5.
- Special Infected max spawn size is reduced by the number of tanks in play.
- Special Infected spawn sizes are random.
- Special Infected time limits are relative to the active difficulty.
- Special Infected min spawn time is 17s.
- Special Infected max spawn time is 35s.
- Special Infected spawn times are random.
- Special Infected spawns are randomly delayed in the range [0.4s, 1.2s].
- Always spawn wandering witches.
- Set tongue_break_from_damage_amount to same value as in Versus.
- Remove tongue victim inaccuracy.
- Set Hunter claw damage to 20.
- Set Jockey ride damage to 15.
- Set jockey health to 290.
- Set Jockey speed to 260.
- Set Charger pound damage to 20.
- Tank health is relative to the number of alive Survivors.
- Tank is faster while on fire.
- Disable tank spawn on c4m4_milltown_b.
- Set damage from crouched Common/Uncommon Infected to 2.
- Shotguns are more effective at close range against Common Infected.
- Set Hunting Rifle damage against Common/Uncommon Infected to 38.
- Set Military Sniper damage against Common/Uncommon Infected to 38.
- Set Scout damage against Common/Uncommon Infected to 76.
- Set AWP damage against Common/Uncommon Infected to 152.
- Set melee damage against Tank to 400.

## Compilation

Idealy compile with SourceMod version 1.12.  

If you don't know how to compile it into SourceMod plugin (.smx) see https://wiki.alliedmods.net/Compiling_SourceMod_Plugins

## Special contributors

[Osvaldatore](https://steamcommunity.com/id/Osvaldatore)

## Known issues

- If alive bot gets kicked alive survivors will not get recounted. To resolve this you can trigger recount by going IDLE.

## Changelog

Version scheme: MAJOR (gameplay change).MINOR.PATCH

Version 42.0.0
- Separate game fixes from the mod.

Version 41.0.0
- Adjust difficulties.
- Add a new difficulty. Max difficulty.
- Remove z_jockey_speed change.

Version 40.1.0
- Increase director AFK timeout to 30s.

Version 40.0.0
- Tank health based on difficulty.

Version 39.0.0
- Rework difficulty system.
- Slightly increase tank health.

Version 38.0.0
- Set jockey health to 290.

Version 37.1.0
- Rename Hard into Advanced difficulty.

Version 37.0.0
- Implement new difficulty system.
- Implement the better fix for Special Infected attack while staggered.
- Remove tongue victim inaccuracy.
- Set damage from crouched Common/Uncommon Infected to 2.
- Slightly increase tank health.
- Various other small changes.

Version 36.0.0
- Revert jockey health to default (325).
- Slightly reduce tank health.
- Revert disable tank spawn on c4m3_sugarmill_b.

Version 35.0.0
- Jockey is slightly faster.
- Set jockey health to 250.
- Increase tank health.
- Revert jockey leap range to the default.
- Revert tank takes double melee damage while on fire.

Version 34.1.0
- Fix common infected shove immunity while climbing.
- Disable tank spawn on c4m3_sugarmill_b and c4m4_milltown_b.

Version 34.0.0
- Set tongue_break_from_damage_amount to same value as in Versus.
- Tank takes double melee damage while on fire.

Version 33.0.1
- Fix an issue with the weapon reload fix.

Version 33.0.0
- Make tank faster while on fire.
- Decrease tank HP.

Version 32.1.0
- Fix weapon reload.

Version 32.0.0
- Halve damage from crouched Common/Uncommon Infected.
- Update gamedata.

Version 31.3.1
- Micro optimizations.
- Code edits.

Version 31.3.0
- Fix Common Infected shove immunity on landing.
- Switch to new gamedata.

Version 31.2.3
- Fix bride witch wandering.

Version 31.2.2
- Make timers more accurate.

Version 31.2.1
- Micro optimizations.

Version 31.2.0
- Fix spitter acid spread.

Version 31.1.0
- Fix jockey insta attack after failed leap.
- Micro optimizations.

Version 31.0.0
- Always spawn wandering witches.
- Fix many IDLE exploits.
- Fix incapacitated dizzines.
- Reduce afk timeout.

Version 30.7.1
- Check for the firebulletsfix.l4d2.txt game data first.

Version 30.7.0
- Stop setting sb_allow_shoot_through_survivors.

Version 30.6.1
- Edit common infected shove direction fix.
- Edit debug.

Version 30.6.0
- Simplify hit registration fix (firebulletsfix).

Version 30.5.1
 - Change error message.

Version 30.5.0
- Fix hit registration (firebulletsfix).
- Optimizations.

Version 30.4.1
- Micro optimizations.

Version 30.4.0
- hr_getmod print message in chat instead of console.

Version 30.3.5
- Micro optimizations.

Version 30.3.4
- Micro optimizations.

Version 30.3.3
- Refix special infected insta attack after shove fix not working as intended.

Version 30.3.2
- Fix special infected insta attack after shove fix not working as intended.

Version 30.3.1
- Micro optimizations.

Version 30.3.0
- Optimizations.
- Make moded weapon damage more reliable.

Version 30.2.0
- Optimizations.

Version 30.1.0
- Optimizations.

Version 30.0.0
- Set minimum delay from the special infected death and its next possible spawn.

Version 29.2.0
- Revert minimum spawn delay.
- Reorganize code.

Version 29.1.0
- Reduce spawn delays.
- Make timer callbacks void.

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
