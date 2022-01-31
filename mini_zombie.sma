#include <amxmodx>
#include <amxmisc>
#include <cstrike>
#include <engine>
#include <fakemeta>
#include <fun>
#include <hamsandwich>
#include <xs>

#define PLUGIN "Zombie - Mystic Death"
#define VERSION "1.0"
#define AUTHOR "Internet"

/* Enums */

enum (+= 1111)
{
	TASK_READY = 1111,
	TASK_INFECTION_PRE,
	TASK_ROUND_SUPER,
	TASK_HUD,
}

new const zm_knife_model[] = "models/MD-Infection/v_knife_blood.mdl"
new const zm_zombie_model[] = "models/player/zombie_burned/zombie_burned.mdl"
new const zm_sound_die[][]  = { "MD-Infection/zombie_die1.wav", "MD-Infection/zombie_die2.wav", "MD-Infection/zombie_die3.wav", "MD-Infection/zombie_die4.wav", "MD-Infection/zombie_die5.wav" }
new const zm_sound_infect[][] = { "MD-Infection/zombie_infec1.wav", "MD-Infection/zombie_infec2.wav", "MD-Infection/zombie_infec3.wav" }
new const zm_sound_first[][] = { "MD-Infection/zombie_first1.wav", "MD-Infection/zombie_first2.wav", "MD-Infection/zombie_first3.wav", "MD-Infection/zombie_first4.wav"}
new const block_choose[][] = 
{ /*"chooseteam", "jointeam", */"buy", "buyequip", "usp", "glock", "deagle", "p228", "elites", "fn57", "m3", 
	"xm1014", "mp5", "tmp", "p90", "mac10", "ump45", "ak47", "galil", "famas", "sg552", "m4a1", 
	"aug", "scout", "awp", "g3sg1", "sg550", "m249", "vest", "vesthelm", "flash", "hegren", 
	"sgren", "defuser", "nvgs", "shield", "primammo", "secammo", "km45", "9x19mm", "nighthawk", "228compact", "12gauge", 
	"autoshotgun", "smg", "mp", "c90", "cv47", "defender", "clarion", "krieg552", "bullpup", "magnum", "d3au1", "krieg550", 
	"buyammo1", "buyammo2", "cl_autobuy", "cl_rebuy", "cl_setautobuy", "cl_setrebuy" 
}

// CSDM SPAWNS


const MAX_CSDM_SPAWNS = 128
const MAX_STATS_SAVED = 64

new g_spawnCount, g_spawnCount2 // available spawn points counter
new Float:g_spawns[MAX_CSDM_SPAWNS][3], Float:g_spawns2[MAX_CSDM_SPAWNS][3] // spawn points data

//

// DEFINES //

#define SHOWHUD (taskid - TASK_HUD)

/* Variables */

// Hud

new Hud

// Player vars

new g_weapon[33]

new g_level[33], g_exp[33]

new name[33][32]

new bool:g_nvg[33]

new bool:g_zombie[33]

new g_weap_name[32][32] = 
{
	"", "P228", "", "Scout", "He-Grenade",
	"XM-1014", "C4", "Mac-10", "AUG", "SmokeGrenade", "Dual Elites",
	"Five-Seven", "UMP45", "SG-550", "GALIL", "FAMAS", "USP", "Glock18",
	"Awp", "Mp5Navy", "M249", "M3", "M4A1", "TMP",
	"G3SG1", "FlashBang", "Desert Eagle", "SG-552", "AK-47",
	"Knife", "P90", ""
}

// Game Vars

new count_kill_zombies, count_kill_humans, count_kill_total 
new bool:new_round, bool:end_round, bool:infection_round
new bool:g_start = false, g_count

// Get maxplayers

new g_maxplayers

/* Cvars */

new g_zombie_hp, g_first_zombie_hp, g_zombie_speed, g_zombie_brain, g_clip_cost, g_clip_lost, g_light

//new menu_shotgun, menu_pistol, menu_smg
//new menu_sh_m3, menu_sh_xm, menu_pt_glock, menu_pt_usp, menu_pt_p228, menu_pt_deagle, menu_pt_fiveseven, menu_pt_elites, menu_smg_tmp, menu_smg_mac, menu_smg_mp5, menu_smg_p90, menu_smg_ump

public plugin_precache()
{
	new i
	
	for (  i = 0 ; i < sizeof zm_sound_die ; i++)
	precache_sound(zm_sound_die[i])
	
	for (  i = 0 ; i < sizeof zm_sound_infect ; i++)
	precache_sound(zm_sound_infect[i])
	
	for (  i = 0 ; i < sizeof zm_sound_first ; i++)
	precache_sound(zm_sound_first[i])
	
	precache_model(zm_knife_model)
	precache_model(zm_zombie_model)
	
	new const szRemoveEntities[ ][ ] = 
	{
		"func_hostage_rescue", "info_hostage_rescue", "game_player_equip",
		"func_bomb_target", "info_bomb_target", "hostage_entity",
		"info_vip_start", "func_vip_safetyzone", "func_escapezone",
		"info_map_parameters", "player_weaponstrip", "func_buyzone", "armoury_entity", "weapon_c4"/*,
		"func_breakable", "func_door", "func_door_rotating"*/
	}
    
	for( new i; i < sizeof szRemoveEntities; i++ )
		remove_entity_name( szRemoveEntities[ i ] )
    
	new iHostage = create_entity( "hostage_entity" )
	engfunc( EngFunc_SetOrigin, iHostage, { 0.0, 0.0, -55000.0 } )
	engfunc( EngFunc_SetSize, iHostage, { -1.0, -1.0, -1.0 }, { 1.0, 1.0, 1.0 } )
	dllfunc( DLLFunc_Spawn, iHostage )
	
	load_spawns()
}

