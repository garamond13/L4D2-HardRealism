/*
IMPORTANT NOTE: HardRealism mode is designed for Realism Expert ("mp_gamemode realism" and "z_difficulty Impossible").

Version description

Special Infected (SI) order = Smoker, Boomer, Hunter, Spitter, Jockey, Charger.

Version 31
- Normal (default) mod and MaxedOut mod.
- Get active mode with hr_getmod command.
- Switch between mods with hr_switchmod command.
- Number of alive survivors is clamped between 2 and 4 (Normal mod).
- Special Infected limit is relative to the number of alive Survivors (Normal mod).
- Special Infected max spawn size is relative to the number of alive Survivors (Normal mod).
- Special Infected max spawn size is reduced by the number of tanks in play.
- Special Infected spawn size minimum is 3 (Normal mod).
- Special Infected spawn sizes are random (Normal mod).
- Special Infected spawn limits in SI order are 2, 1, 2, 1, 2, 2.
- Special Infected spawn weights in SI order are 60, 100, 60, 100, 60, 60.
- Special Infected spawn weight reduction factors in SI order are 0.5, 1.0, 0.5, 1.0, 0.5, 0.5.
- Special Infected spawns are randomly delayed in the range [0.4s, 2.2s].
- Always spawn wandering witches.
- Set Hunter claw damage to 20.
- Set Jockey health to 300.
- Set Jockey ride damage to 15.
- Set Jockey leap range to 150.
- Set Charger pound damage to 20.
- Tank health is relative to the number of alive Survivors (Normal mod).
- Shotguns are more effective at close range against Common Infected.
- Set Hunting Rifle damage against Common/Uncommon Infected to 38.
- Set Military Sniper damage against Common/Uncommon Infected to 38.
- Set Scout damage against Common/Uncommon Infected to 76.
- Set AWP damage against Common/Uncommon Infected to 152.
- Set melee damage against Tank to 400.
- Fix many IDLE exploits.
- Fix incapacitated dizziness.
- Fix hit registration (firebulletsfix).
- Fix Common Infected shove direction.
- Fix Jockey insta attack after failed leap.
- Fix Special Infected insta attack after shove.
- Fix friendly fire while Charger carries survivor.
- Fix Smoker insta grab.
*/

// Note that in SourcePawn variables and arrays should be zero initialized by default.

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <dhooks>
#include <actions>

#pragma semicolon 1
#pragma newdecls required

// MAJOR (gameplay change).MINOR.PATCH
#define VERSION "31.1.0"

// Debug switches
#define DEBUG_DAMAGE_MOD 0
#define DEBUG_SI_SPAWN 0
#define DEBUG_TANK_HP 0
#define DEBUG_SHOVE 0
#define DEBUG_CHARGER 0
#define DEBUG_SMOKER 0
#define DEBUG_FIREBULLETSFIX 0
#define DEBUG_JOCKEY 0

// Teams
#define TEAM_SURVIVORS 2
#define TEAM_INFECTED 3

// Zombie classes
#define ZOMBIE_CLASS_SMOKER 1
#define ZOMBIE_CLASS_BOOMER 2
#define ZOMBIE_CLASS_HUNTER 3
#define ZOMBIE_CLASS_SPITTER 4
#define ZOMBIE_CLASS_JOCKEY 5
#define ZOMBIE_CLASS_CHARGER 6
#define ZOMBIE_CLASS_TANK 8

// Special infected spawner
//

// Special infected types (for indexing).
// Keep the same order as zombie classes.
#define SI_TYPES 6
#define SI_INDEX_SMOKER 0
#define SI_INDEX_BOOMER 1
#define SI_INDEX_HUNTER 2
#define SI_INDEX_SPITTER 3
#define SI_INDEX_JOCKEY 4
#define SI_INDEX_CHARGER 5

#if (DEBUG_SI_SPAWN || DEBUG_SHOVE || DEBUG_JOCKEY)
// Keep the same order as zombie classes.
static const char g_debug_si_indexes[SI_TYPES][] = { "SI_INDEX_SMOKER", "SI_INDEX_BOOMER", "SI_INDEX_HUNTER", "SI_INDEX_SPITTER", "SI_INDEX_JOCKEY", "SI_INDEX_CHARGER" };
#endif

Handle g_hspawn_timer;
int g_alive_survivors;
int g_si_limit;
int g_si_recently_killed[SI_TYPES];

//

// Damage mod
Handle g_hweapon_trie;

// Special infected insta attack after shove fix.
// Jockey insta attack after failed leap fix.
//

enum struct Clear_in_attack2_timer
{
	int userid;
	Handle htimer;
}

// Set array size to the max possible special infected limit.
Clear_in_attack2_timer g_clear_in_attack2_timers[5];

