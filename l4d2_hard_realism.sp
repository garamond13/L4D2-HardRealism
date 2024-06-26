/*
IMPORTANT NOTE: HardRealism mode is designed for Realism Expert ("mp_gamemode realism" and "z_difficulty Impossible").

Version description

SI order = Smoker, Boomer, Hunter, Spitter, Jockey, Charger.

Version 29
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
- Set Hunter claw damage to 20.
- Set Jockey health to 300.
- Set Jockey ride damage to 15.
- Set Jockey leap range to 150.
- Set Charger pound damage to 20.
- Tank health is relative to the number of alive Survivors (Normal mod).
- Shotguns are more effective at close range against Common Infected.
- Set Hunting Rifle damage against Common/Uncommon Infected to 38.
- Set Military Sniper damage against Common/Uncommon Infected to 38.
- Set Scout damage against Common/Uncommon Infected to 75.
- Set AWP damage against Common/Uncommon Infected to 150.
- Set melee damage against Tank to 400.
- Bots no longer shoot through Survivors.
- Fix Common Infected shove direction.
- Fix Special Infected insta attack after shove.
- Fix friendly fire while Charger carrys survivor.
- Fix Smoker insta grab.
*/

// Note that in SourcePawn variables and arrays should be zero initialized by default.

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <actions>

#pragma semicolon 1
#pragma newdecls required

// MAJOR (gameplay change).MINOR.PATCH
#define VERSION "29.0.2"

// Debug switches
#define DEBUG_DAMAGE_MOD 0
#define DEBUG_SI_SPAWN 0
#define DEBUG_TANK_HP 0
#define DEBUG_SHOVE 0
#define DEBUG_CHARGER 0
#define DEBUG_SMOKER 0

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

#if (DEBUG_SI_SPAWN || DEBUG_SHOVE)
// Keep the same order as zombie classes.
static const char g_debug_si_indexes[SI_TYPES][] = { "SI_INDEX_SMOKER", "SI_INDEX_BOOMER", "SI_INDEX_HUNTER", "SI_INDEX_SPITTER", "SI_INDEX_JOCKEY", "SI_INDEX_CHARGER" };
#endif

// Keep the same order as zombie classes.
static const char g_z_spawns[SI_TYPES][] = { "z_spawn_old smoker auto", "z_spawn_old boomer auto", "z_spawn_old hunter auto", "z_spawn_old spitter auto", "z_spawn_old jockey auto", "z_spawn_old charger auto" };
static const int g_si_spawn_limits[SI_TYPES] = { 2, 1, 2, 1, 2, 2 };
static const int g_si_spawn_weights[SI_TYPES] = { 60, 100, 60, 100, 60, 60 };
static const float g_si_spawn_weight_mods[SI_TYPES] = { 0.5, 1.0, 0.5, 1.0, 0.5, 0.5 };

Handle g_hspawn_timer;
int g_alive_survivors;
int g_si_limit;

//

// Damage mod
Handle g_hweapon_trie;

// Is MaxedOut mod active? If not Normal mod will be active.
bool g_is_maxedout;

// Used by GetVScriptOutput().
ConVar gCvarBuffer;

public Plugin myinfo = {
	name = "L4D2 HardRealism",
	author = "Garamond",
	description = "HardRealism mod",
	version = VERSION,
	url = "https://github.com/garamond13/L4D2-HardRealism"
};