public plugin_init() 
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	// Events
	
	register_event("Damage", "EventDamage", "b", "2!0", "3=0", "4!0") // Old Method
	
	register_event("HLTV", "HLTV", "a", "1=0", "2=0")
	
	register_logevent("logevent_round_end", 2, "1=Round_End")	
	
	// Forwards
	
	register_forward(FM_EmitSound, "Forward_EmitSound")
	
	RegisterHam(Ham_Killed, "player", "ham_killed_post", 1)
	
	RegisterHam(Ham_Spawn, "player", "ham_spawn_post", 1)
	
	RegisterHam(Ham_TakeDamage, "player", "ham_takedamage_post")
	
	RegisterHam(Ham_Touch, "armoury_entity", "TouchWeapon")
	
	RegisterHam(Ham_Touch, "weaponbox", "TouchWeapon")
	
	RegisterHam(Ham_Touch, "weapon_shield", "TouchWeapon")
	
	// Client commands
	
	for ( new id = 0 ; id < sizeof block_choose ; id++)
		register_clcmd(block_choose[id], "block")
	
	register_clcmd("nightvision", "nvg")
	
	register_clcmd("buyammo1", "buyammo")
	
	register_clcmd("buyammo2", "buyammo")
	
	// Message hooks
	
	register_message(get_user_msgid("CurWeapon"), "update_weapon")
	
	register_message(get_user_msgid("TextMsg"), "message_textmsg")
	//register_message(get_user_msgid("TeamInfo"), "message_teaminfo")
	
	// Cvars
	
	g_zombie_hp = register_cvar("amx_zombie_health", "1700")
	g_first_zombie_hp = register_cvar("amx_zombie_first_health", "3400")
	g_zombie_speed = register_cvar("amx_zombie_speed", "210")
	g_zombie_brain = register_cvar("amx_zombie_brain_health", "300")
	g_clip_cost = register_cvar("amx_human_clip_cost", "3000")
	g_clip_lost = register_cvar("amx_human_clip_lost", "500")
	g_light = register_cvar("amx_zmod_light", "n")
	
	// Tasks
	
	set_task(50.0, "PlayersCount", _,_,_, "b")
	
	// Get Max Players
	
	g_maxplayers = get_maxplayers()
	
	// Create the HUD Sync Objects
	
	Hud = CreateHudSyncObj()
}

//
// Main Events
//

// Event Damage

public EventDamage( victim )
{
	new attacker = get_user_attacker( victim )
	
	if(victim == attacker || get_user_team(victim) == get_user_team(attacker) || !is_user_connected(attacker)) return;
	
	if(g_zombie[attacker])
	{	
		new total_ct
		
		for ( new id = 1 ; id <= g_maxplayers ; id++ )
		{
			if(is_user_alive(id) && !g_zombie[id])
				total_ct++
		}
		
		if ( total_ct != 1 )
		{
			if(is_user_alive(victim) )
			{
				get_user_name(attacker, name[attacker], 32)
				get_user_name(victim, name[victim], 32)
				
				emit_sound(victim, CHAN_VOICE,  zm_sound_infect[random(sizeof zm_sound_infect)], 1.0, ATTN_NORM, 0, PITCH_NORM)
				message_begin(MSG_BROADCAST, get_user_msgid("DeathMsg"))
				write_byte(attacker)
				write_byte(victim) 
				write_byte(1)
				write_string("infection") 
				message_end()
				
				message_begin(MSG_BROADCAST, get_user_msgid("ScoreAttrib"))
				write_byte(victim)
				write_byte(0)
				message_end()
				
				set_user_health(attacker, get_user_health(attacker) + get_pcvar_num(g_zombie_brain))
				
				set_hudmessage(255, 0, 0, 0.0, -1.0, 0, 6.0, 3.0)
				show_hudmessage(0, "%s brains was eaten by %s!", name[victim], name[attacker])
				set_task(0.1, "user_infected", victim)
				g_zombie[victim] = true
			}
		}
	}
}

// Round Start (FreeZetime)

public HLTV()
{
	for ( new id = 1 ; id <= g_maxplayers ; id++ )
	{
		if(is_user_connected(id))
		{
			cs_reset_user_model(id)
			remove_task(id+TASK_HUD)
			g_zombie[id] = false
		}
	}

	count_kill_zombies = 0
	count_kill_humans = 0
	count_kill_total = 0
	end_round = false
	infection_round = false
	new_round = true
	lights()
	
	switch(random_num(0,2))
	{
		case 0:
		{
			//set_lights("a")
			set_task(random_float(4.0 , 5.0), "infection", TASK_INFECTION_PRE)
		}
		case 1: 
		{ 
			//set_lights("b")
			set_task(random_float(10.0 , 15.0), "infection", TASK_INFECTION_PRE)
		}
		case 2:
		{
			set_task(random_float(7.0 , 10.0), "infection", TASK_INFECTION_PRE)
			//set_lights("c")
		}
	}
}

// Round Ended

public logevent_round_end( )
{
	for ( new id = 0 ; id <= g_maxplayers ; id++ )
	{			
		if(is_user_connected(id))
		{
			g_zombie[id] = false
			g_nvg[id] = false
		}
	} 
	
	remove_task(TASK_READY)
	remove_task(TASK_INFECTION_PRE)
	balance_teams()
	end_round = true
	infection_round = false
}

/*================================================================================
 [Main Forwards]
=================================================================================*/

public client_disconnect(id)
{
	remove_task(id+TASK_HUD)
}
	
public client_putinserver(id)
{
	//Level_Up(g_level[id] = 2)
	set_task(0.1, "join", id)
	
	/* Waiting Players */
	if(!g_start)
	{
		g_start = true
		g_count = 60
		set_task(1.0, "waiting_function", 8550,  _,_, "b")
	}
}