//

// Is MaxedOut mod active? If not Normal mod will be active.
bool g_is_maxedout;

// Only used internaly.
Handle g_hhr_istankinplay;

// Used by firebulletsfix.
Handle g_hweapon_shoot_position;
float g_old_weapon_shoot_position[MAXPLAYERS + 1][3];

public Plugin myinfo = {
	name = "L4D2 HardRealism",
	author = "Garamond",
	description = "HardRealism mod",
	version = VERSION,
	url = "https://github.com/garamond13/L4D2-HardRealism"
};

public void OnPluginStart()
{
	// For firebulletsfix.
	Handle hgame_data = LoadGameConfigFile("firebulletsfix.l4d2");
	g_hweapon_shoot_position = DHookCreate(GameConfGetOffset(hgame_data, "Weapon_ShootPosition"), HookType_Entity, ReturnType_Vector, ThisPointer_CBaseEntity, on_weapon_shoot_position);
	CloseHandle(hgame_data);

	// Map modded damage.
	g_hweapon_trie = CreateTrie();
	SetTrieValue(g_hweapon_trie, "weapon_hunting_rifle", 38.0);
	SetTrieValue(g_hweapon_trie, "weapon_sniper_military", 38.0);
	SetTrieValue(g_hweapon_trie, "weapon_sniper_scout", 76.0);
	SetTrieValue(g_hweapon_trie, "weapon_sniper_awp", 152.0);

	// Hook game events.
	HookEvent("player_left_safe_area", event_player_left_safe_area, EventHookMode_PostNoCopy);
	HookEvent("player_spawn", event_player_spawn);
	HookEvent("player_death", event_player_death);
	HookEvent("tank_spawn", event_tank_spawn, EventHookMode_Pre);
	HookEvent("player_shoved", event_player_shoved);
	HookEvent("charger_carry_start", event_charger_carry_start);
	HookEvent("charger_carry_end", event_charger_carry_end);
	HookEvent("tongue_grab", event_tongue_grab);
	HookEvent("round_end", event_round_end, EventHookMode_PostNoCopy);

	// IDLE exploits fix.
	// Disable IDLE command.
	static const char go_away_from_keyboard[] = "go_away_from_keyboard";
	SetCommandFlags(go_away_from_keyboard, GetCommandFlags(go_away_from_keyboard) | FCVAR_CHEAT);
	
	// Register new console commands.
	RegConsoleCmd("hr_getmod", command_hr_getmod);
	RegConsoleCmd("hr_switchmod", command_hr_switchmod);
	
	g_hhr_istankinplay = CreateConVar("hr_istankinplay", "0");
}

public void OnConfigsExecuted()
{	
	// Disbale director spawn special infected.
	SetConVarInt(FindConVar("z_smoker_limit"), 0);
	SetConVarInt(FindConVar("z_boomer_limit"), 0);
	SetConVarInt(FindConVar("z_hunter_limit"), 0);
	SetConVarInt(FindConVar("z_spitter_limit"), 0);
	SetConVarInt(FindConVar("z_jockey_limit"), 0);
	SetConVarInt(FindConVar("z_charger_limit"), 0);

	// Workaround. It will be halved by on_take_damage().
	// Default 5, it will be multiplied by 3 on Realsim Expert.
	SetConVarInt(FindConVar("z_pounce_damage"), 10);

	// Defualt 325.
	SetConVarInt(FindConVar("z_jockey_health"), 300);

	// Default 200.
	SetConVarInt(FindConVar("z_jockey_leap_range"), 150);

	// Default 4, it will be multiplied by 3 on Realsim Expert.
	SetConVarInt(FindConVar("z_jockey_ride_damage"), 5);

	// Default 15.
	SetConVarInt(FindConVar("z_charger_pound_dmg"), 20);

	// Set to Morning(2), to always spawn wandering witches.
	// Default -1.
	SetConVarInt(FindConVar("sv_force_time_of_day"), 2);

	// Default 100.
	SetConVarInt(FindConVar("z_shotgun_bonus_damage_range"), 150);

	// Incapacitated dizziness fix.
	//

	// Default 2.0.
	SetConVarFloat(FindConVar("survivor_incapacitated_dizzy_severity"), 0.0);

	// Default 2.5.
	SetConVarFloat(FindConVar("survivor_incapacitated_dizzy_timer"), 0.0);

	//

	// Compensate for IDLE exploits fix.
	// Default 45.
	SetConVarInt(FindConVar("director_afk_timeout"), 20);
}

Action command_hr_getmod(int client, int args)
{
	if (g_is_maxedout)
		PrintToChat(client, "[HR] MaxedOut mod is active.");
	else // Normal mod.
		PrintToChat(client, "[HR] Normal mod is active.");
	return Plugin_Handled;
}

