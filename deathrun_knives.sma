#include <amxmodx>
#include <cstrike>
#include <fakemeta>
#include <hamsandwich>

#define PLUGIN "Deathrun: Knives"
#define VERSION "0.2"
#define AUTHOR "Mistrick"

#pragma semicolon 1

const XO_CBASEPLAYERWEAPON = 4;
const XO_CBASEPLAYER = 5;
const m_pPlayer = 41;
const m_flNextPrimaryAttack = 46;
const m_flNextSecondaryAttack= 47;
const m_flTimeWeaponIdle = 48;
const m_pActiveItem = 373;
const PDATA_SAFE = 2;

enum _:KNIFE_INFO
{
	NAME[32],
	DESCRIPTION[32],
	ACCESS,
	Float:ATTACK_SPEED_RATE_1,
	Float:ATTACK_SPEED_RATE_2,
	Float:GRAVITY,
	Float:MAXSPEED,
	Float:DAMAGE,
	MODEL_V[64],
	MODEL_P[64],
	SOUND_HIT[64],
	SOUND_STAB[64],
	SOUND_HITWALL[64],
	SOUND_SLASH[64]
}

new g_eKnives[][KNIFE_INFO] = 
{
	{
		"Default",//Name
		"\y[HP Regeneration]",//Description
		0,//Admin Access
		1.0,//Attack1 Speed
		1.0,//Attack2 Speed
		1.0,//Gravity
		250.0,//MaxSpeed
		1.0,//Damage
		"models/v_knife.mdl",//v_model
		"models/p_knife.mdl",//p_model
		"weapons/knife_hit1.wav",//sound_hit
		"weapons/knife_stab.wav",//sound_stab
		"weapons/knife_hitwall1.wav",//sound_hitwall
		"weapons/knife_slash1.wav"//sound_slash
	},
	{
		"Default",//Name
		"\y[Speed++, Gravity++]",//Description
		ADMIN_LEVEL_A,//Admin Access
		1.0,//Attack1 Speed
		1.0,//Attack2 Speed
		0.7,//Gravity
		350.0,//MaxSpeed
		1.0,//Damage
		"models/v_knife.mdl",//v_model
		"models/p_knife.mdl",//p_model
		"weapons/knife_hit1.wav",//sound_hit
		"weapons/knife_stab.wav",//sound_stab
		"weapons/knife_hitwall1.wav",//sound_hitwall
		"weapons/knife_slash1.wav"//sound_slash
	},
	{
		"Default",//Name
		"\y[Slow Attack Speed, Damage++]",//Description
		0,//Admin Access
		0.5,//Attack1 Speed
		0.5,//Attack2 Speed
		1.0,//Gravity
		250.0,//MaxSpeed
		2.0,//Damage
		"models/v_knife.mdl",//v_model
		"models/p_knife.mdl",//p_model
		"weapons/knife_hit1.wav",//sound_hit
		"weapons/knife_stab.wav",//sound_stab
		"weapons/knife_hitwall1.wav",//sound_hitwall
		"weapons/knife_slash1.wav"//sound_slash
	},
	{
		"Default",//Name
		"\y[Fast Attack Speed, Damage--]",//Description
		0,//Admin Access
		2.0,//Attack1 Speed
		2.0,//Attack2 Speed
		1.0,//Gravity
		250.0,//MaxSpeed
		0.5,//Damage
		"models/v_knife.mdl",//v_model
		"models/p_knife.mdl",//p_model
		"weapons/knife_hit1.wav",//sound_hit
		"weapons/knife_stab.wav",//sound_stab
		"weapons/knife_hitwall1.wav",//sound_hitwall
		"weapons/knife_slash1.wav"//sound_slash
	}
};

#define DEFAULTABILITY_INTERVAL 3.0
#define DEFAULTABILITY_ADDHEALTH 5.0
#define DEFAULTABILITY_MAXHEALTH 100.0