public Forward_EmitSound(id, channel, sample[], Float:volume, Float:attn, flag, pitch)
{
	if(!is_user_connected(id))
		return FMRES_IGNORED

	if(g_zombie[id])
	{

		//PAIN
		if (sample[1] == 'l' && sample[2] == 'a' && sample[3] == 'y' && ( (containi(sample, "bhit") != -1) || (containi(sample, "pain") != -1) || (containi(sample, "shot") != -1)))
		{
		//	emit_sound(id, CHAN_VOICE, zm_sound_pain[random(sizeof zm_sound_pain)], volume, attn, flag, pitch)
			return FMRES_SUPERCEDE
		}
		//DEATH
		else if (sample[7] == 'd' && (sample[8] == 'i' && sample[9] == 'e' || sample[12] == '6'))
		{
			emit_sound(id, CHAN_VOICE, zm_sound_die[random(sizeof zm_sound_die)], volume, attn, flag, pitch)
		}
		else if (sample[6] == 'n' && sample[7] == 'v' && sample[8] == 'g')
			return FMRES_SUPERCEDE
	}
	else
	{
			if (sample[6] == 'n' && sample[7] == 'v' && sample[8] == 'g')
				return FMRES_SUPERCEDE
	}

	return FMRES_IGNORED
}

public ham_killed_post(victim, attacker, shouldgib)
{
	if(g_zombie[victim])
	{
		count_kill_zombies++
		emit_sound(victim, CHAN_VOICE, zm_sound_die[random(sizeof zm_sound_die)], 1.0, ATTN_NORM, 0, PITCH_NORM)
	}
	else if(!g_zombie[victim])
	{
		count_kill_humans++
	}
	
	set_task(1.0, "hud", victim+TASK_HUD, _,_, "b")
	count_kill_total++	
}

public ham_spawn_post(id)
{
	if(!is_user_connected(id))
		return;
		
	if(infection_round)
	{
		cs_reset_user_model(id)
		cs_set_user_team(id, CS_TEAM_CT)
	}
	
	new message[64]
	
	formatex(message, charsmax(message), "[ZM]-[XP] Level: %d XP:%d", g_level[id], g_exp[id])
	
	message_begin(MSG_ONE_UNRELIABLE, get_user_msgid("StatusText"), _, id)
	write_byte(0)
	write_string(message)
	message_end()
	
	do_random_spawn(id)
	g_zombie[id] = false
	menu_weapon(id)
	remove_task(id+TASK_HUD)
}

public ham_takedamage_post(victim, inflictor, attacker, Float:damage, dmg_bits)
{
	if(new_round || end_round)
		return HAM_SUPERCEDE
		
	return HAM_HANDLED
}


public TouchWeapon(weapon, id)
{
	if (!is_user_alive(id))
		return HAM_IGNORED
	
	if (g_zombie[id])
		return HAM_SUPERCEDE
	
	return HAM_IGNORED
}

/*================================================================================
 [Client Commands]
=================================================================================*/

public block(id)
	return PLUGIN_HANDLED_MAIN
	

public nvg(id)
{
	if(!is_user_connected(id) || is_user_bot(id))
		return
	
	if(cs_get_user_team(id) == CS_TEAM_SPECTATOR || cs_get_user_team(id) == CS_TEAM_UNASSIGNED)
		g_nvg[id] = !g_nvg[id]
	else if(!is_user_alive(id))
		g_nvg[id] = !g_nvg[id]
	else if(is_user_alive(id) && g_zombie[id])
		g_nvg[id] = !g_nvg[id]
	
	g_nvg[id] ? set_user_gnvision(id, 1) : set_user_gnvision(id, 0)
}	

public buyammo(id)
{
	if(!is_user_alive(id) || g_zombie[id])
		return
		
	if(cs_get_user_money(id) > get_pcvar_num(g_clip_cost))
	{
		client_print(id, print_chat, "[ZM] Extra ammo bought!")
		cs_set_user_money(id, cs_get_user_money(id) - get_pcvar_num(g_clip_lost))
		UTIL_GiveWeaponAmmo(id)
	}
	else
	{
		client_print(id, print_chat, "[ZM] You don't have enough money to purchase extra ammo! You require at least $1500.")
	}
}

/*================================================================================
 [Menus]
=================================================================================*/

/* Weapon Menu! */

public menu_weapon(id)
{
	new gMenu = menu_create("\yZombie Mod Infection Weapon Menu:", "handlerweapon")
	    
	menu_additem(gMenu, "Shotguns", "1") 
	menu_additem(gMenu, "SMG", "2")
	menu_display(id, gMenu, 0)
}

public handlerweapon(id, menu, item)       
{
	
    if ( item == MENU_EXIT || !is_user_alive(id ) || g_zombie[id]) 
    {
        menu_destroy(menu)        
        return PLUGIN_HANDLED
    }
    
    if(user_has_weapon(id, CSW_C4))
        ham_strip_weapon(id, "weapon_c4")
    
    switch(item) 
    {
        case 0:  
            menu_weapon_shotgun(id)
      
        case 1:  
            menu_weapon_smg(id)
        
    }
    return PLUGIN_HANDLED
} 

public menu_weapon_shotgun(id)
{
	new gMenu = menu_create("\yZombie Mod Infection Weapon Menu \r[Shotguns]", "handlerweaponshotgun")
	    
	menu_additem(gMenu, "Leone 12 Gauge Super", "1") 
	menu_additem(gMenu, "Leone YG1265 Auto Shotgun", "2")
	menu_display(id, gMenu, 0)
}