Action command_hr_switchmod(int client, int args)
{
	g_is_maxedout = !g_is_maxedout;
	if (g_is_maxedout) {
		g_alive_survivors = 4;
		g_si_limit = 5;
		PrintToChatAll("[HR] MaxedOut mod is activated by %N.", client);
	}
	else { // Normal mod.
		count_alive_survivors();
		PrintToChatAll("[HR] Normal mod is activated by %N.", client);
	}
	return Plugin_Handled;
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (!strcmp(classname, "infected"))
		SDKHook(entity, SDKHook_OnTakeDamage, on_take_damage_infected);
}

Action on_take_damage_infected(int victim, int& attacker, int& inflictor, float& damage, int& damagetype)
{
	if (attacker == inflictor && attacker > 0 && attacker <= MaxClients) {
		char classname[24];
		GetClientWeapon(attacker, classname, sizeof(classname));

		// Get modded damage.
		if (GetTrieValue(g_hweapon_trie, classname, damage)) {
		
			#if DEBUG_DAMAGE_MOD
			debug_on_take_damage(victim, attacker, inflictor, damage);
			#endif
		
			return Plugin_Changed;
		}
	}

	#if DEBUG_DAMAGE_MOD
	debug_on_take_damage(victim, attacker, inflictor, damage);
	#endif

	return Plugin_Continue;
}

void event_player_spawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (GetClientTeam(client) == TEAM_SURVIVORS) {

		// First make sure we are not rehooking on_take_damage_survivor.
		SDKUnhook(client, SDKHook_OnTakeDamage, on_take_damage_survivor);

		SDKHook(client, SDKHook_OnTakeDamage, on_take_damage_survivor);

		if (!g_is_maxedout) {
			
			// Count on the next frame, fixes miscount on idle.
			RequestFrame(count_alive_survivors);
		
		}
	}	
}

Action on_take_damage_survivor(int victim, int& attacker, int& inflictor, float& damage, int& damagetype)
{
	// Hunter damage to survivors.
	if (attacker > 0 && attacker <= MaxClients && GetClientTeam(attacker) == TEAM_INFECTED && GetEntProp(attacker, Prop_Send, "m_zombieClass") == ZOMBIE_CLASS_HUNTER) {
		damage *= 0.5;

		#if DEBUG_DAMAGE_MOD
		debug_on_take_damage(victim, attacker, inflictor, damage);
		#endif

		return Plugin_Changed;
	}
	
	#if DEBUG_DAMAGE_MOD
	debug_on_take_damage(victim, attacker, inflictor, damage);
	#endif

	return Plugin_Continue;
}

void event_player_death(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (client) {
		int client_team = GetClientTeam(client);

		// Keep track of recently killed special infected.
		if (client_team == TEAM_INFECTED) {
			const float delay = 4.0;
			switch (GetEntProp(client, Prop_Send, "m_zombieClass")) {
				case ZOMBIE_CLASS_SMOKER: {
					++g_si_recently_killed[SI_INDEX_SMOKER];
					CreateTimer(delay, clear_recently_killed, SI_INDEX_SMOKER, TIMER_FLAG_NO_MAPCHANGE);
				}
				case ZOMBIE_CLASS_BOOMER: {
					++g_si_recently_killed[SI_INDEX_BOOMER];
					CreateTimer(delay, clear_recently_killed, SI_INDEX_BOOMER, TIMER_FLAG_NO_MAPCHANGE);
				}
				case ZOMBIE_CLASS_HUNTER: {
					++g_si_recently_killed[SI_INDEX_HUNTER];
					CreateTimer(delay, clear_recently_killed, SI_INDEX_HUNTER, TIMER_FLAG_NO_MAPCHANGE);
				}
				case ZOMBIE_CLASS_SPITTER: {
					++g_si_recently_killed[SI_INDEX_SPITTER];
					CreateTimer(delay, clear_recently_killed, SI_INDEX_SPITTER, TIMER_FLAG_NO_MAPCHANGE);
				}
				case ZOMBIE_CLASS_JOCKEY: {
					++g_si_recently_killed[SI_INDEX_JOCKEY];
					CreateTimer(delay, clear_recently_killed, SI_INDEX_JOCKEY, TIMER_FLAG_NO_MAPCHANGE);
				}
				case ZOMBIE_CLASS_CHARGER: {
					++g_si_recently_killed[SI_INDEX_CHARGER];
					CreateTimer(delay, clear_recently_killed, SI_INDEX_CHARGER, TIMER_FLAG_NO_MAPCHANGE);
				}
			}
		}

		else if (!g_is_maxedout && client_team == TEAM_SURVIVORS)
			count_alive_survivors();
	}
}