public void OnPluginStart()
{
	// Map modded damage.
	g_hweapon_trie = CreateTrie();
	SetTrieValue(g_hweapon_trie, "weapon_hunting_rifle", 38.0);
	SetTrieValue(g_hweapon_trie, "weapon_sniper_military", 38.0);
	SetTrieValue(g_hweapon_trie, "weapon_sniper_scout", 75.0);
	SetTrieValue(g_hweapon_trie, "weapon_sniper_awp", 150.0);

	// Hook game events.
	HookEvent("player_left_safe_area", event_player_left_safe_area, EventHookMode_PostNoCopy);
	HookEvent("player_spawn", event_player_spawn);
	HookEvent("player_death", event_player_death);
	HookEvent("tank_spawn", event_tank_spawn, EventHookMode_Pre);
	HookEvent("player_shoved", event_player_shoved);
	HookEvent("charger_carry_start", event_charger_carry_start);
	HookEvent("charger_carry_end", event_charger_carry_end);
	HookEvent("tongue_grab", event_tongue_grab);
	HookEvent("round_end", event_round_end, EventHookMode_Pre);

	// Register new console commands.
	RegConsoleCmd("hr_getmod", command_hr_getmod);
	RegConsoleCmd("hr_switchmod", command_hr_switchmod);
	
	// Used by GetVScriptOutput().
	gCvarBuffer = CreateConVar("sm_vscript_return", "", "Buffer used to return vscript values. Do not use.");
}

public void OnConfigsExecuted()
{	
	// Workaround. It will be halved by on_take_damage().
	// Default 5, it will be multiplied by 3 on Realsim Expert
	SetConVarInt(FindConVar("z_pounce_damage"), 10);

	// Defualt 325.
	SetConVarInt(FindConVar("z_jockey_health"), 300);

	// Default 200.
	SetConVarInt(FindConVar("z_jockey_leap_range"), 150);

	// Default 4, it will be multiplied by 3 on Realsim Expert.
	SetConVarInt(FindConVar("z_jockey_ride_damage"), 5);

	// Default 15.
	SetConVarInt(FindConVar("z_charger_pound_dmg"), 20);

	// Default 100.
	SetConVarInt(FindConVar("z_shotgun_bonus_damage_range"), 150);
	
	// Default 1.
	SetConVarInt(FindConVar("sb_allow_shoot_through_survivors"), 0);

	// Disbale director spawn special infected.
	SetConVarInt(FindConVar("z_smoker_limit"), 0);
	SetConVarInt(FindConVar("z_boomer_limit"), 0);
	SetConVarInt(FindConVar("z_hunter_limit"), 0);
	SetConVarInt(FindConVar("z_spitter_limit"), 0);
	SetConVarInt(FindConVar("z_jockey_limit"), 0);
	SetConVarInt(FindConVar("z_charger_limit"), 0);
}

Action command_hr_getmod(int client, int args)
{
	if (g_is_maxedout)
		PrintToConsole(client, "[HR] MaxedOut mod is active.");
	else // Normal mod.
		PrintToConsole(client, "[HR] Normal mod is active.");
	return Plugin_Handled;
}