public handlerweaponshotgun(id, menu, item)       
{	
    if ( item == MENU_EXIT || !is_user_alive(id ) || g_zombie[id]) 
    {
        menu_destroy(menu)        
        return PLUGIN_HANDLED
    }
    
    switch(item) 
    {
	case 0:  
	{
		drop_weapons(id, 1)
		give_user_weapon(id, CSW_M3, 8, 32)
		menu_weapon_pistol(id)
	}
	case 1:  
	{
		
		drop_weapons(id, 1)
		give_user_weapon(id, CSW_XM1014, 7, 32)
		menu_weapon_pistol(id)
	}
    }
    return PLUGIN_HANDLED
} 

public menu_weapon_smg(id)
{
	new gMenu = menu_create("\yZombie Mod Infection Weapon Menu \r[SMGs]", "handlerweaponsmg")
	    
	menu_additem(gMenu, "Ingram MAC-10", "1") 
	menu_additem(gMenu, "Schmidt TMP", "2")
	menu_additem(gMenu, "UMP 45", "3") 
	menu_additem(gMenu, "MP5 Navy", "4")
	menu_additem(gMenu, "ES P90", "5")
	menu_display(id, gMenu, 0)
}
public handlerweaponsmg(id, menu, item)
{
    if ( item == MENU_EXIT || !is_user_alive(id ) || g_zombie[id]) 
    {
        menu_destroy(menu)        
        return PLUGIN_HANDLED
    }
    switch(item) 
    {
	case 0:  
	{
		
		drop_weapons(id, 1)
		give_user_weapon(id, CSW_MAC10, 30, 120)
		menu_weapon_pistol(id)
	}
	case 1:  
	{
		
		drop_weapons(id, 1)
		give_user_weapon(id, CSW_TMP, 30, 120)
		menu_weapon_pistol(id)
	}
	case 2:  
	{
		
		drop_weapons(id, 1)
		give_user_weapon(id, CSW_UMP45, 25, 100)
		menu_weapon_pistol(id)
	}
	case 3:  
	{
		
		drop_weapons(id, 1)
		give_user_weapon(id, CSW_MP5NAVY, 30, 120)
		menu_weapon_pistol(id)
	}
	case 4:  
	{
		
		drop_weapons(id, 1)
		give_user_weapon(id, CSW_P90, 50, 100)
		menu_weapon_pistol(id)
	}
    }
    return PLUGIN_HANDLED  
} 

public menu_weapon_pistol(id)
{
	new gMenu = menu_create("\yZombie Mod Infection Weapon Menu \r[Pistols]", "handlerweaponpistol")
	    
	menu_additem(gMenu, "9x19MM Sidearm", "1") 
	menu_additem(gMenu, "KM .45 Tactical", "2")
	menu_additem(gMenu, "228 Compact", "3") 
	menu_additem(gMenu, "Night Hawk .50C", "4")
	menu_additem(gMenu, "Five-Seven", "5") 
	menu_additem(gMenu, ".40 Dual Elites", "6")
	menu_display(id, gMenu, 0)
}

public handlerweaponpistol(id, menu, item)       
{
    if ( item == MENU_EXIT || !is_user_alive(id ) || g_zombie[id]) 
    {
        menu_destroy(menu)        
        return PLUGIN_HANDLED   
    }
    switch(item) 
    {
	case 0:  
	{
		drop_weapons(id, 2)
		give_user_weapon(id, CSW_GLOCK18, 20, 120)
	}
	case 1:  
	{
		drop_weapons(id, 2)
		give_user_weapon(id, CSW_USP, 12, 100)
	}
	case 2:  
	{
		drop_weapons(id, 2)
		give_user_weapon(id, CSW_P228, 13, 52)
	}
	case 3:  
	{
		drop_weapons(id, 2)
		give_user_weapon(id, CSW_DEAGLE, 7, 35)
	}
	case 4:  
	{
		drop_weapons(id, 2)
		give_user_weapon(id, CSW_FIVESEVEN, 20, 100)
		
	}
	case 5:  
	{
		drop_weapons(id, 2)
		give_user_weapon(id, CSW_ELITE, 30, 120)	
	}
    }
    menu_grenade(id)
    return PLUGIN_HANDLED
} 

public menu_grenade(id)
{
	new gMenu = menu_create("\yZombie Mod Infection Weapon Menu \r[Grenades]", "handlerweaponnade")
	    
	menu_additem(gMenu, "He Grenade", "1") 
	menu_additem(gMenu, "Smoke Grenade", "2")
	menu_additem(gMenu, "Both Grenades", "3") 
	menu_display(id, gMenu, 0)
}
public handlerweaponnade(id, menu, item)
{
	if ( item == MENU_EXIT || !is_user_alive(id ) || g_zombie[id]) 
	{
		menu_destroy(menu)        
		return PLUGIN_HANDLED  
	}
	
	switch(item) 
	{
		case 0:  
			give_item(id, "weapon_hegrenade")
	
		case 1:  
			give_item(id, "weapon_smokegrenade")
	
		case 2:  
		{
			give_item(id, "weapon_hegrenade")
			give_item(id, "weapon_smokegrenade")
		}
	}
	return PLUGIN_HANDLED
} 

/*================================================================================
 [Message Hooks]
=================================================================================*/

public update_weapon(msg_id, msg_dest, id)
{
	if(get_msg_arg_int(1))
		g_weapon[id] = get_msg_arg_int(2)
		
	replace_models(id)	
		
	if(g_zombie[id] && g_weapon[id] != CSW_KNIFE)
		engclient_cmd(id, "weapon_knife")
}