void clear_recently_killed(Handle tiemr, int data)
{
	--g_si_recently_killed[data];
}

void count_alive_survivors()
{
	g_alive_survivors = 0;
	for (int i = 1; i <= MaxClients; ++i)
		if (IsClientInGame(i) && GetClientTeam(i) == TEAM_SURVIVORS && IsPlayerAlive(i))
			++g_alive_survivors;

	#if DEBUG_SI_SPAWN
	PrintToChatAll("[HR] count_alive_survivors(): (BEFORE CLAMP!) g_alive_survivors = %i", g_alive_survivors);
	#endif

	g_alive_survivors = clamp(g_alive_survivors, 2, 4);
	
	// Setting g_si_limit here is convinient.
	g_si_limit = g_alive_survivors + 1;

	#if DEBUG_SI_SPAWN
	PrintToChatAll("[HR] count_alive_survivors(): (AFTER CLAMP!) g_alive_survivors = %i", g_alive_survivors);
	PrintToChatAll("[HR] count_alive_survivors(): g_si_limit = %i", g_si_limit);
	#endif
}

void event_player_left_safe_area(Event event, const char[] name, bool dontBroadcast)
{
	#if DEBUG_SI_SPAWN
	PrintToChatAll("[HR] event_player_left_safe_area()");
	#endif

	start_spawn_timer();
}

void start_spawn_timer()
{
	float interval = 17.0;
	if (!g_is_maxedout)
		interval = GetRandomFloat(17.0, 38.0);
	g_hspawn_timer = CreateTimer(interval, auto_spawn_si);

	#if DEBUG_SI_SPAWN
	PrintToChatAll("[HR] start_spawn_timer(): interval = %.2f", interval);
	#endif
}

void auto_spawn_si(Handle timer)
{
	// Count special infected.
	int si_type_counts[SI_TYPES];
	int si_total_count;
	for (int i = 1; i <= MaxClients; ++i) {
		if (IsClientInGame(i) && GetClientTeam(i) == TEAM_INFECTED && IsPlayerAlive(i)) {
			switch (GetEntProp(i, Prop_Send, "m_zombieClass")) {
				case ZOMBIE_CLASS_SMOKER: {
					++si_type_counts[SI_INDEX_SMOKER];
					++si_total_count;
				}
				case ZOMBIE_CLASS_BOOMER: {
					++si_type_counts[SI_INDEX_BOOMER];
					++si_total_count;
				}
				case ZOMBIE_CLASS_HUNTER: {
					++si_type_counts[SI_INDEX_HUNTER];
					++si_total_count;
				}
				case ZOMBIE_CLASS_SPITTER: {
					++si_type_counts[SI_INDEX_SPITTER];
					++si_total_count;
				}
				case ZOMBIE_CLASS_JOCKEY: {
					++si_type_counts[SI_INDEX_JOCKEY];
					++si_total_count;
				}
				case ZOMBIE_CLASS_CHARGER: {
					++si_type_counts[SI_INDEX_CHARGER];
					++si_total_count;
				}

				// Idealy should count only aggroed tanks.
				case ZOMBIE_CLASS_TANK: {

					// Run VScript code.
					int logic = CreateEntityByName("logic_script");
					DispatchSpawn(logic);
					SetVariantString("Convars.SetValue(\"hr_istankinplay\",Director.IsTankInPlay());");
					AcceptEntityInput(logic, "RunScriptCode");
					RemoveEntity(logic);

					#if DEBUG_SI_SPAWN
					PrintToChatAll("[HR] auto_spawn_si(): hr_istankinplay = %i", GetConVarInt(g_hhr_istankinplay));
					#endif

					if (GetConVarBool(g_hhr_istankinplay))
						++si_total_count;
				}

			}
		}
	}

	// Spawn special infected.
	if (si_total_count < g_si_limit) {
		
		// Set spawn size.
		int size = g_si_limit - si_total_count;
		if (!g_is_maxedout && size > 3)
			size = GetRandomInt(3, size);

		#if DEBUG_SI_SPAWN
		PrintToChatAll("[HR] auto_spawn_si(): g_si_limit = %i; si_total_count = %i; size = %i", g_si_limit, si_total_count, size);
		#endif

		// Keep the same order as zombie classes.
		static const int si_spawn_limits[SI_TYPES] = { 2, 1, 2, 1, 2, 2 };
		static const int si_spawn_weights[SI_TYPES] = { 60, 100, 60, 100, 60, 60 };
		static const float si_spawn_weight_mods[SI_TYPES] = { 0.5, 1.0, 0.5, 1.0, 0.5, 0.5 };

		int tmp_weights[SI_TYPES];
		float delay;
		while (size) {

			// Calculate temporary weights and their weight sum, including reductions.
			int tmp_wsum;
			for (int i = 0; i < SI_TYPES; ++i) {
				if (si_type_counts[i] < si_spawn_limits[i]) {
					tmp_weights[i] = si_spawn_weights[i];
					int tmp_count = si_type_counts[i];
					while (tmp_count) {
						tmp_weights[i] = RoundToNearest(float(tmp_weights[i]) * si_spawn_weight_mods[i]);
						--tmp_count;
					}
				}
				else
					tmp_weights[i] = 0;
				tmp_wsum += tmp_weights[i];
			}

			#if DEBUG_SI_SPAWN
			for (int i = 0; i < SI_TYPES; ++i)
				PrintToChatAll("[HR] auto_spawn_si(): tmp_weights[%s] = %i", g_debug_si_indexes[i], tmp_weights[i]);
			#endif

			int index = GetRandomInt(1, tmp_wsum);

			#if DEBUG_SI_SPAWN
			PrintToChatAll("[HR] auto_spawn_si(): index = %i", index);
			#endif

			// Cycle trough weight ranges, find where the random index falls and pick an appropriate array index.
			int range;
			for (int i = 0; i < SI_TYPES; ++i) {
				range += tmp_weights[i];
				if (index <= range) {
					index = i;
					++si_type_counts[index];
					break;
				}
			}

			#if DEBUG_SI_SPAWN
			PrintToChatAll("[HR] auto_spawn_si(): range = %i; tmp_wsum = %i; index = %s", range, tmp_wsum, g_debug_si_indexes[index]);
			#endif

			// Prevent instant spam of all specials at once.
			// Min and max delays are chosen more for technical reasons than gameplay reasons.
			delay += GetRandomFloat(0.4, 1.2);
			CreateTimer(delay, fake_z_spawn_old, index, TIMER_FLAG_NO_MAPCHANGE);

			--size;
		}
	}

	#if DEBUG_SI_SPAWN
	else
		PrintToConsoleAll("[HR] auto_spawn_si(): g_si_limit = %i; si_total_count = %i; SI LIMIT REACHED!", g_si_limit, si_total_count);
	#endif

	// Restart the spawn timer.
	start_spawn_timer();
}