Action command_hr_switchmod(int client, int args)
{
	g_is_maxedout = !g_is_maxedout;
	char buffer[32];
	GetClientName(client, buffer, sizeof(buffer));
	if (g_is_maxedout) {
		UnhookEvent("player_death", event_player_death);
		g_alive_survivors = 4;
		g_si_limit = 5;
		PrintToChatAll("[HR] MaxedOut mod is activated by %s.", buffer);
	}
	else { // Normal mod.
		HookEvent("player_death", event_player_death);
		count_alive_survivors();
		PrintToChatAll("[HR] Normal mod is activated by %s.", buffer);
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
	if (attacker == inflictor && attacker > 0 && attacker <= MaxClients && IsClientInGame(attacker)) {
		char classname[32];
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
	if (client && IsClientInGame(client) && GetClientTeam(client) == TEAM_SURVIVORS) {

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
	if (attacker > 0 && attacker <= MaxClients && IsClientInGame(attacker) && GetClientTeam(attacker) == TEAM_INFECTED && GetEntProp(attacker, Prop_Send, "m_zombieClass") == ZOMBIE_CLASS_HUNTER) {
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
	if (client && IsClientInGame(client) && GetClientTeam(client) == TEAM_SURVIVORS)
		count_alive_survivors();
}

void count_alive_survivors()
{
	g_alive_survivors = 0;
	for (int i = 1; i <= MaxClients; ++i)
		if (IsClientInGame(i) && GetClientTeam(i) == TEAM_SURVIVORS && IsPlayerAlive(i))
			++g_alive_survivors;

	#if DEBUG_SI_SPAWN
	PrintToConsoleAll("[HR] count_alive_survivors(): (BEFORE CLAMP!) g_alive_survivors = %i", g_alive_survivors);
	#endif

	g_alive_survivors = clamp(g_alive_survivors, 2, 4);
	
	// Setting g_si_limit here is convinient.
	g_si_limit = g_alive_survivors + 1;

	#if DEBUG_SI_SPAWN
	PrintToConsoleAll("[HR] count_alive_survivors(): (AFTER CLAMP!) g_alive_survivors = %i", g_alive_survivors);
	PrintToConsoleAll("[HR] count_alive_survivors(): g_si_limit = %i", g_si_limit);
	#endif
}

void event_player_left_safe_area(Event event, const char[] name, bool dontBroadcast)
{
	#if DEBUG_SI_SPAWN
	PrintToConsoleAll("[HR] event_player_left_safe_area()");
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
	PrintToConsoleAll("[HR] start_spawn_timer(): interval = %f", interval);
	#endif
}

Action auto_spawn_si(Handle timer)
{
	// Count special infected.
	int si_type_counts[SI_TYPES];
	int si_total_count;
	for (int i = 1; i <= MaxClients; ++i) {
		if (IsClientInGame(i) && GetClientTeam(i) == TEAM_INFECTED && IsPlayerAlive(i)) {

			// Detect special infected type by zombie class.
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
					char buffer[128]; // GetVScriptOutput() requires large buffer.
					
					// Returns "true" if any tanks are aggro on survivors.
					GetVScriptOutput("Director.IsTankInPlay()", buffer, sizeof(buffer));
					
					#if DEBUG_SI_SPAWN
					PrintToConsoleAll("[HR] auto_spawn_si(): Director.IsTankInPlay() = %s", buffer);
					#endif

					if (!strcmp(buffer, "true"))
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
		PrintToConsoleAll("[HR] auto_spawn_si(): g_si_limit = %i; si_total_count = %i; size = %i", g_si_limit, si_total_count, size);
		#endif

		int tmp_weights[SI_TYPES];
		float delay;
		while (size) {

			// Calculate temporary weights and their weight sum, including reductions.
			int tmp_wsum;
			for (int i = 0; i < SI_TYPES; ++i) {
				if (si_type_counts[i] < g_si_spawn_limits[i]) {
					tmp_weights[i] = g_si_spawn_weights[i];
					int tmp_count = si_type_counts[i];
					while (tmp_count) {
						tmp_weights[i] = RoundToNearest(float(tmp_weights[i]) * g_si_spawn_weight_mods[i]);
						--tmp_count;
					}
				}
				else
					tmp_weights[i] = 0;
				tmp_wsum += tmp_weights[i];
			}

			#if DEBUG_SI_SPAWN
			for (int i = 0; i < SI_TYPES; ++i)
				PrintToConsoleAll("[HR] auto_spawn_si(): tmp_weights[%s] = %i", g_debug_si_indexes[i], tmp_weights[i]);
			#endif

			int index = GetRandomInt(1, tmp_wsum);

			#if DEBUG_SI_SPAWN
			PrintToConsoleAll("[HR] auto_spawn_si(): index = %i", index);
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
			PrintToConsoleAll("[HR] auto_spawn_si(): range = %i; tmp_wsum = %i; index = %s", range, tmp_wsum, g_debug_si_indexes[index]);
			#endif

			// Prevent instant spam of all specials at once.
			// Min and max delays are chosen more for technical reasons than gameplay reasons.
			delay += GetRandomFloat(0.4, 2.2);
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
	
	return Plugin_Continue;
}

Action fake_z_spawn_old(Handle timer, int data)
{	
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

		FakeClientCommand(client, g_z_spawns[data]);

		// Restore command flags.
		SetCommandFlags(z_spawn_old, flags);

		#if DEBUG_SI_SPAWN
		char buffer[32];
		GetClientName(client, buffer, sizeof(buffer));
		PrintToConsoleAll("[HR] fake_z_spawn_old(): client = %i [%s]; g_z_spawns[%s] = %s", client, buffer, g_debug_si_indexes[data], g_z_spawns[data]);
		#endif

		// Kick the bot.
		if (bot && IsClientConnected(bot))
			KickClient(bot);

	}

	#if DEBUG_SI_SPAWN
	else
		PrintToConsoleAll("[HR] fake_z_spawn_old(): INVALID CLIENT!");
	#endif

	return Plugin_Continue;
}

void event_tank_spawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (client) {

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
		PrintToConsoleAll("[HR] event_tank_spawn(): g_alive_survivors = %i", g_alive_survivors);
		PrintToConsoleAll("[HR] event_tank_spawn(): tank_hp = %i", tank_hp);
		PrintToConsoleAll("[HR] event_tank_spawn(): tank hp is %i", GetEntProp(client, Prop_Data, "m_iHealth"));
		PrintToConsoleAll("[HR] event_tank_spawn(): tank max hp is %i", GetEntProp(client, Prop_Data, "m_iMaxHealth"));
		PrintToConsoleAll("[HR] event_tank_spawn(): tank burn time is %i", GetConVarInt(FindConVar("tank_burn_duration_expert")));
		#endif
	}

	#if DEBUG_TANK_HP
	else
		PrintToConsoleAll("[HR] event_tank_spawn(): INVALID CLIENT!");
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
	if (!strcmp(classname, "weapon_melee") && isn_zero(damage)) {
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

public void OnActionCreated(BehaviorAction action, int owner, const char[] name)
{
	if (!strcmp(name, "InfectedShoved"))
		action.OnShoved = on_shoved;
}

Action on_shoved(BehaviorAction action, int actor, int shover, ActionDesiredResult result)
{
	// Common infected shove direction fix.
	// Source: https://forums.alliedmods.net/showthread.php?t=319988
	//

	char classname[8];
	GetEntityClassname(actor, classname, sizeof(classname));
	if (!strcmp(classname, "witch")) 
		return Plugin_Continue;
	
	#if DEBUG_SHOVE
	PrintToChatAll("[HR] on_shoved()");
	#endif

	return Plugin_Handled;

	//
}

void event_player_shoved(Event event, const char[] name, bool dontBroadcast)
{
	// Prevent insta attack from SI after shove.
	int userid = GetEventInt(event, "userid");
	int client = GetClientOfUserId(userid);
	if (client && IsClientInGame(client) && GetClientTeam(client) == TEAM_INFECTED && IsPlayerAlive(client)) {
		int zombie_class = GetEntProp(client, Prop_Send, "m_zombieClass");
		if (zombie_class == ZOMBIE_CLASS_SMOKER || zombie_class == ZOMBIE_CLASS_BOOMER || zombie_class == ZOMBIE_CLASS_HUNTER || zombie_class == ZOMBIE_CLASS_SPITTER || zombie_class == ZOMBIE_CLASS_JOCKEY) {
			
			#if DEBUG_SHOVE
			PrintToChatAll("[HR] event_player_shoved(): zombie_class = %s", g_debug_si_indexes[zombie_class - 1]);
			#endif
			
			SetEntProp(client, Prop_Data, "m_afButtonDisabled", GetEntProp(client, Prop_Data, "m_afButtonDisabled") | IN_ATTACK2);
			
			// Allow SI to attack again after delay.
			CreateTimer(1.5, clear_in_attack2, userid, TIMER_FLAG_NO_MAPCHANGE);

		}
	}
}

Action clear_in_attack2(Handle timer, int data)
{
	int client = GetClientOfUserId(data);
	if (client && IsClientInGame(client) && IsPlayerAlive(client)) {
		
		#if DEBUG_SHOVE
		int zombie_class = GetEntProp(client, Prop_Send, "m_zombieClass");
		PrintToChatAll("[HR] clear_in_attack2(): zombie_class = %s", g_debug_si_indexes[zombie_class - 1]);
		#endif
		
		SetEntProp(client, Prop_Data, "m_afButtonDisabled", GetEntProp(client, Prop_Data, "m_afButtonDisabled") & ~IN_ATTACK2);
	}
	return Plugin_Continue;
}

void event_charger_carry_start(Event event, const char[] name, bool dontBroadcast)
{
		#if DEBUG_CHARGER
		char buffer[32];
		GetClientName(GetClientOfUserId(GetEventInt(event, "victim")), buffer, sizeof(buffer));
		PrintToChatAll("[HR] event_charger_carry_start(): victim = %s", buffer);
		#endif

		SDKHook(GetClientOfUserId(GetEventInt(event, "victim")), SDKHook_OnTakeDamage, on_take_damage_charger_carry);
}

void event_charger_carry_end(Event event, const char[] name, bool dontBroadcast)
{
		#if DEBUG_CHARGER
		char buffer[32];
		GetClientName(GetClientOfUserId(GetEventInt(event, "victim")), buffer, sizeof(buffer));
		PrintToChatAll("[HR] event_charger_carry_end(): victim = %s", buffer);
		#endif

		SDKUnhook(GetClientOfUserId(GetEventInt(event, "victim")), SDKHook_OnTakeDamage, on_take_damage_charger_carry);
}

Action on_take_damage_charger_carry(int victim, int& attacker, int& inflictor, float& damage, int& damagetype)
{
	if (attacker == inflictor && attacker > 0 && attacker <= MaxClients && IsClientInGame(attacker) && GetClientTeam(attacker) == TEAM_SURVIVORS) {

		#if DEBUG_CHARGER
		char attacker_name[32];
		char victim_name[32];
		GetClientName(attacker, attacker_name, sizeof(attacker_name));
		GetClientName(victim, victim_name, sizeof(victim_name));
		PrintToChatAll("[HR] on_take_damage_charger_carry(): attacker = %s, victim = %s", attacker_name, victim_name);
		#endif

		damage = 0.0;
		return Plugin_Changed;
	}
	return Plugin_Continue;
}

void event_tongue_grab(Event event, const char[] name, bool dontBroadcast)
{
	// Smoker insta grab fix.
	int smoker = GetClientOfUserId(GetEventInt(event, "userid"));
	int victim_id = GetEventInt(event, "victim");
	int victim = GetClientOfUserId(victim_id);
	if (victim) {
		int ground_entity = GetEntPropEnt(victim, Prop_Send, "m_hGroundEntity");
		if (ground_entity != -1 && smoker && IsClientInGame(smoker) && IsClientInGame(victim)) {

			// Get origins.
			float smoker_origin[3];
			float victim_origin[3];
			GetClientAbsOrigin(smoker, smoker_origin);
			GetClientAbsOrigin(victim, victim_origin);

			char classname[16];
			GetEntityClassname(ground_entity, classname, sizeof(classname));
			if (smoker_origin[2] > victim_origin[2] && strcmp(classname, "worldspawn")) {

				#if DEBUG_SMOKER
				char client_name[32];
				GetClientName(victim, client_name, sizeof(client_name));
				PrintToChatAll("[HR] event_tongue_grab(): victim = %s", client_name);
				#endif

				// Boilerplate for running VScript code.
				static int logic = INVALID_ENT_REFERENCE;
				if (logic == INVALID_ENT_REFERENCE || !IsValidEntity(logic)) {
					logic = EntIndexToEntRef(CreateEntityByName("logic_script"));
					if (logic == INVALID_ENT_REFERENCE || !IsValidEntity(logic))
						SetFailState("Could not create 'logic_script'");
					DispatchSpawn(logic);
				}

				char buffer[256];

				// Source: https://steamcommunity.com/sharedfiles/filedetails/?id=2945656229
				FormatEx(buffer, sizeof(buffer), "local victim=GetPlayerFromUserID(%i);NetProps.SetPropEntity(victim,\"m_hGroundEntity\",null);victim.SetOrigin(victim.GetOrigin()+Vector(0,0,20));victim.ApplyAbsVelocityImpulse(Vector(0,0,30));", victim_id);

				// Run code.
				SetVariantString(buffer);
				AcceptEntityInput(logic, "RunScriptCode");
				AcceptEntityInput(logic, "Kill");

			}
		}
	}
}

void event_round_end(Event event, const char[] name, bool dontBroadcast)
{
	delete g_hspawn_timer;
}

public void OnMapEnd()
{
	delete g_hspawn_timer;
}

public void OnServerEnterHibernation()
{
	if (g_is_maxedout) {
		HookEvent("player_death", event_player_death);
		g_is_maxedout = false;
	}
}

#if DEBUG_DAMAGE_MOD
void debug_on_take_damage(int victim, int attacker, int inflictor, float damage)
{
	if (attacker > 0 && attacker <= MaxClients && IsClientInGame(attacker)) {
		char attacker_name[32];
		GetClientName(attacker, attacker_name, sizeof(attacker_name));
		char classname[32];
		if (attacker == inflictor)
			GetClientWeapon(inflictor, classname, sizeof(classname));
		else
			GetEdictClassname(inflictor, classname, sizeof(classname));
		if (victim > 0 && victim <= MaxClients && IsClientInGame(victim)) {
			char victim_name[32];
			GetClientName(victim, victim_name, sizeof(victim_name));
			PrintToChatAll("%s (%s) %f dmg to %s", attacker_name, classname, damage, victim_name);
		}
		else
			PrintToChatAll("%s (%s) %f dmg to victim %i", attacker_name, classname, damage, victim);
	}
}
#endif

// Extra stock functions
//

// Source https://forums.alliedmods.net/showthread.php?t=317145
// If <RETURN> </RETURN> is removed as suggested.
/**
* Runs a single line of VScript code and returns values from it.
*
* @param	code			The code to run.
* @param	buffer			Buffer to copy to.
* @param	maxlength		Maximum size of the buffer.
* @return	True on success, false otherwise.
* @error	Invalid code.
*/
stock bool GetVScriptOutput(char[] code, char[] buffer, int maxlength)
{
	static int logic = INVALID_ENT_REFERENCE;
	if( logic == INVALID_ENT_REFERENCE || !IsValidEntity(logic) )
	{
		logic = EntIndexToEntRef(CreateEntityByName("logic_script"));
		if( logic == INVALID_ENT_REFERENCE || !IsValidEntity(logic) )
			SetFailState("Could not create 'logic_script'");

		DispatchSpawn(logic);
	}
	Format(buffer, maxlength, "Convars.SetValue(\"sm_vscript_return\", \"\" + %s + \"\");", code);

	// Run code
	SetVariantString(buffer);
	AcceptEntityInput(logic, "RunScriptCode");
	AcceptEntityInput(logic, "Kill");

	// Retrieve value and return to buffer
	gCvarBuffer.GetString(buffer, maxlength);
	gCvarBuffer.SetString("");

	if( buffer[0] == '\x0')
		return false;
	return true;
}

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
Safe check is float val not zero.
*/
stock bool isn_zero(float val)
{
	return FloatAbs(val) >= 0.000001;
}