public message_textmsg()
{
	static message[38]
	get_msg_arg_string(2, message, charsmax(message))

	if(equal(message, "#Terrorists_Win"))
	{
		set_hudmessage(255, 0, 0, -1.0, 0.2, 0, 6.0, 5.0)
		show_hudmessage(0, "[ZM] Zombies have taken over the world!")
		client_print(0, print_chat, "[ZM] Zombies have taken over the world!")
	}
	else if(equal(message, "#CTs_Win"))
	{
		set_hudmessage(0, 0, 255, -1.0, 0.3, 0, 6.0, 5.0)
		show_hudmessage(0, "[ZM] All of the zombies have been killed!")
		client_print(0, print_chat, "[ZM] All of the zombies have been killed!")
	}
	else if(equal(message, "#Round_Draw") || equal(message, "#Game_Commencing") || equal(message, "#Target_Saved") || equal(message, "#Game_will_restart_in") )
	{
		set_hudmessage(255, 255, 255, -1.0, 0.3, 0, 6.0, 5.0)
		show_hudmessage(0, "[ZM] No one won...")
		client_print(0, print_chat, "[ZM] No one won...")
		logevent_round_end( )
	}
}
/*
public message_teaminfo(msg_id, msg_dest)
{
	// Only hook global messages
	if(msg_dest != MSG_ALL && msg_dest != MSG_BROADCAST) return;

	// Don't pick up our own TeamInfo messages for this player (bugfix)
	if(g_switchingteam) return;

	// Get player's id
	static id
	id = get_msg_arg_int(1)

	// Invalid player id? (bugfix)
	if (!(1 <= id <= g_maxplayers)) return;	

	// Get his new team
	static team[2]
	get_msg_arg_string(2, team, charsmax(team))

	// Perform some checks to see if they should join a different team instead
	switch (team[0])
	{
		case 'C': // CT
		{
			
			//g_respawn_as_zombie[id] = true;
			remove_task(id+TASK_TEAM)
			cs_set_user_team(id, CS_TEAM_T)
			set_msg_arg_string(2, "TERRORIST")
		}
		case 'T': // Terrorist
		{	
			remove_task(id+TASK_TEAM)
			v(id, FM_CS_TEAM_CT)
			set_msg_arg_string(2, "CT")
		}
	}
}
*/

/*================================================================================
 [Main Functions]
=================================================================================*/

// Reemplace models

public replace_models(id)
{
	if (!is_user_alive(id)) // not alive
		return
	
	
	if (g_weapon[id] == CSW_KNIFE) // custom knife models
	{
		if (g_zombie[id] && !new_round && !end_round)
		{
			set_pev(id, pev_viewmodel2, zm_knife_model)
			set_pev(id, pev_weaponmodel2, "")
			set_user_maxspeed(id, get_pcvar_float(g_zombie_speed))
		}
	}
}

// Auto Join Team

public join(id)
{
	new teammsg_block, teammsg_block_vgui, restore, vgui
	restore = get_pdata_int(id, 510)
	vgui = restore & (1<<0)
	    
	if (vgui)    set_pdata_int(id, 510, restore & ~(1<<0))
	    
	teammsg_block = get_msg_block(get_user_msgid("ShowMenu"))
	teammsg_block_vgui = get_msg_block(get_user_msgid("VGUIMenu"))
	    
	set_msg_block(get_user_msgid("ShowMenu"), BLOCK_ONCE)
	set_msg_block(get_user_msgid("VGUIMenu"), BLOCK_ONCE)
	    
	engclient_cmd(id, "jointeam", "5")
	engclient_cmd(id, "joinclass", "5")
	    
	set_msg_block(get_user_msgid("ShowMenu"), teammsg_block)
	set_msg_block(get_user_msgid("VGUIMenu"), teammsg_block_vgui)
}

// Start mode infection

public infection()
{
	
	if(get_playersnum() > 0)
	{
		for ( new id = 0 ; id <= g_maxplayers ; id++ )
		{		
			if(is_user_connected(id))
			{
				cs_set_user_team(id, CS_TEAM_CT)
				//fm_user_team_update(id)
				
			}
		}
		
		new rdm_ply = GetRandomPlayer()
		get_user_name(rdm_ply, name[rdm_ply], 32)
		user_infected(rdm_ply)
		set_user_health(rdm_ply, get_pcvar_num(g_first_zombie_hp))
		emit_sound(rdm_ply, CHAN_STREAM,  zm_sound_first[random(sizeof zm_sound_first)], 1.0, ATTN_NORM, 0, PITCH_NORM)
		set_hudmessage(255, 0, 0, -1.0, 0.3, 0, 6.0, 5.0)
		show_hudmessage(0, "BEWARE! %s IS THE FIRST ZOMBIE!!", name[rdm_ply])
		new_round = false
		infection_round = true
	}
	else
		set_task(5.0, "infection", TASK_INFECTION_PRE)
}

// Hud to show HP

public hud(taskid)
{
	static id
	id = SHOWHUD
    
	if (!is_user_alive(id))
	{
		id = pev(id, pev_iuser2)
		if (!is_user_alive(id)) return
	}
	
	if(id != SHOWHUD)
	{
		
		new clip, ammo
		get_user_weapon(id, clip, ammo)
		
		get_user_name(id, name[id], 32)
		
		if(g_weapon[id] == CSW_KNIFE)
		{
			set_hudmessage(255, 255, 255, 0.01, 0.22, 0, 6.0, 0.9)
			ShowSyncHudMsg(SHOWHUD, Hud, "Spectating: %s^n    Health: %d    Armor: %d^n    Weapon: %s", name[id], get_user_health(id), get_user_armor(id), g_weap_name[g_weapon[id]])
		}
		else
		{
			set_hudmessage(255, 255, 255, 0.01, 0.22, 0, 6.0, 0.9)
			ShowSyncHudMsg(SHOWHUD, Hud, "Spectating: %s^n    Health: %d    Armor: %d^n    Weapon: %s    Ammo: %d/%d", name[id], get_user_health(id), get_user_armor(id), g_weap_name[g_weapon[id]], clip, ammo)
		
		}
	}
	else
	{
		set_hudmessage(255, 255, 255, 0.01, 0.22, 0, 6.0, 0.9)
		ShowSyncHudMsg(SHOWHUD, Hud, "    Health: %d^n^n^n^n^n^n    Armor: %d", get_user_health(SHOWHUD), get_user_armor(SHOWHUD))
	}
} 