void fake_z_spawn_old(Handle timer, int data)
{	
	// Further delay spawn if special infected we wished to spawn was killed recently.
	if (g_si_recently_killed[data] > 0) {

		#if DEBUG_SI_SPAWN
		PrintToChatAll("[HR] fake_z_spawn_old(): g_si_recently_killed[%s] = %i; RECREATING TIMER AND RETURNING!", g_debug_si_indexes[data], g_si_recently_killed[data]);
		#endif

		CreateTimer(0.2, fake_z_spawn_old, data, TIMER_FLAG_NO_MAPCHANGE);
		return;
	}

	int client = get_random_alive_survivor();
	if (client) {
		
		// Create infected bot.
		// Without this we may not be able to spawn our special infected.
		int bot = CreateFakeClient("");
		if (bot)
			ChangeClientTeam(bot, TEAM_INFECTED);
		
		static const char z_spawn_old[] = "z_spawn_old";

		// Store command flags.
		int flags = GetCommandFlags(z_spawn_old);

		// Clear "sv_cheat" flag from the command.
		SetCommandFlags(z_spawn_old, flags & ~FCVAR_CHEAT);

		// Keep the same order as zombie classes.
		static const char z_spawns[SI_TYPES][] = { "z_spawn_old smoker auto", "z_spawn_old boomer auto", "z_spawn_old hunter auto", "z_spawn_old spitter auto", "z_spawn_old jockey auto", "z_spawn_old charger auto" };

		FakeClientCommand(client, z_spawns[data]);

		// Restore command flags.
		SetCommandFlags(z_spawn_old, flags);

		#if DEBUG_SI_SPAWN
		PrintToChatAll("[HR] fake_z_spawn_old(): client = %i [%N]; z_spawns[%s] = %s", client, client, g_debug_si_indexes[data], z_spawns[data]);
		#endif

		// Kick the bot.
		if (bot && IsClientConnected(bot))
			KickClient(bot);

	}
}