new g_iPlayerKnife[33], Float:g_fOldGravity[33];

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);
	register_clcmd("say /knife", "Command_Knife");
	RegisterHam(Ham_Item_Deploy, "weapon_knife", "Ham_Knife_Deploy_Post", true);
	RegisterHam(Ham_Item_Holster, "weapon_knife", "Ham_Knife_Holster_Post", true);
	RegisterHam(Ham_Weapon_PrimaryAttack, "weapon_knife", "Ham_Knife_PrimaryAttack_Post", true);
	RegisterHam(Ham_Weapon_SecondaryAttack, "weapon_knife", "Ham_Knife_SecondaryAttack_Post", true);
	RegisterHam(Ham_CS_Item_GetMaxSpeed, "weapon_knife", "Ham_CS_Item_GetMaxSpeed_Pre", false);
	RegisterHam(Ham_TakeDamage, "player", "Ham_TakeDamage_Pre", false);
	register_forward(FM_EmitSound, "FM_EmitSound_Pre", false);
}
public plugin_precache()
{
	for(new i; i < sizeof(g_eKnives); i++)
	{
		precache_model(g_eKnives[i][MODEL_P]);
		precache_model(g_eKnives[i][MODEL_V]);
		precache_sound(g_eKnives[i][SOUND_HIT]);
		precache_sound(g_eKnives[i][SOUND_STAB]);
		precache_sound(g_eKnives[i][SOUND_HITWALL]);
		precache_sound(g_eKnives[i][SOUND_SLASH]);
	}
}
public client_putinserver(id)
{
	g_iPlayerKnife[id] = 0;
}
public client_disconnect(id)
{
	remove_task(id);
}
public Command_Knife(id)
{
	new menu = menu_create("\yKnives Menu", "KnivesMenu_Handler");
	new szText[64];
	for(new i; i < sizeof(g_eKnives); i++)
	{
		formatex(szText, charsmax(szText), "%s%s %s", g_iPlayerKnife[id] == i ? "\r": "", g_eKnives[i][NAME], g_eKnives[i][DESCRIPTION]);
		menu_additem(menu, szText, _, g_eKnives[i][ACCESS]);
	}
	menu_display(id, menu);
}
public KnivesMenu_Handler(id, menu, item)
{
	if(item == MENU_EXIT)
	{
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}
	
	remove_task(id);
	
	g_iPlayerKnife[id] = item;
	
	new weapon = fm_cs_get_current_weapon_ent(id);
	
	if(weapon != -1 && cs_get_weapon_id(weapon) == CSW_KNIFE)
	{
		new knife = g_iPlayerKnife[id];
		
		set_pev(id, pev_maxspeed, g_eKnives[knife][MAXSPEED]);
		set_pev(id, pev_gravity, g_eKnives[knife][GRAVITY]);
		set_pev(id, pev_viewmodel2, g_eKnives[knife][MODEL_V]);
		set_pev(id, pev_weaponmodel2, g_eKnives[knife][MODEL_P]);
		if(knife == 0)
		{
			set_task(DEFAULTABILITY_INTERVAL, "Task_DefaultKnifeAbility", id, .flags = "b");
		}
	}
	
	menu_destroy(menu);
	return PLUGIN_HANDLED;
}
public FM_EmitSound_Pre(id, channel, sample[])
{
	if(!is_user_alive(id) || g_iPlayerKnife[id] == 0) return FMRES_IGNORED;
	
	if(sample[8] == 'k' && sample[9] == 'n' && sample[10] == 'i' && sample[11] == 'f' && sample[12] == 'e')//knife
	{
		new knife = g_iPlayerKnife[id];
		if (sample[14] == 'h')
		{
			if(sample[17] == 'w')//hitwall
			{
				emit_sound(id, CHAN_WEAPON, g_eKnives[knife][SOUND_HITWALL], random_float(0.5, 1.0), ATTN_NORM, 0, PITCH_NORM);
			}
			else//hit
			{
				emit_sound(id, CHAN_WEAPON, g_eKnives[knife][SOUND_HIT], random_float(0.5, 1.0), ATTN_NORM, 0, PITCH_NORM);
			}
		}
		else if(sample[15] == 'l')//slash
		{
			emit_sound(id, CHAN_WEAPON, g_eKnives[knife][SOUND_SLASH], random_float(0.5, 1.0), ATTN_NORM, 0, PITCH_NORM);
		}
		else if(sample[17] == 'b')//stab
		{
			emit_sound(id, CHAN_WEAPON, g_eKnives[knife][SOUND_STAB], random_float(0.5, 1.0), ATTN_NORM, 0, PITCH_NORM);
		}//deploy??
		return FMRES_SUPERCEDE;
	}
	
	return FMRES_IGNORED;
}
public Ham_CS_Item_GetMaxSpeed_Pre(weapon)
{
	new player = get_pdata_cbase(weapon, m_pPlayer, XO_CBASEPLAYERWEAPON);
	new knife = g_iPlayerKnife[player];
	SetHamReturnFloat(g_eKnives[knife][MAXSPEED]);
	return HAM_SUPERCEDE;
}
public Ham_Knife_Deploy_Post(weapon)
{
	new player = get_pdata_cbase(weapon, m_pPlayer, XO_CBASEPLAYERWEAPON);
	pev(player, pev_gravity, g_fOldGravity[player]);
	
	new knife = g_iPlayerKnife[player];
	
	set_pev(player, pev_gravity, g_eKnives[knife][GRAVITY]);
	set_pev(player, pev_viewmodel2, g_eKnives[knife][MODEL_V]);
	set_pev(player, pev_weaponmodel2, g_eKnives[knife][MODEL_P]);
	
	//DefaultKnife Ability
	if(g_iPlayerKnife[player] == 0 && !task_exists(player))
	{
		set_task(DEFAULTABILITY_INTERVAL, "Task_DefaultKnifeAbility", player, .flags = "b");
	}
}
public Ham_Knife_Holster_Post(weapon)
{
	new player = get_pdata_cbase(weapon, m_pPlayer, XO_CBASEPLAYERWEAPON);
	set_pev(player, pev_gravity, g_fOldGravity[player]);
	remove_task(player);
}
public Ham_Knife_PrimaryAttack_Post(weapon)
{
	new player = get_pdata_cbase(weapon, m_pPlayer, XO_CBASEPLAYERWEAPON);
	new knife = g_iPlayerKnife[player];
	new Float:flRate = 0.35 / g_eKnives[knife][ATTACK_SPEED_RATE_1];
	
	set_pdata_float(weapon, m_flNextPrimaryAttack, flRate, XO_CBASEPLAYERWEAPON);
	set_pdata_float(weapon, m_flNextSecondaryAttack, flRate, XO_CBASEPLAYERWEAPON);
	set_pdata_float(weapon, m_flTimeWeaponIdle, flRate, XO_CBASEPLAYERWEAPON);
}
public Ham_Knife_SecondaryAttack_Post(weapon)
{
	new player = get_pdata_cbase(weapon, m_pPlayer, XO_CBASEPLAYERWEAPON);
	new knife = g_iPlayerKnife[player];
	new Float:flRate = 1.0 / g_eKnives[knife][ATTACK_SPEED_RATE_2];

	set_pdata_float(weapon, m_flNextPrimaryAttack, flRate, XO_CBASEPLAYERWEAPON);
	set_pdata_float(weapon, m_flNextSecondaryAttack, flRate, XO_CBASEPLAYERWEAPON);
	set_pdata_float(weapon, m_flTimeWeaponIdle, flRate, XO_CBASEPLAYERWEAPON);
}
public Ham_TakeDamage_Pre(victim, idinflictor, attacker, Float:damage, damagebits)
{
	if(attacker && attacker <= 32 && victim != attacker)
	{
		if(fm_cs_get_current_weapon_ent(attacker) == CSW_KNIFE)
		{
			new knife = g_iPlayerKnife[attacker];
			SetHamParamFloat(4, damage * g_eKnives[knife][DAMAGE]);
		}
	}
}
//DefaultKnife Ability
public Task_DefaultKnifeAbility(id)
{
	new Float:health = float(pev(id, pev_health));
	if(health < DEFAULTABILITY_MAXHEALTH)
	{
		set_pev(id, pev_health, floatmin(health + DEFAULTABILITY_ADDHEALTH, DEFAULTABILITY_MAXHEALTH));
		MsgScreenFade(id);
	}
}
stock fm_cs_get_current_weapon_ent(id)
{
	return (pev_valid(id) != PDATA_SAFE) ? -1 : get_pdata_cbase(id, m_pActiveItem, XO_CBASEPLAYER);
}
stock MsgScreenFade(id)
{
	static msg_screenfade; if(!msg_screenfade) msg_screenfade = get_user_msgid("ScreenFade");
	message_begin(MSG_ONE_UNRELIABLE, msg_screenfade, {0,0,0}, id);
	write_short(1<<10);
	write_short(1<<10);
	write_short(0x0000);
	write_byte(0);
	write_byte(200);
	write_byte(0);
	write_byte(75);
	message_end();
}
