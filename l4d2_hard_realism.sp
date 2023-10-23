/*
Important note: HardRealism mode is designed for "mp_gamemode realism" and "z_difficulty Impossible".

Version description

Note: SI order = smoker, boomer, hunter, spitter, jockey, charger.

Version 20:
- Tank health is relative to the number of alive survivors.
- Smoker health is set to 300.
- Hunter health is set to 300.
- Hunter attack damage is set to 20.
- Spitter health is set to 150.
- Jockey health is set to 300.
- Jockey ride damage is set to 15.
- Jockey leap range is reduced to 150.
- Charger pound damage is set to 20.
- Special infected limit and maximum spawn size are relative to the number of alive survivors.
- Special infected spawn size minimum is 3.
- Special infected spawn sizes are random.
- Special infected spawn limits in the SI order are 2, 1, 2, 1, 2, 2.
- Special infected spawn weights in the SI order are 60, 100, 60, 100, 60, 60.
- Special infected spawn weight reduction factors in the SI order are 0.5, 1.0, 0.5, 1.0, 0.5, 0.5.
- Special infected spawns are randomly delayed in the range [0.3s, 2.2s].
- Horde max spawn time is reduced to 120.
- Shotguns are more effective against commons.
- SMG damage is increased by 8%.
- M16 damage is increased by 7%.
- SCAR damage is increased by 8%. 
- Hunting Rifle damage is increased by 12%.
- Military Sniper damage is increased by 12%.
- AWP damage is increased by 74%.
- Melee damage to tank is set to 400.
- Disable bots shooting through the survivors.
- Improved bots behavior.
*/

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#pragma semicolon 1
#pragma newdecls required

//MAJOR (gameplay change).MINOR.PATCH
#define VERSION "20.0.0"

//debug switches
#define DEBUG_DAMAGE_MOD 0
#define DEBUG_SI_SPAWN 0
#define DEBUG_TANK_HP 0

//teams
#define TEAM_SURVIVORS 2
#define TEAM_INFECTED 3

//zombie classes
#define ZOMBIE_CLASS_SMOKER 1
#define ZOMBIE_CLASS_BOOMER 2
#define ZOMBIE_CLASS_HUNTER 3
#define ZOMBIE_CLASS_SPITTER 4
#define ZOMBIE_CLASS_JOCKEY 5
#define ZOMBIE_CLASS_CHARGER 6
#define ZOMBIE_CLASS_TANK 8

//special infected spawner
//

//special infected types (for indexing)
//keep the same order as zombie classes
#define SI_TYPES 6
#define SI_INDEX_SMOKER 0
#define SI_INDEX_BOOMER 1
#define SI_INDEX_HUNTER 2
#define SI_INDEX_SPITTER 3
#define SI_INDEX_JOCKEY 4
#define SI_INDEX_CHARGER 5

#if DEBUG_SI_SPAWN
//keep the same order as zombie classes
static const char debug_si_indexes[SI_TYPES][] = { "SI_INDEX_SMOKER", "SI_INDEX_BOOMER", "SI_INDEX_HUNTER", "SI_INDEX_SPITTER", "SI_INDEX_JOCKEY", "SI_INDEX_CHARGER" };
#endif

//keep the same order as zombie classes
static const char z_spawns[SI_TYPES][] = { "smoker", "boomer", "hunter", "spitter", "jockey", "charger" };
static const int si_spawn_limits[SI_TYPES] = { 2, 1, 2, 1, 2, 2 };
static const int si_spawn_weights[SI_TYPES] = { 60, 100, 60, 100, 60, 60 };
static const float si_spawn_weight_mods[SI_TYPES] = { 0.5, 1.0, 0.5, 1.0, 0.5, 0.5 };

int alive_survivors;
int si_limit;

//spawn timer
Handle h_spawn_timer;
bool is_spawn_timer_running;

//

//tank health
int tank_hp;

//damage mod
Handle h_weapon_trie;

public Plugin myinfo = {
	name = "L4D2 HardRealism",
	author = "Garamond",
	description = "HardRealism mod",
	version = VERSION,
	url = "https://github.com/garamond13/L4D2-HardRealism"
};