void event_tank_spawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));

	// Tank hp on 2 alive survivors = 10447.
	// Tank hp on 3 alive survivors = 14449.
	// Tank hp on 4 alive survivors = 18189.
	int tank_hp = RoundToNearest(6000.0 * Pow(float(g_alive_survivors), 0.8));
		
	SetEntProp(client, Prop_Data, "m_iMaxHealth", tank_hp);
	SetEntProp(client, Prop_Data, "m_iHealth", tank_hp);

	// Tank burn time on 2 alive survivors = 111 s (1:51 min).
	// Tank burn time on 3 alive survivors = 154 s (2:34 min).
	// Tank burn time on 4 alive survivors = 193 s (3:13 min).
	// The constant factor was calculated from default values.
	SetConVarInt(FindConVar("tank_burn_duration_expert"), RoundToNearest(float(tank_hp) * 0.010625));

	SDKHook(client, SDKHook_OnTakeDamage, on_take_damage_tank);

	#if DEBUG_TANK_HP
	PrintToChatAll("[HR] event_tank_spawn(): tank hp is %i", GetEntProp(client, Prop_Data, "m_iHealth"));
	PrintToChatAll("[HR] event_tank_spawn(): tank max hp is %i", GetEntProp(client, Prop_Data, "m_iMaxHealth"));
	PrintToChatAll("[HR] event_tank_spawn(): tank burn time is %i", GetConVarInt(FindConVar("tank_burn_duration_expert")));
	#endif
}

Action on_take_damage_tank(int victim, int& attacker, int& inflictor, float& damage, int& damagetype)
{
	// Melee damage to tank.
	//

	char classname[16];
	GetEdictClassname(inflictor, classname, sizeof(classname));
	
	// Melee should do one instance of damage larger than zero and multiple instances of zero damage,
	// so ignore zero damage.
	if (!strcmp(classname, "weapon_melee") && !is_zero(damage)) {
		damage = 400.0;
		
		#if DEBUG_DAMAGE_MOD
		debug_on_take_damage(victim, attacker, inflictor, damage);
		#endif
		
		return Plugin_Changed;
	}

	//
	
	#if DEBUG_DAMAGE_MOD
	debug_on_take_damage(victim, attacker, inflictor, damage);
	#endif

	return Plugin_Continue;
}

// firebulletsfix
// Source: https://forums.alliedmods.net/showthread.php?t=315405
//

public void OnClientPutInServer(int client)
{
	if (!IsFakeClient(client))
		DHookEntity(g_hweapon_shoot_position, true, client);
}

public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, float vel[3], float angles[3], int& weapon, int& subtype, int& cmdnum, int& tickcount, int& seed, int mouse[2])
{
	if (!IsFakeClient(client) && IsPlayerAlive(client))
		GetClientEyePosition(client, g_old_weapon_shoot_position[client]);
	return Plugin_Continue;
}

MRESReturn on_weapon_shoot_position(int pThis, DHookReturn hReturn)
{
	#if DEBUG_FIREBULLETSFIX
	float vec[3];
	DHookGetReturnVector(hReturn, vec);
	PrintToChatAll("[HR] %N Old ShootPosition: %.2f, %.2f, %.2f", pThis, g_old_weapon_shoot_position[pThis][0], g_old_weapon_shoot_position[pThis][1], g_old_weapon_shoot_position[pThis][2]);
	PrintToChatAll("[HR] %N New ShootPosition: %.2f, %.2f, %.2f", pThis, vec[0], vec[1], vec[2]);
	#endif

	DHookSetReturnVector(hReturn, g_old_weapon_shoot_position[pThis]);
	return MRES_Supercede;
}

//

public void OnActionCreated(BehaviorAction action, int actor, const char[] name)
{
	// For common infected shove direction fix.
	if (!strcmp(name, "InfectedShoved"))
		__action_setlistener(action, __action_processor_OnShoved, infected_shoved_on_shoved, false);
	
	// For jockey insta attack after failed leap fix.
	else if (!strcmp(name, "JockeyAttack"))
		__action_setlistener(action, __action_processor_OnResume, jockey_attack_on_resume, true);
}

// Common infected shove direction fix.
// Source: https://forums.alliedmods.net/showthread.php?t=319988
Action infected_shoved_on_shoved(any action, int actor, int entity, ActionDesiredResult result)
{
	char classname[8];
	GetEntityClassname(actor, classname, sizeof(classname));

	#if DEBUG_SHOVE
	PrintToChatAll("[HR] infected_shoved_on_shoved(): %s", classname);
	#endif

	if (!strcmp(classname, "witch")) 
		return Plugin_Continue;
	return Plugin_Handled;
}