// Auto-Restart

public waiting_function()
{
	g_count--
	
	if(g_count > 0)
	{
		set_hudmessage(255, 255, 255, -1.0, 0.2, 0, 2.0, 1.5)
		show_hudmessage(0, "[ZM] Waiting for players to connect. ^nGame will restart in %d seconds", g_count)
	}
	
	else 
	{
		set_cvar_num("sv_restartround", 5)
		remove_task(8550)
	}
}

public PlayersCount()
{
	new Players[32], Num, id
	new count_t, count_ct, count_spec, count_dead
	get_players( Players, Num)
		
	count_ct = 0
	count_t = 0
	count_spec = 0
	count_dead = 0
		
	for(new i = 0; i < Num; i++)
	{
		id = Players[i]
		
		if(is_user_alive(id))
		{
			if(!g_zombie[id]) count_ct++
			if(g_zombie[id]) count_t++
		}
		else if(!is_user_alive(id))
			count_dead++
		
		if(cs_get_user_team(id) == CS_TEAM_SPECTATOR) 
			count_spec++
		
	}
	
	set_hudmessage(255, 255, 255, 0.6, -1.0, 0, 6.0, 5.0)
	show_hudmessage(0, "Players Count:      ^n^nAlive Humans: %d  ^nAlive Zombies: %d  ^nHumans Killed: %d  ^nZombies Killed: %d  ^nDead Players: %d  ^nSpectators: %d  ^nTotal Players: %d  ", count_ct, count_t,count_kill_humans, count_kill_zombies, count_dead, count_spec, get_playersnum())	
}

public user_infected(id)
{
	if(is_user_alive(id))
	{
		drop_weapons(id, 1)
		drop_weapons(id, 2)
		ham_strip_weapon(id, "weapon_c4")
		ham_strip_weapon(id, "weapon_hegrenade")
		ham_strip_weapon(id, "weapon_flashbang")
		ham_strip_weapon(id, "weapon_smokegrenade")
		cs_set_user_team(id, CS_TEAM_T)
		set_user_health(id, get_pcvar_num(g_zombie_hp))
		cs_set_user_model(id, "zombie_burned")
		client_print(id, print_chat, "[ZM] You are a zombie. Slash the humans and turn them into zombies!")
		set_pev(id, pev_viewmodel2, zm_knife_model)
		set_pev(id, pev_weaponmodel2, "")
		set_task(1.0, "hud", id+TASK_HUD, _,_, "b")
		g_zombie[id] = true
	}
}


// Balance Teams Task
balance_teams()
{
	// Get amount of users playing
	new players_count = get_playersnum()
    
	// No players, don't bother
	if (players_count < 1) return;
    
	// Split players evenly
	new iTerrors
	new iMaxTerrors = players_count / 2
	new id, CsTeams:team
    
    // First, set everyone to CT
	for (id = 1; id <= g_maxplayers; id++)
	{
		// Skip if not connected
		if (!is_user_connected(id))
			continue;
        
		team = cs_get_user_team(id)
        
        // Skip if not playing
		if (team == CS_TEAM_SPECTATOR || team == CS_TEAM_UNASSIGNED)
			continue;
        
        // Set team
		cs_set_user_team(id, CS_TEAM_CT)
	}
    
    // Then randomly move half of the players to Terrorists
	while (iTerrors < iMaxTerrors)
	{
		// Keep looping through all players
		if (++id > g_maxplayers) id = 1
		
		// Skip if not connected
		if (!is_user_connected(id))
			continue;
		
		team = cs_get_user_team(id)
		
		// Skip if not playing or already a Terrorist
		if (team != CS_TEAM_CT)
			continue;
		
		// Random chance
		if (random_num(0, 1))
		{
			cs_set_user_team(id, CS_TEAM_T)
			iTerrors++
		}
	}
}

// Place user at a random spawn
do_random_spawn(id, regularspawns = 0)
{
	static hull, sp_index, i
	
	// Get whether the player is crouching
	hull = (pev(id, pev_flags) & FL_DUCKING) ? HULL_HEAD : HULL_HUMAN
	
	// Use regular spawns?
	if (!regularspawns)
	{
		// No spawns?
		if (!g_spawnCount)
			return;
		
		// Choose random spawn to start looping at
		sp_index = random_num(0, g_spawnCount - 1)
		
		// Try to find a clear spawn
		for (i = sp_index + 1; /*no condition*/; i++)
		{
			// Start over when we reach the end
			if (i >= g_spawnCount) i = 0
			
			// Free spawn space?
			if (is_hull_vacant(g_spawns[i], hull))
			{
				// Engfunc_SetOrigin is used so ent's mins and maxs get updated instantly
				engfunc(EngFunc_SetOrigin, id, g_spawns[i])
				break;
			}
			
			// Loop completed, no free space found
			if (i == sp_index) break;
		}
	}
	else
	{
		// No spawns?
		if (!g_spawnCount2)
			return;
		
		// Choose random spawn to start looping at
		sp_index = random_num(0, g_spawnCount2 - 1)
		
		// Try to find a clear spawn
		for (i = sp_index + 1; /*no condition*/; i++)
		{
			// Start over when we reach the end
			if (i >= g_spawnCount2) i = 0
			
			// Free spawn space?
			if (is_hull_vacant(g_spawns2[i], hull))
			{
				// Engfunc_SetOrigin is used so ent's mins and maxs get updated instantly
				engfunc(EngFunc_SetOrigin, id, g_spawns2[i])
				break;
			}
			
			// Loop completed, no free space found
			if (i == sp_index) break;
		}
	}
}