public void OnPluginStart()
{
	//map damage mods
	h_weapon_trie = CreateTrie();
	SetTrieValue(h_weapon_trie, "weapon_smg", 1.08);
	SetTrieValue(h_weapon_trie, "weapon_rifle", 1.07);
	SetTrieValue(h_weapon_trie, "weapon_rifle_desert", 1.08);
	SetTrieValue(h_weapon_trie, "weapon_hunting_rifle", 1.12);
	SetTrieValue(h_weapon_trie, "weapon_sniper_military", 1.12);
	SetTrieValue(h_weapon_trie, "weapon_sniper_awp", 1.74);
	SetTrieValue(h_weapon_trie, "weapon_hunter_claw", 0.5);

	//hook game events
	HookEvent("player_left_safe_area", event_player_left_safe_area, EventHookMode_PostNoCopy);
	HookEvent("player_spawn", event_player_spawn);
	HookEvent("player_death", event_player_death);
	HookEvent("tank_spawn", event_tank_spawn, EventHookMode_Pre);
	HookEvent("round_end", event_round_end, EventHookMode_Pre);
}

public void OnConfigsExecuted()
{	
	//default 250
	SetConVarInt(FindConVar("z_gas_health"), 300);
	
	//default 250
	SetConVarInt(FindConVar("z_hunter_health"), 300);

	//default 5
	//it will be multiplied by 3 on Realsim Expert
	//it will be halved by on_take_damage()
	SetConVarInt(FindConVar("z_pounce_damage"), 10);
	
	//default 100
	SetConVarInt(FindConVar("z_spitter_health"), 150);

	//default 325
	SetConVarInt(FindConVar("z_jockey_health"), 300);

	//default 200
	SetConVarInt(FindConVar("z_jockey_leap_range"), 150);

	//default 4
	//it will be multiplied by 3 on Realsim Expert
	SetConVarInt(FindConVar("z_jockey_ride_damage"), 5);

	//default 15
	SetConVarInt(FindConVar("z_charger_pound_dmg"), 20);

	//default 180
	SetConVarInt(FindConVar("z_mob_spawn_max_interval_expert"), 120);

	//default 100
	SetConVarInt(FindConVar("z_shotgun_bonus_damage_range"), 150);
	
	//default 1
	SetConVarInt(FindConVar("sb_allow_shoot_through_survivors"), 0);

	//default 4
	SetConVarInt(FindConVar("sb_battlestation_human_hold_time"), 1);
	
	//default 0.5
	SetConVarFloat(FindConVar("sb_friend_immobilized_reaction_time_expert"), 0.1);

	//default 0
	SetConVarInt(FindConVar("sb_sidestep_for_horde"), 1);

	//disbale director spawn special infected
	SetConVarInt(FindConVar("z_smoker_limit"), 0);
	SetConVarInt(FindConVar("z_boomer_limit"), 0);
	SetConVarInt(FindConVar("z_hunter_limit"), 0);
	SetConVarInt(FindConVar("z_spitter_limit"), 0);
	SetConVarInt(FindConVar("z_jockey_limit"), 0);
	SetConVarInt(FindConVar("z_charger_limit"), 0);
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_OnTakeDamage, on_take_damage);
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (!strcmp(classname, "infected") || !strcmp(classname, "witch"))
		SDKHook(entity, SDKHook_OnTakeDamage, on_take_damage);
}