// Jockey insta attack after failed leap fix.
Action jockey_attack_on_resume(any action, int actor, any priorAction, ActionResult result)
{
	#if DEBUG_JOCKEY
	PrintToChatAll("[HR] jockey_attack_on_resume()");
	#endif

	// Prevent jockey from attacking.
	static const char m_afButtonDisabled[] = "m_afButtonDisabled";
	SetEntProp(actor, Prop_Data, m_afButtonDisabled, GetEntProp(actor, Prop_Data, m_afButtonDisabled) | IN_ATTACK2);

	// Allow jockey to attack again after delay.
	//

	int userid = GetClientUserId(actor);
	const float delay = 0.2;

	// We already have a timer?
	for (int i = 0; i < 5; ++i)
		if (g_clear_in_attack2_timers[i].userid == userid) {

			#if DEBUG_JOCKEY
			PrintToChatAll("[HR] jockey_attack_on_resume(): We already have a timer!");
			#endif

			return Plugin_Continue;
		}

	// We don't have a timer.
	for (int i = 0; i < 5; ++i)
		if (!g_clear_in_attack2_timers[i].userid) {
			g_clear_in_attack2_timers[i].userid = userid;
			g_clear_in_attack2_timers[i].htimer = CreateTimer(delay, clear_in_attack2, i);
			return Plugin_Continue;
		}

	#if DEBUG_SHOVE
	PrintToChatAll("[HR] jockey_attack_on_resume(): g_clear_in_attack2_timers has no free slot!");
	#endif

	//

	return Plugin_Continue;
}

// Special infected insta attack after shove fix.
void event_player_shoved(Event event, const char[] name, bool dontBroadcast)
{
	int userid = GetEventInt(event, "userid");
	int client = GetClientOfUserId(userid);
	if (GetClientTeam(client) == TEAM_INFECTED && IsPlayerAlive(client)) {

		// smoker(1) or boomer(2) or hunter(3) or spitter(4) or jockey(5)
		int zombie_class = GetEntProp(client, Prop_Send, "m_zombieClass");
		if (zombie_class > 0 && zombie_class < 6) {
			
			#if DEBUG_SHOVE
			PrintToChatAll("[HR] event_player_shoved(): zombie_class = %s", g_debug_si_indexes[zombie_class - 1]);
			#endif
			
			// Prevent special infected from attacking.
			static const char m_afButtonDisabled[] = "m_afButtonDisabled";
			SetEntProp(client, Prop_Data, m_afButtonDisabled, GetEntProp(client, Prop_Data, m_afButtonDisabled) | IN_ATTACK2);
			
			// Allow special infected to attack again after delay.
			//

			const float delay = 1.5;

			// Are we reshoving or we already have timer?
			for (int i = 0; i < 5; ++i)
				if (g_clear_in_attack2_timers[i].userid == userid) {
					delete g_clear_in_attack2_timers[i].htimer;
					g_clear_in_attack2_timers[i].htimer = CreateTimer(delay, clear_in_attack2, i);
					return;
				}

			// Shoving for the first time.
			for (int i = 0; i < 5; ++i)
				if (!g_clear_in_attack2_timers[i].userid) {
					g_clear_in_attack2_timers[i].userid = userid;
					g_clear_in_attack2_timers[i].htimer = CreateTimer(delay, clear_in_attack2, i);
					return;
				}

			#if DEBUG_SHOVE
			PrintToChatAll("[HR] event_player_shoved(): g_clear_in_attack2_timers has no free slot!");
			#endif

			//

		}
	}
}

// For jockey insta attack after failed leap fix.
// For special infected insta attack after shove fix.
void clear_in_attack2(Handle timer, int data)
{
	int client = GetClientOfUserId(g_clear_in_attack2_timers[data].userid);
	if (client && IsClientInGame(client) && IsPlayerAlive(client)) {
		
		#if (DEBUG_SHOVE || DEBUG_JOCKEY)
		int zombie_class = GetEntProp(client, Prop_Send, "m_zombieClass");
		PrintToChatAll("[HR] clear_in_attack2(): zombie_class = %s", g_debug_si_indexes[zombie_class - 1]);
		#endif
		
		static const char m_afButtonDisabled[] = "m_afButtonDisabled";
		SetEntProp(client, Prop_Data, m_afButtonDisabled, GetEntProp(client, Prop_Data, m_afButtonDisabled) & ~IN_ATTACK2);
	}
	g_clear_in_attack2_timers[data].userid = 0;
	g_clear_in_attack2_timers[data].htimer = null;
}

// Friendly fire while Charger carries survivor fix.
//

void event_charger_carry_start(Event event, const char[] name, bool dontBroadcast)
{
	#if DEBUG_CHARGER
	PrintToChatAll("[HR] event_charger_carry_start(): victim = %N", GetClientOfUserId(GetEventInt(event, "victim")));
	#endif

	SDKHook(GetClientOfUserId(GetEventInt(event, "victim")), SDKHook_OnTakeDamage, on_take_damage_charger_carry);
}