// Collect random spawn points
stock load_spawns()
{
	// Check for CSDM spawns of the current map
	new cfgdir[32], mapname[32], filepath[100], linedata[64]
	get_configsdir(cfgdir, charsmax(cfgdir))
	get_mapname(mapname, charsmax(mapname))
	formatex(filepath, charsmax(filepath), "%s/csdm/%s.spawns.cfg", cfgdir, mapname)
	
	// Load CSDM spawns if present
	if (file_exists(filepath))
	{
		new csdmdata[10][6], file = fopen(filepath,"rt")
		
		while (file && !feof(file))
		{
			fgets(file, linedata, charsmax(linedata))
			
			// invalid spawn
			if(!linedata[0] || str_count(linedata,' ') < 2) continue;
			
			// get spawn point data
			parse(linedata,csdmdata[0],5,csdmdata[1],5,csdmdata[2],5,csdmdata[3],5,csdmdata[4],5,csdmdata[5],5,csdmdata[6],5,csdmdata[7],5,csdmdata[8],5,csdmdata[9],5)
			
			// origin
			g_spawns[g_spawnCount][0] = floatstr(csdmdata[0])
			g_spawns[g_spawnCount][1] = floatstr(csdmdata[1])
			g_spawns[g_spawnCount][2] = floatstr(csdmdata[2])
			
			// increase spawn count
			g_spawnCount++
			if (g_spawnCount >= sizeof g_spawns) break;
		}
		if (file) fclose(file)
	}
	else
	{
		// Collect regular spawns
		collect_spawns_ent("info_player_start")
		collect_spawns_ent("info_player_deathmatch")
	}
	
	// Collect regular spawns for non-random spawning unstuck
	collect_spawns_ent2("info_player_start")
	collect_spawns_ent2("info_player_deathmatch")
}

// Collect spawn points from entity origins
stock collect_spawns_ent(const classname[])
{
	new ent = -1
	while ((ent = engfunc(EngFunc_FindEntityByString, ent, "classname", classname)) != 0)
	{
		// get origin
		new Float:originF[3]
		pev(ent, pev_origin, originF)
		g_spawns[g_spawnCount][0] = originF[0]
		g_spawns[g_spawnCount][1] = originF[1]
		g_spawns[g_spawnCount][2] = originF[2]
		
		// increase spawn count
		g_spawnCount++
		if (g_spawnCount >= sizeof g_spawns) break;
	}
}

// Collect spawn points from entity origins
stock collect_spawns_ent2(const classname[])
{
	new ent = -1
	while ((ent = engfunc(EngFunc_FindEntityByString, ent, "classname", classname)) != 0)
	{
		// get origin
		new Float:originF[3]
		pev(ent, pev_origin, originF)
		g_spawns2[g_spawnCount2][0] = originF[0]
		g_spawns2[g_spawnCount2][1] = originF[1]
		g_spawns2[g_spawnCount2][2] = originF[2]
		
		// increase spawn count
		g_spawnCount2++
		if (g_spawnCount2 >= sizeof g_spawns2) break;
	}
}

// Checks if a space is vacant (credits to VEN)
stock is_hull_vacant(Float:origin[3], hull)
{
	engfunc(EngFunc_TraceHull, origin, origin, 0, hull, 0, 0)
	
	if (!get_tr2(0, TR_StartSolid) && !get_tr2(0, TR_AllSolid) && get_tr2(0, TR_InOpen))
		return true;
	
	return false;
}

// Check if a player is stuck (credits to VEN)
stock is_player_stuck(id)
{
	static Float:originF[3]
	pev(id, pev_origin, originF)
	
	engfunc(EngFunc_TraceHull, originF, originF, 0, (pev(id, pev_flags) & FL_DUCKING) ? HULL_HEAD : HULL_HUMAN, id, 0)
	
	if (get_tr2(0, TR_StartSolid) || get_tr2(0, TR_AllSolid) || !get_tr2(0, TR_InOpen))
		return true;
	
	return false;
}

stock str_count(const str[], searchchar)
{
	new count, i, len = strlen(str)
	
	for (i = 0; i <= len; i++)
	{
		if(str[i] == searchchar)
			count++
	}
	
	return count;
}


stock drop_weapons(id, dropwhat)
{
	// Get user weapons
	static weapons[32], num, i, weaponid
	num = 0 // reset passed weapons count (bugfix)
	get_user_weapons(id, weapons, num)
	
	// Loop through them and drop primaries or secondaries
	for (i = 0; i < num; i++)
	{
		// Prevent re-indexing the array
		weaponid = weapons[i]
		const PRIMARY_WEAPONS_BIT_SUM = (1<<CSW_SCOUT)|(1<<CSW_XM1014)|(1<<CSW_MAC10)|(1<<CSW_AUG)|(1<<CSW_UMP45)|(1<<CSW_SG550)|(1<<CSW_GALIL)|(1<<CSW_FAMAS)|(1<<CSW_AWP)|(1<<CSW_MP5NAVY)|(1<<CSW_M249)|(1<<CSW_M3)|(1<<CSW_M4A1)|(1<<CSW_TMP)|(1<<CSW_G3SG1)|(1<<CSW_SG552)|(1<<CSW_AK47)|(1<<CSW_P90)
		const SECONDARY_WEAPONS_BIT_SUM = (1<<CSW_P228)|(1<<CSW_ELITE)|(1<<CSW_FIVESEVEN)|(1<<CSW_USP)|(1<<CSW_GLOCK18)|(1<<CSW_DEAGLE)

		
		if ((dropwhat == 1 && ((1<<weaponid) & PRIMARY_WEAPONS_BIT_SUM)) || (dropwhat == 2 && ((1<<weaponid) & SECONDARY_WEAPONS_BIT_SUM)))
		{
			// Get weapon entity
			static wname[32], weapon_ent
			get_weaponname(weaponid, wname, charsmax(wname))
			weapon_ent = fm_find_ent_by_owner(-1, wname, id)
			
			// Hack: store weapon bpammo on PEV_ADDITIONAL_AMMO
			set_pev(weapon_ent, pev_iuser1, cs_get_user_bpammo(id, weaponid))
			
			// Player drops the weapon and looses his bpammo
			engclient_cmd(id, "drop", wname)
			cs_set_user_bpammo(id, weaponid, 0)
		}
	}
}

