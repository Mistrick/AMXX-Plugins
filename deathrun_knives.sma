#include <amxmodx>
#include <cstrike>
#include <fakemeta>
#include <hamsandwich>

#define PLUGIN "Deathrun: Knives"
#define VERSION "0.4.1"
#define AUTHOR "Mistrick"

#pragma semicolon 1

#define IsPlayer(%1) (%1 && %1 <= 32)

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
	DEFAULT_KNIFE,
	MODEL_V[64],
	MODEL_P[64],
	SOUND_HIT[64],
	SOUND_STAB[64],
	SOUND_HITWALL[64],
	SOUND_SLASH[64],
	SOUND_DEPLOY[64]
}
enum
{
	KNIFE_DEFAULT_REGENERATION = 0,
	KNIFE_SECOND,
	KNIFE_THIRD,
	KNIFE_FOURTH
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
		1,//Default Knife
		"models/v_knife.mdl",//v_model
		"models/p_knife.mdl",//p_model
		"weapons/knife_hit1.wav",//sound_hit
		"weapons/knife_stab.wav",//sound_stab
		"weapons/knife_hitwall1.wav",//sound_hitwall
		"weapons/knife_slash1.wav",//sound_slash
		"weapons/knife_deploy1.wav"//sound_deploy
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
		1,//Default Knife
		"",//v_model
		"",//p_model
		"",//sound_hit
		"",//sound_stab
		"",//sound_hitwall
		"",//sound_slash
		""//sound_deploy
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
		1,//Default Knife
		"",//v_model
		"",//p_model
		"",//sound_hit
		"",//sound_stab
		"",//sound_hitwall
		"",//sound_slash
		""//sound_deploy
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
		1,//Default Knife
		"",//v_model
		"",//p_model
		"",//sound_hit
		"",//sound_stab
		"",//sound_hitwall
		"",//sound_slash
		""//sound_deploy
	},
	{
		"Custom",//Name
		"\y[Fast Attack Speed, Damage--]",//Description
		0,//Admin Access
		2.0,//Attack1 Speed
		2.0,//Attack2 Speed
		1.0,//Gravity
		250.0,//MaxSpeed
		0.5,//Damage
		0,//Default Knife
		"models/knives/v_tixon.mdl",//v_model
		"models/knives/p_tixon.mdl",//p_model
		"weapons/knife_hit1.wav",//sound_hit
		"weapons/knife_stab.wav",//sound_stab
		"weapons/knife_hitwall1.wav",//sound_hitwall
		"weapons/knife_slash1.wav",//sound_slash
		"weapons/knife_deploy1.wav"//sound_deploy
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
	RegisterHam(Ham_CS_Item_GetMaxSpeed, "weapon_knife", "Ham_CS_Knife_GetMaxSpeed_Pre", false);
	RegisterHam(Ham_TakeDamage, "player", "Ham_TakeDamage_Pre", false);
	RegisterHam(Ham_TakeDamage, "player", "Ham_TakeDamage_Post", true);
	register_forward(FM_EmitSound, "FM_EmitSound_Pre", false);
}
public plugin_precache()
{
	for(new i; i < sizeof(g_eKnives); i++)
	{
		if(!g_eKnives[i][DEFAULT_KNIFE])
		{
			precache_model(g_eKnives[i][MODEL_P]);
			precache_model(g_eKnives[i][MODEL_V]);
			precache_sound(g_eKnives[i][SOUND_HIT]);
			precache_sound(g_eKnives[i][SOUND_STAB]);
			precache_sound(g_eKnives[i][SOUND_HITWALL]);
			precache_sound(g_eKnives[i][SOUND_SLASH]);
			precache_sound(g_eKnives[i][SOUND_DEPLOY]);
		}
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
	for(new i, szText[64]; i < sizeof(g_eKnives); i++)
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
		new knife = item;
		
		set_pev(id, pev_maxspeed, g_eKnives[knife][MAXSPEED]);
		set_pev(id, pev_gravity, g_eKnives[knife][GRAVITY]);
		if(!g_eKnives[knife][DEFAULT_KNIFE])
		{
			set_pev(id, pev_viewmodel2, g_eKnives[knife][MODEL_V]);
			set_pev(id, pev_weaponmodel2, g_eKnives[knife][MODEL_P]);
		}
		else
		{
			set_pev(id, pev_viewmodel2, "models/v_knife.mdl");
			set_pev(id, pev_weaponmodel2, "models/p_knife.mdl");
		}
		KnifeAbilityForward(id, knife);
	}
	
	menu_destroy(menu);
	return PLUGIN_HANDLED;
}
KnifeAbilityForward(id, knife)
{
	switch(knife)
	{
		case KNIFE_DEFAULT_REGENERATION:
		{
			if(!task_exists(id) && pev(id, pev_health) < DEFAULTABILITY_MAXHEALTH)
			{
				set_task(DEFAULTABILITY_INTERVAL, "Task_DefaultKnifeAbility", id, .flags = "b");
			}
		}
		case KNIFE_SECOND:
		{
			//your code
		}
		//other knives
	}
}
KnifeRemoveAbilityForward(id, knife)
{
	switch(knife)
	{
		case KNIFE_DEFAULT_REGENERATION:
		{
			remove_task(id);
		}
		case KNIFE_SECOND:
		{
			//your code
		}
		//other knives
	}
}
public FM_EmitSound_Pre(id, channel, sample[])
{
	if(!is_user_alive(id) || g_eKnives[g_iPlayerKnife[id]][DEFAULT_KNIFE] == 1) return FMRES_IGNORED;
	
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
		}
		else//deploy
		{
			emit_sound(id, CHAN_WEAPON, g_eKnives[knife][SOUND_DEPLOY], random_float(0.5, 1.0), ATTN_NORM, 0, PITCH_NORM);
		}
		return FMRES_SUPERCEDE;
	}
	
	return FMRES_IGNORED;
}
public Ham_CS_Knife_GetMaxSpeed_Pre(weapon)
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
	
	if(!g_eKnives[knife][DEFAULT_KNIFE])
	{
		set_pev(player, pev_viewmodel2, g_eKnives[knife][MODEL_V]);
		set_pev(player, pev_weaponmodel2, g_eKnives[knife][MODEL_P]);
	}
	
	KnifeAbilityForward(player, knife);
}
public Ham_Knife_Holster_Post(weapon)
{
	new player = get_pdata_cbase(weapon, m_pPlayer, XO_CBASEPLAYERWEAPON);
	set_pev(player, pev_gravity, g_fOldGravity[player]);
	new knife = g_iPlayerKnife[player];
	KnifeRemoveAbilityForward(player, knife);
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
	if(IsPlayer(attacker) && victim != attacker && !(damagebits & DMG_GRENADE))
	{
		new weapon = fm_cs_get_current_weapon_ent(victim);
		if(weapon != -1 && cs_get_weapon_id(weapon) == CSW_KNIFE)
		{
			new knife = g_iPlayerKnife[attacker];
			SetHamParamFloat(4, damage * g_eKnives[knife][DAMAGE]);
		}
	}
}
public Ham_TakeDamage_Post(victim, idinflictor, attacker, Float:damage, damagebits)
{
	if(g_iPlayerKnife[victim] == KNIFE_DEFAULT_REGENERATION && !task_exists(victim) && pev(victim, pev_health) < DEFAULTABILITY_MAXHEALTH)
	{
		new weapon = fm_cs_get_current_weapon_ent(victim);
		if(weapon != -1 && cs_get_weapon_id(weapon) == CSW_KNIFE)
		{
			set_task(DEFAULTABILITY_INTERVAL, "Task_DefaultKnifeAbility", victim, .flags = "b");
		}
	}
}
//DefaultKnife Ability
public Task_DefaultKnifeAbility(id)
{
	if(g_iPlayerKnife[id] != KNIFE_DEFAULT_REGENERATION)
	{
		remove_task(id);
		return;
	}
	new Float:health = float(pev(id, pev_health));
	if(health < DEFAULTABILITY_MAXHEALTH)
	{
		set_pev(id, pev_health, floatmin(health + DEFAULTABILITY_ADDHEALTH, DEFAULTABILITY_MAXHEALTH));
		MsgScreenFade(id);
	}
	else
	{
		remove_task(id);
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