void event_charger_carry_end(Event event, const char[] name, bool dontBroadcast)
{
	#if DEBUG_CHARGER
	PrintToChatAll("[HR] event_charger_carry_end(): victim = %N", GetClientOfUserId(GetEventInt(event, "victim")));
	#endif

	SDKUnhook(GetClientOfUserId(GetEventInt(event, "victim")), SDKHook_OnTakeDamage, on_take_damage_charger_carry);
}

Action on_take_damage_charger_carry(int victim, int& attacker, int& inflictor, float& damage, int& damagetype)
{
	if (attacker > 0 && attacker <= MaxClients && GetClientTeam(attacker) == TEAM_SURVIVORS) {

		#if DEBUG_CHARGER
		PrintToChatAll("[HR] on_take_damage_charger_carry(): attacker = %N, victim = %N", attacker, victim);
		#endif

		damage = 0.0;
		return Plugin_Changed;
	}
	return Plugin_Continue;
}

//

// Smoker insta grab fix.
void event_tongue_grab(Event event, const char[] name, bool dontBroadcast)
{
	int victim_id = GetEventInt(event, "victim");
	int victim = GetClientOfUserId(victim_id);

	// We only need to fix things if the victim is not on "worldspawn".
	int ground_entity = GetEntPropEnt(victim, Prop_Send, "m_hGroundEntity");
	if (ground_entity != -1) {
		char classname[12];
		GetEntityClassname(ground_entity, classname, sizeof(classname));

		#if DEBUG_SMOKER
		PrintToChatAll("[HR] event_tongue_grab(): ground_entity = %s", classname);
		#endif
			
		if (strcmp(classname, "worldspawn")) {
				
			// We only need to fix things if the smoker is above the victim.
			float smoker_origin[3];
			float victim_origin[3];
			GetClientAbsOrigin(GetClientOfUserId(GetEventInt(event, "userid")), smoker_origin);
			GetClientAbsOrigin(victim, victim_origin);
			if (smoker_origin[2] > victim_origin[2]) {

				#if DEBUG_SMOKER
				PrintToChatAll("[HR] event_tongue_grab(): smoker_origin.z > victim_origin.z");
				#endif

				// Run VScript code.
				//

				int logic = CreateEntityByName("logic_script");
				DispatchSpawn(logic);
				char buffer[172];

				// Source: https://steamcommunity.com/sharedfiles/filedetails/?id=2945656229
				FormatEx(buffer, sizeof(buffer), "local v=GetPlayerFromUserID(%i);NetProps.SetPropEntity(v,\"m_hGroundEntity\",null);v.SetOrigin(v.GetOrigin()+Vector(0,0,20));v.ApplyAbsVelocityImpulse(Vector(0,0,30));", victim_id);

				SetVariantString(buffer);
				AcceptEntityInput(logic, "RunScriptCode");
				RemoveEntity(logic);

				//

			}

		}
	}
}

void event_round_end(Event event, const char[] name, bool dontBroadcast)
{
	on_end();
}

public void OnMapEnd()
{
	on_end();
}

void on_end()
{
	delete g_hspawn_timer;
	for (int i = 0; i < 5; ++i) {
		g_clear_in_attack2_timers[i].userid = 0;
		delete g_clear_in_attack2_timers[i].htimer;
	}
	for (int i = 0; i < SI_TYPES; ++i)
		g_si_recently_killed[i] = 0;
}

public void OnServerEnterHibernation()
{
	g_is_maxedout = false;
}

#if DEBUG_DAMAGE_MOD
void debug_on_take_damage(int victim, int attacker, int inflictor, float damage)
{
	if (attacker > 0 && attacker <= MaxClients && IsClientInGame(attacker)) {
		char classname[32];
		if (attacker == inflictor)
			GetClientWeapon(inflictor, classname, sizeof(classname));
		else
			GetEdictClassname(inflictor, classname, sizeof(classname));
		if (victim > 0 && victim <= MaxClients && IsClientInGame(victim))
			PrintToChatAll("%N (%s) %.2f dmg to %N", attacker, classname, damage, victim);
		else
			PrintToChatAll("%N (%s) %.2f dmg to victim %i", attacker, classname, damage, victim);
	}
}
#endif

// Extra stock functions
//

/*
Returns client of random alive survivor or 0 if there are no alive survivors.
*/
stock int get_random_alive_survivor()
{
	int[] clients = new int[MaxClients];
	int index;
	for (int i = 1; i <= MaxClients; ++i)
		if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i))
			clients[index++] = i; // We can't know who's last, so index will overflow!
	return index ? clients[GetRandomInt(0, index - 1)] : 0;
}

/*
Returns clamped val between min and max.
*/
stock int clamp(int val, int min, int max)
{
	return val > max ? max : (val < min ? min : val);
}

/*
Safe check is float val zero.
*/
stock bool is_zero(float val)
{
	return FloatAbs(val) < 0.000001;
}