Action on_take_damage(int victim, int& attacker, int& inflictor, float& damage, int& damagetype)
{
	#if 0
	PrintToChatAll("attacker %i, inflictor %i dealt [%f] dmg to victim %i", attacker, inflictor, damage, victim);
	#endif

	if (attacker == inflictor && attacker > 0 && attacker <= MaxClients && IsClientInGame(attacker)) {
		char classname[32];
		GetClientWeapon(attacker, classname, sizeof(classname));

		//get damage modifier
		float mod;
		if (GetTrieValue(h_weapon_trie, classname, mod)) {
			damage *= mod;

			#if DEBUG_DAMAGE_MOD
			debug_on_take_damage(victim, attacker, inflictor, damage);
			#endif

			return Plugin_Changed;
		}
	}
	
	//melee damage to tank
	else if (victim > 0 && victim <= MaxClients && IsClientInGame(victim) && GetClientTeam(victim) == TEAM_INFECTED && GetEntProp(victim, Prop_Send, "m_zombieClass") == ZOMBIE_CLASS_TANK) {
		char classname[32];
		GetEdictClassname(inflictor, classname, sizeof(classname));
		
		//melee should do one instance of damage larger than zero and multiple instances of zero damage
		if (!strcmp(classname, "weapon_melee") && FloatAbs(damage) >= 0.000001) {
			damage = 400.0;

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

void event_player_left_safe_area(Event event, const char[] name, bool dontBroadcast)
{
	#if DEBUG_SI_SPAWN
	PrintToConsoleAll("[HR] event_player_left_safe_area()");
	#endif

	start_spawn_timer();
}

void event_player_spawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (client && IsClientInGame(client) && GetClientTeam(client) == TEAM_SURVIVORS) {

		//count on the next frame, fixes miscount on idle
		RequestFrame(survivor_check);

	}
}

void event_player_death(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (client && IsClientInGame(client) && GetClientTeam(client) == TEAM_SURVIVORS)
		survivor_check();
}

void survivor_check()
{
	//count alive survivors
	alive_survivors = 0;
	for (int i = 1; i <= MaxClients; ++i)
		if (IsClientInGame(i) && GetClientTeam(i) == TEAM_SURVIVORS && IsPlayerAlive(i))
			++alive_survivors;
	
	//set survior relative values
	si_limit = alive_survivors + 1;
	if (si_limit < 3)
		si_limit = 3;
	tank_hp = RoundToNearest(6000.0 * Pow(float(alive_survivors), 0.86));

	#if DEBUG_SI_SPAWN
	PrintToConsoleAll("[HR] survivor_check(): alive_survivors = %i", alive_survivors);
	PrintToConsoleAll("[HR] survivor_check(): si_limit = %i", si_limit);
	PrintToConsoleAll("[HR] survivor_check(): tank_hp = %i", tank_hp);
	#endif
}

void start_spawn_timer()
{
	float timer = GetRandomFloat(17.0, 38.0);
	h_spawn_timer = CreateTimer(timer, auto_spawn_si);
	is_spawn_timer_running = true;

	#if DEBUG_SI_SPAWN
	PrintToConsoleAll("[HR] start_spawn_timer(): timer = %f", timer);
	#endif
}

Action auto_spawn_si(Handle timer)
{
	is_spawn_timer_running = false;
	spawn_si();
	start_spawn_timer();
	return Plugin_Continue;
}

void spawn_si()
{
	//count special infected
	int si_type_counts[SI_TYPES] = { 0, 0, 0, 0, 0, 0 };
	int si_total_count = 0;
	for (int i = 1; i <= MaxClients; ++i) {
		if (IsClientInGame(i) && GetClientTeam(i) == TEAM_INFECTED && IsPlayerAlive(i)) {

			//detect special infected type by zombie class
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
			}
		}
	}

	if (si_total_count < si_limit) {
		
		//set spawn size
		int size = si_limit - si_total_count;
		if (size > 3)
			size = GetRandomInt(3, size);

		#if DEBUG_SI_SPAWN
		PrintToConsoleAll("[HR] spawn_si(): si_limit = %i; si_total_count = %i; size = %i", si_limit, si_total_count, size);
		#endif

		int tmp_weights[SI_TYPES];
		float delay = 0.0;
		while (size) {

			//calculate temporary weights and their weight sum, including reductions
			int tmp_wsum = 0;
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
				PrintToConsoleAll("[HR] spawn_si(): tmp_weights[%s] = %i", debug_si_indexes[i], tmp_weights[i]);
			#endif

			int index = GetRandomInt(1, tmp_wsum);

			#if DEBUG_SI_SPAWN
			PrintToConsoleAll("[HR] spawn_si(): index = %i", index);
			#endif

			//cycle trough weight ranges, find where the random index falls and pick an appropriate array index
			int range = 0;
			for (int i = 0; i < SI_TYPES; ++i) {
				range += tmp_weights[i];
				if (index <= range) {
					index = i;
					++si_type_counts[index];
					break;
				}
			}

			#if DEBUG_SI_SPAWN
			PrintToConsoleAll("[HR] spawn_si(): range = %i; tmp_wsum = %i; index = %s", range, tmp_wsum, debug_si_indexes[index]);
			#endif

			//prevent instant spam of all specials at once
			//min and max delays are chosen more for technical reasons than gameplay reasons
			delay += GetRandomFloat(0.3, 2.2);
			CreateTimer(delay, z_spawn_old, index, TIMER_FLAG_NO_MAPCHANGE);

			--size;
		}
	}

	#if DEBUG_SI_SPAWN
	else
		PrintToConsoleAll("[HR] spawn_si(): si_limit = %i; si_total_count = %i; SI LIMIT REACHED!", si_limit, si_total_count);
	#endif
}

Action z_spawn_old(Handle timer, any data)
{	
	int client = get_random_alive_survivor();
	if (client) {
		
		//create infected bot
		//without this we may not be able to spawn our special infected
		int bot = CreateFakeClient("Infected Bot");
		if (bot)
			ChangeClientTeam(bot, TEAM_INFECTED);

		static const char command[] = "z_spawn_old";

		//store command flags
		int flags = GetCommandFlags(command);

		//clear "sv_cheat" flag from the command
		SetCommandFlags(command, flags & ~FCVAR_CHEAT);

		FakeClientCommand(client, "z_spawn_old %s auto", z_spawns[data]);

		//restore command flags
		SetCommandFlags(command, flags);

		#if DEBUG_SI_SPAWN
		char buffer[32];
		GetClientName(client, buffer, sizeof(buffer));
		PrintToConsoleAll("[HR] z_spawn_old(): client = %i [%s]; z_spawns[%s] = %s", client, buffer, debug_si_indexes[data], z_spawns[data]);
		#endif

		//kick the bot
		if (bot && IsClientConnected(bot))
			KickClient(bot);

	}

	#if DEBUG_SI_SPAWN
	else
		PrintToConsoleAll("[HR] z_spawn_old(): INVALID CLIENT!");
	#endif

	return Plugin_Continue;
}

int get_random_alive_survivor()
{
	if (alive_survivors) {
		int[] clients = new int[alive_survivors];
		int index = 0;
		for (int i = 1; i <= MaxClients; ++i)
			if (IsClientInGame(i) && GetClientTeam(i) == TEAM_SURVIVORS && IsPlayerAlive(i))
				clients[index++] = i;
		return clients[GetRandomInt(0, alive_survivors - 1)];
	}
	return 0;
}

void event_tank_spawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (client) {
		SetEntProp(client, Prop_Data, "m_iMaxHealth", tank_hp);
		SetEntProp(client, Prop_Data, "m_iHealth", tank_hp);

		//the constant factor was calculated from default values
		SetConVarInt(FindConVar("tank_burn_duration_expert"), RoundToNearest(float(tank_hp) * 0.010625));

		#if DEBUG_TANK_HP
		PrintToConsoleAll("[HR] event_tank_spawn(): tank_hp = %i", tank_hp);
		PrintToConsoleAll("[HR] event_tank_spawn(): tank hp is %i", GetEntProp(client, Prop_Data, "m_iHealth"));
		PrintToConsoleAll("[HR] event_tank_spawn(): tank max hp is %i", GetEntProp(client, Prop_Data, "m_iMaxHealth"));
		PrintToConsoleAll("[HR] event_tank_spawn(): tank burn time is %i", GetConVarInt(FindConVar("tank_burn_duration_expert")));
		#endif
	}

	#if DEBUG_TANK_HP
	else
		PrintToConsoleAll("[HR] event_tank_spawn(): CLIENT WAS ZERO!");
	#endif
}

void event_round_end(Event event, const char[] name, bool dontBroadcast)
{
	end_spawn_timer();
}

public void OnMapEnd()
{
	end_spawn_timer();
}

void end_spawn_timer()
{
	if (is_spawn_timer_running) {
		CloseHandle(h_spawn_timer);
		is_spawn_timer_running = false;
	}
}