// GetRandomPlayer

stock GetRandomPlayer()
{
	static player
	new players[32], iPnum
	
	get_players(players, iPnum, "a")
	if(!iPnum)	return 0
	
	player = players[random(iPnum)]
	
	if(!player)	GetRandomPlayer()
	else		return player
	
	return 0
	
}

stock fm_find_ent_by_owner(entity, const classname[], owner)
{
	while ((entity = engfunc(EngFunc_FindEntityByString, entity, "classname", classname)) && pev(entity, pev_owner) != owner) { /* keep looping */ }
	return entity;
}

stock give_user_weapon( index , iWeaponTypeID , iClip=0 , iBPAmmo=0 , szWeapon[]="" , maxchars=0 )
{
	if ( !( CSW_P228 <= iWeaponTypeID <= CSW_P90 ) || ( iClip < 0 ) || ( iBPAmmo < 0 ) || !is_user_alive( index ) )
		return -1;
	
	new szWeaponName[ 20 ] , iWeaponEntity , bool:bIsGrenade;
	
	const GrenadeBits = ( ( 1 << CSW_HEGRENADE ) | ( 1 << CSW_FLASHBANG ) | ( 1 << CSW_SMOKEGRENADE ) | ( 1 << CSW_C4 ) );
	
	if ( ( bIsGrenade = bool:!!( GrenadeBits & ( 1 << iWeaponTypeID ) ) ) )
		iClip = clamp( iClip ? iClip : iBPAmmo , 1 );
	
	get_weaponname( iWeaponTypeID , szWeaponName , charsmax( szWeaponName ) );
	
	if ( ( iWeaponEntity = user_has_weapon( index , iWeaponTypeID ) ? find_ent_by_owner( -1 , szWeaponName , index ) : give_item( index , szWeaponName ) ) > 0 )
	{
		if ( iWeaponTypeID != CSW_KNIFE )
		{
			if ( iClip && !bIsGrenade )
				cs_set_weapon_ammo( iWeaponEntity , iClip );
			
			if ( iWeaponTypeID == CSW_C4 ) 
				cs_set_user_plant( index , 1 , 1 );
			else
				cs_set_user_bpammo( index , iWeaponTypeID , bIsGrenade ? iClip : iBPAmmo ); 
		}
		
		if ( maxchars )
			copy( szWeapon , maxchars , szWeaponName[7] );
	}
	
	return iWeaponEntity;
}

stock UTIL_GiveWeaponAmmo( index )
{
	new szCopyAmmoData[ 40 ];
	
	switch( get_user_weapon( index ) )
	{
		case CSW_P228: copy( szCopyAmmoData, charsmax( szCopyAmmoData ), "ammo_357sig" )
		case CSW_SCOUT, CSW_G3SG1, CSW_AK47: copy( szCopyAmmoData, charsmax( szCopyAmmoData ), "ammo_762nato" )
		case CSW_XM1014, CSW_M3: copy( szCopyAmmoData, charsmax( szCopyAmmoData ), "ammo_buckshot" )
		case CSW_MAC10, CSW_UMP45, CSW_USP: copy( szCopyAmmoData, charsmax( szCopyAmmoData ), "ammo_45acp" )
		case CSW_SG550, CSW_GALIL, CSW_FAMAS, CSW_M4A1, CSW_SG552, CSW_AUG: copy( szCopyAmmoData, charsmax( szCopyAmmoData ), "ammo_556nato" )
		case CSW_ELITE, CSW_GLOCK18, CSW_MP5NAVY, CSW_TMP: copy( szCopyAmmoData, charsmax( szCopyAmmoData ), "ammo_9mm" )
		case CSW_AWP: copy( szCopyAmmoData, charsmax( szCopyAmmoData ), "ammo_338magnum" )
		case CSW_M249: copy( szCopyAmmoData, charsmax( szCopyAmmoData ), "ammo_556natobox" )
		case CSW_FIVESEVEN, CSW_P90: copy( szCopyAmmoData, charsmax( szCopyAmmoData ), "ammo_57mm" )
		case CSW_DEAGLE: copy( szCopyAmmoData, charsmax( szCopyAmmoData ), "ammo_50ae" )
	}
	
	give_item( index, szCopyAmmoData )
}

stock ham_strip_weapon(id,weapon[])
{
	if(!equal(weapon,"weapon_",7)) return 0;

	new wId = get_weaponid(weapon);
	if(!wId) return 0;

	new wEnt;
	while((wEnt = engfunc(EngFunc_FindEntityByString,wEnt,"classname",weapon)) && pev(wEnt,pev_owner) != id) {}
	if(!wEnt) return 0;

	if(get_user_weapon(id) == wId) ExecuteHamB(Ham_Weapon_RetireWeapon,wEnt);

	if(!ExecuteHamB(Ham_RemovePlayerItem,id,wEnt)) return 0;
	ExecuteHamB(Ham_Item_Kill,wEnt);

	set_pev(id,pev_weapons,pev(id,pev_weapons) & ~(1<<wId));
    
	return 1;
}

set_user_gnvision(id, toggle)
{
	message_begin(MSG_ONE, get_user_msgid("NVGToggle"), _, id)
	write_byte(toggle) // 1 On - 0 Off
	message_end()
}


lights()
{
	new txt[3]
	get_pcvar_string(g_light, txt, charsmax(txt))
	set_lights(txt)
}
