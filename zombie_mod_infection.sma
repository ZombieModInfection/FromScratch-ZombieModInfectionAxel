#include <amxmodx>
#include <amxmisc>
#include <cstrike>
#include <engine>
#include <fakemeta>
#include <fun>
#include <hamsandwich>

enum (+= 1000) { TASK_HUD = 9999, TASK_PRE_INFECTION, TASK_THUNDER }

enum _:StateRound
{
	NEW,
	END,
	INFECTION
}

enum _:RepickWPN
{
	SMG,
	SHOTGUN,
	PISTOL,
	GRENADE
}

enum _:COORDS
{
	X,
	Y,
	Z
}

new lights_thunder1[][] = { "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "l", "k", "j", "i", "h", "g", "f", "e", "d", "c", "b", "a" }

new g_iRound[StateRound]

new Array:g_aOriginSpawn
new g_iSpawns
new g_fwSpawn

new g_iHud, g_iThunder

new g_iDeadZombies, g_iDeadHumans

new g_zombie_hp, g_first_zombie_hp, g_super_zombie_hp, g_zombie_speed, g_zombie_brain, g_light, g_human_ammo, g_super_round

new g_Alive[MAX_PLAYERS + 1], g_Connected[MAX_PLAYERS + 1], g_Zombie[MAX_PLAYERS + 1], g_Player_Weapon[MAX_PLAYERS + 1], g_Remember_Wpn[MAX_PLAYERS + 1], g_Menu_Remember[MAX_PLAYERS + 1][RepickWPN]//, g_PlayerName[MAX_PLAYERS + 1][MAX_NAME_LENGTH]

new const g_szObjectives[ ][ ] = 
{
	"func_hostage_rescue", "info_hostage_rescue", "game_player_equip",
	"func_bomb_target", "info_bomb_target", "hostage_entity",
	"info_vip_start", "func_vip_safetyzone", "func_escapezone",
	"info_map_parameters", "player_weaponstrip", "func_buyzone", "armoury_entity"
}


new const g_szBlock_Commands[][] =
{       
	"buy", "buyequip", "usp", "glock", "deagle", "p228", "elites", "fn57", "m3", 
	"xm1014", "mp5", "tmp", "p90", "mac10", "ump45", "ak47", "galil", "famas", "sg552", "m4a1", 
	"aug", "scout", "awp", "g3sg1", "sg550", "m249", "vest", "vesthelm", "flash", "hegren", 
	"sgren", "defuser", "nvgs", "shield", "primammo", "secammo", "km45", "9x19mm", "nighthawk", "228compact", "12gauge", 
	"autoshotgun", "smg", "mp", "c90", "cv47", "defender", "clarion", "krieg552", "bullpup", "magnum", "d3au1", "krieg550", 
	"buyammo1", "buyammo2", "cl_autobuy", "cl_rebuy", "cl_setautobuy", "cl_setrebuy" 
}
	
new const g_szWeaponsEnts[][] =
{
	"", "weapon_p228", "", "weapon_scout", "weapon_hegrenade", "weapon_xm1014", "weapon_c4", "weapon_mac10",
	"weapon_aug", "weapon_smokegrenade", "weapon_elite", "weapon_fiveseven", "weapon_ump45", "weapon_sg550",
	"weapon_galil", "weapon_famas", "weapon_usp", "weapon_glock18", "weapon_awp", "weapon_mp5navy", "weapon_m249",
	"weapon_m3", "weapon_m4a1", "weapon_tmp", "weapon_g3sg1", "weapon_flashbang", "weapon_deagle", "weapon_sg552",
	"weapon_ak47", "weapon_knife", "weapon_p90" 
}

new const g_szClaw_Zombie[] = "models/MD-Infection/v_knife_zombie.mdl"
new const g_szModel_Zombie[] = "models/player/zombie_burned/zombie_burned.mdl"
new const g_szSound_DieZombie[][]  = { "MD-Infection/zombie_die1.wav", "MD-Infection/zombie_die2.wav", "MD-Infection/zombie_die3.wav", "MD-Infection/zombie_die4.wav", "MD-Infection/zombie_die5.wav" }
new const g_szSound_Infect[][] = { "MD-Infection/zombie_infec1.wav", "MD-Infection/zombie_infec2.wav", "MD-Infection/zombie_infec3.wav" }
new const g_szSound_ChantZombie[][] = { "nihilanth/nil_alone.wav", "nihilanth/nil_comes.wav", "nihilanth/nil_slaves.wav", "nihilanth/nil_die.wav", "nihilanth/nil_now_die.wav" }
new const g_szSound_ChantLastZombie[][] = { "nihilanth/nil_thelast.wav", "nihilanth/nil_last.wav" }
new const g_szSound_First[][] = { "MD-Infection/zombie_first1.wav", "MD-Infection/zombie_first2.wav", "MD-Infection/zombie_first3.wav", "MD-Infection/zombie_first4.wav"}

public plugin_precache() 
{
	precache_model(g_szClaw_Zombie)
	precache_model(g_szModel_Zombie)
	
	new i

	for (  i = 0 ; i < sizeof g_szSound_DieZombie; i++)
		precache_sound(g_szSound_DieZombie[i])
	
	for (  i = 0 ; i < sizeof g_szSound_Infect; i++)
		precache_sound(g_szSound_Infect[i])
	
	for (  i = 0 ; i < sizeof g_szSound_First; i++)
		precache_sound(g_szSound_First[i])
		
	for (  i = 0 ; i < sizeof g_szSound_ChantZombie; i++)
		precache_sound(g_szSound_ChantZombie[i])
		
	for (  i = 0 ; i < sizeof g_szSound_ChantLastZombie; i++)
		precache_sound(g_szSound_ChantLastZombie[i])
    
	g_fwSpawn = register_forward(FM_Spawn, "fw_Spawn")
    
	new iHostage = cs_create_entity( "hostage_entity" )
	entity_set_vector(iHostage, EV_VEC_origin, Float:{ 0.0, 0.0, -55000.0 } )
	entity_set_size( iHostage, Float:{ -1.0, -1.0, -1.0 }, Float:{ 1.0, 1.0, 1.0 } )
	DispatchSpawn(iHostage)
}

public plugin_init() 
{
	register_plugin
	(
	.plugin_name = "Zombie Mod Infection",
	.version = "1.4",
	.author = "Axel"
	)
	
	// Client Commands
	
	register_clcmd("buyammo1", "buyammo")
	
	register_clcmd("buyammo2", "buyammo")
	
	register_clcmd("say /repick", "remember")
	
	register_impulse(100, "flashlight")
	
	for ( new id = 0 ; id < sizeof g_szBlock_Commands ; id++)
		register_clcmd(g_szBlock_Commands[id], "block_buyzone")
		
	// Events
	
	register_event_ex("HLTV", "round_start", RegisterEvent_Global, "1=0", "2=0")
	
	register_event_ex("DeathMsg", "event_death", RegisterEvent_Global)
	
	register_logevent("round_ended", 2, "1=Round_End")
	
	// Cvars
	
	g_zombie_hp = register_cvar("amx_zombie_health", "1700")
	g_first_zombie_hp = register_cvar("amx_zombie_first_health", "3400")
	g_super_zombie_hp = register_cvar("amx_super_zombie_health", "60000")
	g_zombie_speed = register_cvar("amx_zombie_speed", "210")
	g_zombie_brain = register_cvar("amx_zombie_brain_health", "300")
	g_human_ammo = register_cvar("amx_human_clip_cost", "1500")
	g_light = register_cvar("amx_zmod_light", "n")
	g_super_round = register_cvar("amx_super_round", "0")
	
	// Forward
	
	RegisterHam(Ham_Spawn, "player", "ham_spawn_post", true)
	
	RegisterHam(Ham_TakeDamage, "player", "ham_takedamage", false)
	
	//RegisterHam(Ham_Killed, "player", "ham_killed", false)
	
	RegisterHam(Ham_Touch, "weaponbox", "ham_touch", false)
	
	RegisterHam(Ham_Touch, "weapon_shield", "ham_touch", false)
	
	for (new i = 1; i < sizeof(g_szWeaponsEnts); i++)
	{
		if (g_szWeaponsEnts[i][0])
		{
			RegisterHam(Ham_Item_Deploy, g_szWeaponsEnts[i], "ham_itemdeploy_post", true)
		}
	}	
	
	unregister_forward(FM_Spawn, g_fwSpawn)
	
	// Message Hook
	
	register_message(get_user_msgid("TextMsg"), "message_textmsg")
	
	// Array

	g_aOriginSpawn = ArrayCreate(COORDS, 1)
	
	// CSDM Spawns
	
	CheckRandomSpawns()	
	
	// Hud
	
	g_iHud = CreateHudSyncObj()
	
	// Tasks
	
	set_task_ex(50.0, "PlayersCount", .flags = SetTask_Repeat)
	set_task_ex(2.0, "round_start", .flags = SetTask_Once)
}

public plugin_cfg()
{
	new cfgdir[32]
	get_configsdir(cfgdir, sizeof cfgdir - 1)
	
	server_cmd("exec %s/zmod_exec_cfg", cfgdir)
}

/*================================================================================
 [Client Command]
=================================================================================*/

public buyammo(id)
{
	if(g_Alive[id] && !g_Zombie[id])
	{
	
		if(cs_get_user_money(id) < get_pcvar_num(g_human_ammo) )
		{
			client_print(id, print_chat, "[ZM] You don't have enough money to purchase extra ammo! You require at least $%d.", g_human_ammo)
		}
		else
		{
			cs_set_user_money(id, cs_get_user_money(id) - get_pcvar_num(g_human_ammo) )
			client_print(id, print_chat, "[ZM] Extra ammo bought!")
			give_item(id, "ammo_45acp")
			give_item(id, "ammo_357sig")
			give_item(id, "ammo_9mm")
			give_item(id, "ammo_50ae")
			give_item(id, "ammo_57mm")
			give_item(id, "ammo_buckshot")
			give_item(id, "ammo_556nato")
			give_item(id, "ammo_338magnum")
			give_item(id, "ammo_556natobox")
			give_item(id, "ammo_762nato")
		}
	}
}

public flashlight(id)
{
	if(g_Zombie[id])
		return PLUGIN_HANDLED
		
	return PLUGIN_CONTINUE	
}



public remember(id)
{
	g_Remember_Wpn[id] = !g_Remember_Wpn[id]
	client_print(id, print_chat, "Automatic Repick: %s", g_Remember_Wpn[id] ? "Enabled" : "Disabled")
}

public block_buyzone(id)
	return PLUGIN_HANDLED_MAIN

/*================================================================================
 [Main Events]
=================================================================================*/
/*
public client_authorized(id)
{
	get_user_name(id, g_PlayerName[id], charsmax(g_PlayerName[]))
}
*/
public client_disconnected(id)
{
	g_Connected[id] = 0
	g_Alive[id] = 0
	g_Zombie[id] = 0
	g_Player_Weapon[id] = 0
	
	remove_task(id+TASK_HUD)
	
}
public client_putinserver(id)
{	
//	get_user_name(id, g_PlayerName[id], charsmax(g_PlayerName[]))
	
	g_Connected[id] = true
	g_Alive[id] = false
}

public round_start()
{
	g_iRound[END] = false
	
	g_iRound[NEW] = true
	
	lights()
	
	if(get_pcvar_num(g_super_round))
	{
		set_dhudmessage(255, 255, 255, 0.03, 0.0, 0, 6.0, 10.0)
		show_dhudmessage(0, "SUPER ZOMBIE ROUND^n^n SUPER ZOMBIE HP = %d", get_pcvar_num(g_super_zombie_hp))
	}
	
	set_task_ex(10.0, "start_infection", TASK_PRE_INFECTION, .flags = SetTask_Once)
}

public round_ended()
{
	g_iRound[INFECTION] = false
	
	g_iRound[END] = true
	
	remove_task(TASK_PRE_INFECTION)
	
	g_iDeadHumans = 0
	g_iDeadZombies = 0
	
	static id
	for (id = 1; id <= MaxClients; id++)
	{
		if(get_pcvar_num(g_super_round) )
		{
			if(g_Alive[id] )
			{
				strip_user_weapons(id)
				give_item(id, "weapon_knife")
			}
		}
		
		remove_task(id+TASK_HUD)
		
		g_Zombie[id] = false
	}
	
	balance_teams()
}	

public event_death()
{
	new victim = read_data(2)
	
	if(g_Zombie[victim] )
		g_iDeadZombies++
	else
		g_iDeadHumans++
		
	g_Alive[victim] = false	
	set_task_ex(1.0, "hud", victim+TASK_HUD, .flags = SetTask_Repeat)
}

/*================================================================================
 [Main Forwards]
=================================================================================*/

public ham_spawn_post(id)	
{
	if(!is_user_alive(id) || !(cs_get_user_team(id)))
		return;
	
	if(g_iRound[INFECTION])
	{
		g_Zombie[id] = false
		cs_set_user_team(id, CS_TEAM_CT)
	}
	
	g_Alive[id] = true
	
	RandomSpawn(id)
	
	if(is_user_bot(id))
	{
		give_user_weapon(id, CSW_USP, 12, 100)
		give_user_weapon(id, CSW_P90, 50, 100)
		return
	}
		
	if(get_pcvar_num(g_super_round))
	{
		give_user_weapon(id, CSW_M249, 100, 200)
		give_user_weapon(id, CSW_G3SG1, 20, 90)
		give_user_weapon(id, CSW_SG550, 30, 90)
		give_user_weapon(id, CSW_AK47, 30, 90)
		give_user_weapon(id, CSW_M4A1, 30, 90)
		return
	}
	
	if(g_Remember_Wpn[id] )
	{
		if(g_Menu_Remember[id][SMG] )
		{
			handlerweaponsmg(id, 0, g_Menu_Remember[id][SMG] )
			handlerweaponpistol(id, 0, g_Menu_Remember[id][PISTOL] )
			handlerweaponnade(id, 0, g_Menu_Remember[id][GRENADE] )		
			client_print(id, print_chat, "[ZM] To disable automatic repick type /repick.")
			return
		}
		else if (g_Menu_Remember[id][SHOTGUN] )
		{
			handlerweaponsmg(id, 0, g_Menu_Remember[id][SHOTGUN]  )
			handlerweaponpistol(id, 0, g_Menu_Remember[id][PISTOL]  )
			handlerweaponnade(id, 0, g_Menu_Remember[id][GRENADE]  )
			client_print(id, print_chat, "[ZM] To disable automatic repick type /repick.")
			return
		}
		
		client_print(id, print_chat, "[ZM] You don't selected none weapon. (Repick disabled)")
		g_Remember_Wpn[id] = 0
		g_Menu_Remember[id][PISTOL] = 0
		g_Menu_Remember[id][GRENADE] = 0
		menu_weapon(id)
	}
	else
	{
		menu_weapon(id)
	}
}


public ham_takedamage(victim, inflictor, attacker, Float:damage, iDamageBits)
{
	if (victim == attacker || !g_Connected[attacker])
		return HAM_IGNORED;
	
	if (g_iRound[NEW] || g_iRound[END])
		return HAM_SUPERCEDE;
		
	if(!g_Zombie[attacker])
		return HAM_IGNORED;
		
	if(!g_Zombie[victim])
	{
		new count_ct
		count_ct = 0
		
		static id
		for (id = 1; id <= MaxClients; id++)
		{
			if(!g_Connected[id] )
				continue
		
			if(g_Alive[id] && !g_Zombie[id])
				count_ct++
		}
	
		if(count_ct != 1)
		{
			set_dhudmessage(200, 0, 0, 0.0, 0.5, 0, 1.0, 1.0)
			show_dhudmessage(0, "%n brains was eaten by %n!", victim, attacker)
			emit_sound(victim, CHAN_VOICE,  g_szSound_Infect[random(sizeof g_szSound_Infect)], 1.0, ATTN_NORM, 0, PITCH_NORM)
			make_deathmsg(attacker, victim, 1, "Infection")
			FixDeadAttrib(victim)
			set_user_health(attacker, get_user_health(attacker) + get_pcvar_num(g_zombie_brain) )
			set_user_frags(attacker, get_user_frags(attacker) + 1)
			cs_set_user_deaths(victim, cs_get_user_deaths(victim) + 1)
			MakeZombie(victim)
		}
	}
	
	return HAM_IGNORED;
}

public ham_itemdeploy_post(weapon_ent)
{
	static owner
	owner = fm_cs_get_weapon_ent_owner(weapon_ent)
	
	if (!is_valid_ent(owner))
		return
		
	static weaponid
	weaponid = cs_get_weapon_id(weapon_ent)
	
	replace_models(owner)
	
	g_Player_Weapon[owner] = weaponid
		
	if(g_Zombie[owner] && g_Player_Weapon[owner] != CSW_KNIFE)
	{
		g_Player_Weapon[owner] = CSW_KNIFE
		engclient_cmd(owner, "weapon_knife")
	}
	
}

public ham_touch(weapon, id)
{
	if (!is_user_alive(id))
		return HAM_IGNORED
	
	if (g_Zombie[id])
		return HAM_SUPERCEDE
	
	return HAM_IGNORED
}

public fw_Spawn(ent)
{
	if( !pev_valid( ent ) )
		return FMRES_IGNORED
    
	static sClass[ 32 ]
	pev( ent, pev_classname, sClass, 31 )
    
	for( new i = 0; i < sizeof(g_szObjectives); i++ )
	{
		if( equal( sClass, g_szObjectives[ i ] ) )
		{
			engfunc( EngFunc_RemoveEntity, ent )
			return FMRES_SUPERCEDE
		}
	}
	return FMRES_IGNORED
}

/*================================================================================
 [Message Hook]
=================================================================================*/

public message_textmsg()
{
	static message[38]
	get_msg_arg_string(2, message, charsmax(message))

	if(equal(message, "#Terrorists_Win"))
	{
		set_dhudmessage(255, 0, 0, -1.0, 0.2, 0, 6.0, 5.0)
		show_dhudmessage(0, "[ZM] Zombies have taken over the world!")
		client_print(0, print_chat, "[ZM] Zombies have taken over the world!")
	}
	else if(equal(message, "#CTs_Win"))
	{
		set_dhudmessage(0, 0, 255, -1.0, 0.3, 0, 6.0, 5.0)
		show_dhudmessage(0, "[ZM] All of the zombies have been killed!")
		client_print(0, print_chat, "[ZM] All of the zombies have been killed!")
	}
	else if(equal(message, "#Round_Draw") || equal(message, "#Game_Commencing") || equal(message, "#Target_Saved") || equal(message, "#Game_will_restart_in") )
	{
		set_dhudmessage(255, 255, 255, -1.0, 0.3, 0, 6.0, 5.0)
		show_dhudmessage(0, "[ZM] No one won...")
		client_print(0, print_chat, "[ZM] No one won...")
		round_ended( )
	}
}


/*================================================================================
 [Menus]
=================================================================================*/

public menu_weapon(id)
{
	new szText[MAX_MENU_LENGTH]
	
	formatex(szText, charsmax(szText), "\yAuto repick currently \r%s", g_Remember_Wpn[id] ? "ON" : "OFF")
	
	new gMenu = menu_create("\yZombie Mod Infection Weapon Menu:", "handlerweapon")
	    
	menu_additem(gMenu, "Shotguns", "1") 
	menu_additem(gMenu, "SMG", "2")
	menu_additem(gMenu, szText, "3")
	menu_display(id, gMenu, 0)
}

public menu_weapon_shotgun(id)
{
	new gMenu = menu_create("\yZombie Mod Infection Weapon Menu \r[Shotguns]", "handlerweaponshotgun")
	    
	menu_additem(gMenu, "Leone 12 Gauge Super", "1") 
	menu_additem(gMenu, "Leone YG1265 Auto Shotgun", "2")
	menu_display(id, gMenu, 0)
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

public menu_grenade(id)
{
	new gMenu = menu_create("\yZombie Mod Infection Weapon Menu \r[Grenades]", "handlerweaponnade")
	    
	menu_additem(gMenu, "He Grenade", "1") 
	menu_additem(gMenu, "Smoke Grenade", "2")
	menu_additem(gMenu, "Both Grenades", "3") 
	menu_display(id, gMenu, 0)
}

/*================================================================================
 [Menu Handler]
=================================================================================*/

public handlerweapon(id, menu, item)       
{
	
	if ( item == MENU_EXIT || !is_user_alive(id ) || g_Zombie[id]) 
	{
		menu_destroy(menu)        
		return PLUGIN_HANDLED
	}
    
	switch(item) 
	{
		case 0:  
		{
			menu_weapon_shotgun(id)
		}
	      
		case 1:  
		{
			menu_weapon_smg(id)
		}
		case 2:
		{
			g_Remember_Wpn[id] = !g_Remember_Wpn[id]
			menu_weapon(id)
		}
	}
	
	return PLUGIN_HANDLED
} 

public handlerweaponshotgun(id, menu, item)       
{	
	if ( item == MENU_EXIT || !is_user_alive(id ) || g_Zombie[id]) 
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
	
	g_Menu_Remember[id][SHOTGUN] = item
	g_Menu_Remember[id][SMG] = 0
	
	return PLUGIN_HANDLED
} 

public handlerweaponsmg(id, menu, item)
{
	if ( item == MENU_EXIT || !is_user_alive(id ) || g_Zombie[id]) 
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
	
		
	g_Menu_Remember[id][SHOTGUN] = 0
	g_Menu_Remember[id][SMG] = item
	
	return PLUGIN_HANDLED  
} 

public handlerweaponpistol(id, menu, item)       
{
	if ( item == MENU_EXIT || !is_user_alive(id ) || g_Zombie[id]) 
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
	
	g_Menu_Remember[id][PISTOL] = item
	
	menu_grenade(id)
	
	return PLUGIN_HANDLED
} 

public handlerweaponnade(id, menu, item)
{
	if ( item == MENU_EXIT || !is_user_alive(id ) || g_Zombie[id]) 
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
	
	g_Menu_Remember[id][GRENADE] = item
	
	return PLUGIN_HANDLED
} 

/*================================================================================
 [Functions]
=================================================================================*/

public hud(taskid)
{
	static id
	
	new ID_HUD = taskid - TASK_HUD
	
	id = ID_HUD
    
	if (!is_user_alive(id))
	{
		id = entity_get_int(id, EV_INT_iuser2)
		
		if (!is_user_alive(id)) return
	}
	
	if(id != ID_HUD)
	{
		new clip, ammo
		cs_get_user_weapon(id, clip, ammo)
		
		new g_szWpn_Name[32][32] = {"", "P228", "", "Scout", "He-Nade",
		"XM1014", "C4", "Mac10", "Aug", "Smoke-Nade", "Elite",
		"Fiveseven", "Ump45", "Sg550", "Galil", "Famas", "Usp", "Glock",
		"Awp", "Mp5", "M249", "M3", "M4a1", "Tmp",
		"G3sg1", "FB", "Deagle", "Sg552", "Ak47",
		"Knife", "P90", ""}
		
		
		if(g_Player_Weapon[id] == CSW_KNIFE) 
		{
			set_hudmessage(255, 255, 255, 0.01, 0.22, 0, 6.0, 0.9)
			ShowSyncHudMsg(ID_HUD, g_iHud, "Spectating: %n^n    Health: %d    Armor: %d^n    Weapon: %s", id, get_user_health(id), get_user_armor(id), g_szWpn_Name[g_Player_Weapon[id]])
		}
		else
		{
			set_hudmessage(255, 255, 255, 0.01, 0.22, 0, 6.0, 0.9)
			ShowSyncHudMsg(ID_HUD, g_iHud, "Spectating: %n^n    Health: %d    Armor: %d^n    Weapon: %s    Ammo: %d/%d", id, get_user_health(id), get_user_armor(id),  g_szWpn_Name[g_Player_Weapon[id]], clip, ammo)
		
		}
	}
	else
	{
		set_hudmessage(255, 255, 255, 0.01, 0.22, 0, 6.0, 0.9)
		ShowSyncHudMsg(ID_HUD, g_iHud, "    Health: %d^n^n^n^n^n^n    Armor: %d", get_user_health(ID_HUD), get_user_armor(ID_HUD))
		
		if(g_Zombie[ID_HUD] )
		{
			if(random_num(1, 200) <= 10)
			{
				new g_iZombies = get_playersnum_ex(GetPlayers_ExcludeDead|GetPlayers_MatchTeam, "TERRORIST")
				
				if(g_iZombies == 1)
					emit_sound(ID_HUD, CHAN_VOICE,  g_szSound_ChantLastZombie[random(sizeof g_szSound_ChantLastZombie)], 1.0, ATTN_NORM, 0, PITCH_NORM)
				else
					emit_sound(ID_HUD, CHAN_VOICE,  g_szSound_ChantZombie[random(sizeof g_szSound_ChantZombie)], 1.0, ATTN_NORM, 0, PITCH_NORM)
			}
		}
	}
} 

public start_infection()
{
	if(get_playersnum_ex(GetPlayers_ExcludeDead) < 1)
	{
		set_task_ex(10.0, "start_infection", TASK_PRE_INFECTION, .flags = SetTask_Once)
		return
	}
	
	g_iRound[NEW] = false
	g_iRound[INFECTION] = true
	
	static id
	for (id = 1; id <= MaxClients; id++)
	{
		if(!g_Alive[id] || !g_Connected[id] )
			continue
		
		cs_set_user_team(id, CS_TEAM_CT)
	}
	
	new rdm_ply = GetRandomPlayer()
	MakeZombie(rdm_ply)
	
	if(get_pcvar_num(g_super_round))
	{
		set_user_health(rdm_ply, get_pcvar_num (g_super_zombie_hp) )
		set_user_rendering(rdm_ply, kRenderFxGlowShell, 0, 255, 0, kRenderTransAlpha, 16)
		set_dhudmessage(200, 0, 0, 0.0, 0.5, 0, 1.0, 2.0)
		show_dhudmessage(0, "BEWARE! %n IS THE SUPER ZOMBIE!!", rdm_ply )
	}
	else
	{
		set_user_health(rdm_ply, get_pcvar_num(g_first_zombie_hp) )
		set_dhudmessage(200, 0, 0, 0.0, 0.5, 0, 1.0, 2.0)
		show_dhudmessage(0, "BEWARE! %n IS THE FIRST ZOMBIE!!", rdm_ply )
	}
	
	emit_sound(rdm_ply, CHAN_VOICE,  g_szSound_First[random(sizeof g_szSound_First)], 1.0, ATTN_NORM, 0, PITCH_NORM)
}

public PlayersCount()
{
	new count_t, count_ct, count_spec, count_dead
		
	count_ct = 0
	count_t = 0
	count_spec = 0
	count_dead = 0
		
	static id
	
	for (id = 1; id <= MaxClients; id++)
	{
		if(!g_Connected[id] )
			continue
				
		if(is_user_alive(id))
		{
			if(!g_Zombie[id]) count_ct++
			if(g_Zombie[id]) count_t++
		}
		else if(!is_user_alive(id))
			count_dead++
		
		if(cs_get_user_team(id) == CS_TEAM_SPECTATOR) 
			count_spec++
	}
	
	set_hudmessage(255, 255, 255, 0.6, -1.0, 0, 7.0, 5.0)
	show_hudmessage(0, "Players Count:^nAlive Humans: %d^nAlive Zombies: %d^nHumans Killed: %d^nZombies Killed: %d^nDead Players: %d^nSpectators: %d^nTotal Players: %d", count_ct, count_t, g_iDeadHumans, g_iDeadZombies, count_dead, get_playersnum_ex(GetPlayers_MatchTeam, "SPECTATOR"), get_playersnum_ex(GetPlayers_IncludeConnecting) ) 

	g_iThunder = 0
	
	remove_task(TASK_THUNDER)
	set_task_ex(0.1, "thunderclap", TASK_THUNDER, .flags = SetTask_Repeat)
}

public thunderclap()
{
	if (!g_iThunder) client_cmd(0, "speak ambience/thunder_clap.wav")
	
	g_iThunder++
	
	if (g_iThunder < 16)
	{
		set_lights(lights_thunder1[random(sizeof lights_thunder1)] )
	}
	else
	{
		remove_task(TASK_THUNDER)
		lights()
	}
}

replace_models(id)
{
	if(g_Zombie[id])
		entity_set_string(id, EV_SZ_viewmodel, g_szClaw_Zombie)
	
}

MakeZombie(id)
{
	if(g_Alive[id])
	{
		cs_set_user_team(id, CS_TEAM_T)
		set_user_health(id, get_pcvar_num( g_zombie_hp) )
		drop_weapons(id, 1)
		drop_weapons(id, 2)
		strip_user_weapons(id)
		give_item(id, "weapon_knife")
		set_user_maxspeed(id, get_pcvar_float(g_zombie_speed) )
		cs_set_user_model(id, "zombie_burned")
		set_task_ex(1.0, "hud", id+TASK_HUD, .flags = SetTask_Repeat)
		entity_set_string(id, EV_SZ_viewmodel, g_szClaw_Zombie)
		cs_set_user_nvg(id, 1)
		g_Zombie[id] = true
	}
}

lights()
{
	new string[3]
	get_pcvar_string(g_light, string, 2)
	set_lights(string)
}

FixDeadAttrib(id)
{
	message_begin(MSG_BROADCAST, get_user_msgid("ScoreAttrib"))
	write_byte(id)
	write_byte(0)
	message_end()
}

CheckRandomSpawns()
{
	new szFile[128], szMap[32]
	get_configsdir(szFile, charsmax(szFile))
	get_mapname(szMap, charsmax(szMap))
	
	format(szFile, charsmax(szFile), "%s/csdm/%s.spawns.cfg", szFile, szMap)
	
	if(file_exists(szFile))
	{
		new iFile = fopen(szFile, "rt")
		
		if(iFile)
		{
			new szData[32], vOrigin[COORDS][10], Float:fOrigin[3]
			
			while(!feof(iFile))
			{
				fgets(iFile, szData, charsmax(szData))
				trim(szData)
				
				if(!szData[0] || szData[0] == ';')
					continue
					
				parse(szData, vOrigin[X], charsmax(vOrigin[]), vOrigin[Y], charsmax(vOrigin[]), vOrigin[Z], charsmax(vOrigin[]))
				
				fOrigin[0] = str_to_float(vOrigin[X])
				fOrigin[1] = str_to_float(vOrigin[Y])
				fOrigin[2] = str_to_float(vOrigin[Z])
				
				ArrayPushArray(g_aOriginSpawn, fOrigin)
				
				g_iSpawns++
			}
			
			fclose(iFile)
			
		}
		else
			log_amx("Error File Spawns ^"%s^"", szFile)
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
	
	for (id = 1; id <= MaxClients; id++)
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
		if (++id > MaxClients) id = 1
		
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


RandomSpawn(id)
{
	new Float:fOrigin[3], iHull, i, iRandom
	iHull = (pev(id, pev_flags) & FL_DUCKING) ? HULL_HEAD : HULL_HUMAN
	
	iRandom = random(g_iSpawns)
	
	for(i = iRandom + 1;i != iRandom; i++)
	{
		if(i >= g_iSpawns)
			i = 0
		
		ArrayGetArray(g_aOriginSpawn, i, fOrigin)
		
		if(is_hull_vacant(fOrigin, iHull))
		{
			engfunc(EngFunc_SetOrigin, id, fOrigin)
			break
		}
	}
}

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

stock is_hull_vacant(Float:origin[3], hull)
{
	engfunc(EngFunc_TraceHull, origin, origin, 0, hull, 0, 0)
	
	if(!get_tr2(0, TR_StartSolid) && !get_tr2(0, TR_AllSolid) && get_tr2(0, TR_InOpen))
		return true
	
	return false
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

stock drop_weapons(id, dropwhat)
{
	static weapons[32], num, i, weaponid
	num = 0
	get_user_weapons(id, weapons, num)
    
    
    
	const PRIMARY_WEAPONS_BIT_SUM = (1<<CSW_SCOUT)|(1<<CSW_XM1014)|(1<<CSW_MAC10)|(1<<CSW_MAC10)|(1<<CSW_UMP45)|(1<<CSW_SG550)|(1<<CSW_MAC10)|(1<<CSW_FAMAS)|(1<<CSW_AWP)|(1<<CSW_MP5NAVY)|(1<<CSW_M249)|
	(1<<CSW_M3)|(1<<CSW_M4A1)|(1<<CSW_TMP)|(1<<CSW_G3SG1)|(1<<CSW_SG552)|(1<<CSW_AK47)|(1<<CSW_P90)
	
	const SECONDARY_WEAPONS_BIT_SUM = ((1<<CSW_P228)|(1<<CSW_ELITE)|(1<<CSW_FIVESEVEN)|(1<<CSW_USP)|(1<<CSW_GLOCK18)|(1<<CSW_DEAGLE))
    
	for (i = 0; i < num; i++)
	{
		weaponid = weapons[i]
        
		if (dropwhat == 1 && ((1<<weaponid) & PRIMARY_WEAPONS_BIT_SUM) || (dropwhat == 2 && ((1<<weaponid) & SECONDARY_WEAPONS_BIT_SUM)))
		{
			static wname[32]
			get_weaponname(weaponid, wname, sizeof wname - 1)
			engclient_cmd(id, "drop", wname)
		}
	}
} 

stock fm_cs_get_weapon_ent_owner(ent)
{
	if (pev_valid(ent) != 2)
		return -1
	
	return get_pdata_cbase(ent, 41, 4)
}