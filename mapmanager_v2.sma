#include <amxmodx>

#if AMXX_VERSION_NUM < 183
#include <colorchat>
#else
#define DontChange print_team_default
#define Blue print_team_blue
#define Red print_team_red
#define Grey print_team_grey
#endif

#define PLUGIN "Map Manager"
#define VERSION "2.0"
#define AUTHOR "Mistrick"

#pragma semicolon 1

enum _:MAPS_INFO
{
	MAPNAME[32], MIN, MAX
}
enum _:BLOCKEDMAP_INFO
{
	MAPNAME[32], COUNT, INDEX
}
enum _:NOMINATEMAP_INFO
{
	MAPNAME[32], PLAYER, INDEX
}
enum _:VOTE_INFO
{
	MAPNAME[32], VOTES, INDEX
}
enum (+=100)
{
	TASK_SHOWMENU = 100,
	TASK_SHOWTIMER,
	TASK_TIMER,
	TASK_VOTEMENU,
	TASK_CHECKTIME,
	TASK_CHANGELEVEL,
	TASK_CHANGETODEFAULT,
	TASK_CHECKNIGHT
}

new const FILE_MAPS[] = "maps.ini";//configdir
new const FILE_BLOCKEDMAPS[] = "blockedmaps.ini";//datadir

new const PREFIX[] = "^4[MapManager]";

new Array:g_aMaps, Array:g_aNominatedMaps;

#define SELECT_MAPS 5//max 8
#define VOTE_TIME 10
#define SOUND_TIME 10//MAX 10
#define NOMINATE_MAX 3
#define NOMINATE_PLAYER_MAX 3
#define MAP_BLOCK 10

enum _:CVARS
{
	LOAD_MAPS_TYPE,
	CHANGE_TYPE,
	NOMINATION,
	SHOW_RESULT_TYPE,
	SHOW_SELECTS,
	START_VOTE_BEFORE_END,
	START_VOTE_TIME,
	BLACK_SCREEN,
	LAST_ROUND,
	CHANGE_TO_DEDAULT,
	DEFAULT_MAP,
	NIGHT_MODE,
	NIGHT_TIME,
	NIGHT_MAP,
	NIGHT_BLOCK_CMDS,
	STOP_VOTE_IN_MENU,
	ROCK_ENABLE,
	ROCK_MODE,
	ROCK_PERCENT,
	ROCK_PLAYERS,
	ROCK_CHANGE_TYPE,
	ROCK_DELAY,
	ROCK_BEFORE_END_BLOCK,
	ROCK_SHOW,
	ROCK_BLOCK_WITH_ADMIN,
	EXENDED_MAX,
	EXENDED_TIME,
	NEXTMAP,
	CHATTIME,
	TIMELIMIT,
	MAXROUNDS,
	WINLIMIT,
	FRIENDLYFIRE
}

new g_pCvars[CVARS];

new g_szCurrentMap[32];
new g_szMapPrefixes[][] = {"deathrun_", "de_"};
new g_iNominatedMaps[33];
new g_bVoteStarted;
new g_bVoteFinished;
new g_bPlayerVoted[33];
new g_iTotalVotes;
new g_eVoteMenu[SELECT_MAPS + 1][VOTE_INFO];
new g_iTimer;
new g_bRockVote;
new g_bRockVoted[33];
new g_iRockVote;
new g_iExtendedMax;
new g_iPage[33];
new g_iTeamScore[2];
new g_iStartPlugin;
new Float:g_fOldTimeLimit;
new g_bNightMode;

#if MAP_BLOCK > 1
new g_eBlockedMaps[MAP_BLOCK][BLOCKEDMAP_INFO];
#endif

new const g_szSound[][] =
{
	"",	"fvox/one",	"fvox/two",	"fvox/three", "fvox/four", "fvox/five",
	"fvox/six", "fvox/seven", "fvox/eight",	"fvox/nine", "fvox/ten"
};

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);	
	
	register_cvar("mm_version", VERSION, FCVAR_SERVER | FCVAR_SPONLY);
	
	g_pCvars[LOAD_MAPS_TYPE] = register_cvar("mm_load_maps_type", "1");//0 - load all maps from maps folder, 1 - load maps from files
	g_pCvars[CHANGE_TYPE] = register_cvar("mm_change_type", "2");//0 - after end vote, 1 - in round end, 2 - after end map
	g_pCvars[SHOW_RESULT_TYPE] = register_cvar("mm_show_result_type", "1");//0 - disable, 1 - menu, 2 - hud
	g_pCvars[SHOW_SELECTS] = register_cvar("mm_show_selects", "1");//0 - disable, 1 - all, 2 - self
	g_pCvars[START_VOTE_BEFORE_END] = register_cvar("mm_start_vote_before_end", "2");//minutes
	g_pCvars[START_VOTE_TIME] = register_cvar("mm_start_vote_time", "0");//if timelimit == 0
	g_pCvars[BLACK_SCREEN] = register_cvar("mm_black_screen", "0");//0 - disable, 1 - enable
	g_pCvars[LAST_ROUND] = register_cvar("mm_last_round", "0");//0 - disable, 1 - enable
	
	g_pCvars[CHANGE_TO_DEDAULT] = register_cvar("mm_change_to_default_map", "5");//minutes
	g_pCvars[DEFAULT_MAP] = register_cvar("mm_default_map", "de_dust2");
	
	g_pCvars[NIGHT_MODE] = register_cvar("mm_night_mode", "0");//0 - disable, 1 - enable
	g_pCvars[NIGHT_TIME] = register_cvar("mm_night_time", "23:00 8:00");
	g_pCvars[NIGHT_MAP] = register_cvar("mm_night_map", "de_dust2");
	g_pCvars[NIGHT_BLOCK_CMDS] = register_cvar("mm_night_block_cmds", "1");//0 - disable, 1 - enable
	
	g_pCvars[EXENDED_MAX] = register_cvar("mm_extended_map_max", "3");
	g_pCvars[EXENDED_TIME] = register_cvar("mm_extended_time", "15");//minutes
		
	g_pCvars[NOMINATION] = register_cvar("mm_nomination", "1");//0 - disable, 1 - enable
	g_pCvars[STOP_VOTE_IN_MENU] = register_cvar("mm_stop_vote_in_menu", "0");//0 - disable, 1 - enable
	
	g_pCvars[ROCK_ENABLE] = register_cvar("mm_rtv_enable", "1");//0 - disable, 1 - enable
	g_pCvars[ROCK_CHANGE_TYPE] = register_cvar("mm_rtv_change", "0");//0 - after vote, 1 - in round end
	g_pCvars[ROCK_MODE] = register_cvar("mm_rtv_mode", "0");//0 - percents, 1 - players
	g_pCvars[ROCK_PERCENT] = register_cvar("mm_rtv_percent", "60");
	g_pCvars[ROCK_PLAYERS] = register_cvar("mm_rtv_players", "5");
	g_pCvars[ROCK_DELAY] = register_cvar("mm_rtv_delay", "0");//minutes
	g_pCvars[ROCK_BEFORE_END_BLOCK] = register_cvar("mm_rtv_before_end_block", "0");//minutes
	g_pCvars[ROCK_SHOW] = register_cvar("mm_rtv_show", "1");//0 - all, 1 - self
	g_pCvars[ROCK_BLOCK_WITH_ADMIN] = register_cvar("mm_rtv_block_with_admin", "0");//0 - disable, 1 - enable
	
	g_pCvars[NEXTMAP] = register_cvar("amx_nextmap", "");
	
	g_pCvars[CHATTIME] = get_cvar_pointer("mp_chattime");
	g_pCvars[TIMELIMIT] = get_cvar_pointer("mp_timelimit");
	g_pCvars[MAXROUNDS] = get_cvar_pointer("mp_maxrounds");
	g_pCvars[WINLIMIT] = get_cvar_pointer("mp_winlimit");
	g_pCvars[FRIENDLYFIRE] = get_cvar_pointer("mp_friendlyfire");
	
	register_concmd("mm_startvote", "Command_StartVote", ADMIN_MAP);
	register_concmd("mm_stopvote", "Command_StopVote", ADMIN_MAP);
	register_clcmd("amx_map", "Command_AmxMapCmd");
	register_clcmd("amx_votemap", "Command_AmxMapCmd");
	register_clcmd("amx_mapmenu", "Command_AmxMapCmd");
	register_clcmd("say", "Command_Say");
	register_clcmd("say_team", "Command_Say");
	register_clcmd("say rtv", "Command_RTV");
	register_clcmd("say /rtv", "Command_RTV");
	register_clcmd("say maps", "Command_MapsList");
	register_clcmd("say /maps", "Command_MapsList");
	register_clcmd("votemap", "Command_Votemap");
	register_clcmd("say ff", "Command_FriendlyFire");
	register_clcmd("say nextmap", "Command_Nextmap");
	register_clcmd("say timeleft", "Command_Timeleft");
	register_clcmd("say currentmap", "Command_CurrentMap");
	
	register_menucmd(register_menuid("VoteMenu"), 1023, "VoteMenu_Handler");
	register_menucmd(register_menuid("MapsListMenu"), 1023, "MapsListMenu_Handler");
	
	register_event("HLTV", "Event_NewRound", "a", "1=0", "2=0");
	register_event("TextMsg", "Event_GameRestart", "a", "2=#Game_Commencing", "2=#Game_will_restart_in");
	register_event("TeamScore", "Event_TeamScore", "a");
	register_event("30", "Event_Intermission", "a");
	
	set_task(10.0, "Task_CheckTime", TASK_CHECKTIME, .flags = "b");
	set_task(60.0, "Task_CheckNight", TASK_CHECKNIGHT, .flags = "b");
}
public plugin_cfg()
{
	get_mapname(g_szCurrentMap, charsmax(g_szCurrentMap));
	g_aMaps = ArrayCreate(MAPS_INFO); g_aNominatedMaps = ArrayCreate(NOMINATEMAP_INFO);
	g_iStartPlugin = get_systime();
	Task_CheckNight();
	
	#if MAP_BLOCK > 1
	LoadBlockedMaps();
	#endif
	
	if(get_pcvar_num(g_pCvars[LOAD_MAPS_TYPE])) LoadMapList();
	else LoadMapsFromFolder();
	
	set_task(get_pcvar_float(g_pCvars[CHANGE_TO_DEDAULT]) * 60.0, "Task_ChangeToDefault", TASK_CHANGETODEFAULT);
}
LoadMapList()
{	
	new szDir[128]; get_localinfo("amxx_configsdir", szDir, charsmax(szDir));
	new szFile[128]; formatex(szFile, charsmax(szFile), "%s/%s", szDir, FILE_MAPS);
	#if MAP_BLOCK > 1
	new iBlockedMaps;
	#endif
	new iMapsCount, Info[MAPS_INFO];
	if(file_exists(szFile))
	{
		new szText[64], szMapName[32], szMax[3], szMin[3], f = fopen(szFile, "rt");
		if(f)
		{
			while(!feof(f))
			{
				fgets(f, szText, charsmax(szText));
				parse(szText, szMapName, charsmax(szMapName), szMin, charsmax(szMin), szMax, charsmax(szMax));

				trim(szMapName); remove_quotes(szMapName);
				
				if(!szMapName[0] || szMapName[0] == ';' || szMapName[0] == '/' && szMapName[1] == '/'
					|| !valid_map(szMapName) || is_map_in_array(szMapName) || equali(szMapName, g_szCurrentMap))
					continue;
				Info[MAPNAME] = szMapName;
				Info[MIN] = str_to_num(szMin);
				Info[MAX] = str_to_num(szMax) == 0 ? 32 : str_to_num(szMax);
				ArrayPushArray(g_aMaps, Info);
				szMin = ""; szMax = "";
				#if MAP_BLOCK > 1
				if(is_map_blocked(szMapName))
				{
					iBlockedMaps++;
					for(new i; i < MAP_BLOCK; i++)
					{
						if(equali(g_eBlockedMaps[i][MAPNAME], szMapName)) g_eBlockedMaps[i][INDEX] = iMapsCount;
					}
				}
				#endif
				iMapsCount++;
			}		
			fclose(f);
		}
	}
	if(iMapsCount == 0)
	{
		log_amx("Nothing loaded from %s", FILE_MAPS);
	}
	#if MAP_BLOCK > 1
	if(iBlockedMaps >= iMapsCount - SELECT_MAPS)
	{
		ClearBlockedMaps();
	}
	#endif
	
	new iNum;	
	do iNum = random_num(0, iMapsCount - 1);
	while(is_map_blocked_num(iNum));
	
	ArrayGetArray(g_aMaps, iNum, Info);
	set_pcvar_string(g_pCvars[NEXTMAP], Info[MAPNAME]);
}
LoadMapsFromFolder()
{
	new len, filename[64], Info[MAPS_INFO], iMapsCount, dir = open_dir("maps", filename, charsmax(filename));
	
	if(dir)
	{
		#if MAP_BLOCK > 1
		new iBlockedMaps;
		#endif
		while(next_file(dir, filename, charsmax(filename)))
		{
			len = strlen(filename) - 4;
			
			if(len < 0) continue;
			
			if(equali(filename[len], ".bsp") && !equali(filename, g_szCurrentMap))
			{
				filename[len] = '^0';
				formatex(Info[MAPNAME], charsmax(Info[MAPNAME]), filename);
				Info[MIN] = 0;
				Info[MAX] = 32;
				ArrayPushString(g_aMaps, filename);
				#if MAP_BLOCK > 1
				if(is_map_blocked(filename))
				{
					iBlockedMaps++;
					for(new i; i < MAP_BLOCK; i++)
					{
						if(equali(g_eBlockedMaps[i][MAPNAME], filename)) g_eBlockedMaps[i][INDEX] = iMapsCount;
					}
				}
				#endif
				iMapsCount++;
			}
		}
		close_dir(dir);
		
		#if MAP_BLOCK > 1
		if(iBlockedMaps >= iMapsCount - SELECT_MAPS)
		{
			ClearBlockedMaps();
		}
		#endif
	}
}
stock LoadBlockedMaps()
{
	new szDir[128]; get_localinfo("amxx_datadir", szDir, charsmax(szDir));
	new szFile[128]; formatex(szFile, charsmax(szFile), "%s/%s", szDir, FILE_BLOCKEDMAPS);
	
	if(!file_exists(szFile)) return PLUGIN_CONTINUE;
	
	new szTemp[128]; formatex(szTemp, charsmax(szTemp), "%s/temp.ini", szDir);
	new iFile = fopen(szFile, "rt");
	new iTemp = fopen(szTemp, "wt");
	
	new szBuffer[64], szMapName[32], szCount[8], iCount, i = 0;
	
	while(!feof(iFile))
	{
		fgets(iFile, szBuffer, charsmax(szBuffer));
		parse(szBuffer, szMapName, charsmax(szMapName), szCount, charsmax(szCount));
		
		if(is_map_blocked(szMapName) || !is_map_valid(szMapName) || equali(szMapName, g_szCurrentMap)) continue;
		
		iCount = str_to_num(szCount) - 1;
		
		if(!iCount) continue;
		
		if(iCount > MAP_BLOCK)
		{
			fprintf(iTemp, "^"%s^" ^"%d^"^n", szMapName, MAP_BLOCK);
			iCount = MAP_BLOCK;
		}
		else
		{
			fprintf(iTemp, "^"%s^" ^"%d^"^n", szMapName, iCount);
		}
		
		formatex(g_eBlockedMaps[i][MAPNAME], charsmax(g_eBlockedMaps[][MAPNAME]), szMapName);
		g_eBlockedMaps[i][COUNT] = iCount;
		
		if(++i >= MAP_BLOCK) break;
	}
	
	fclose(iFile);
	fclose(iTemp);
	
	delete_file(szFile);
	rename_file(szTemp, szFile, 1);
	
	return PLUGIN_CONTINUE;
}
stock ClearBlockedMaps()
{
	for(new i; i < MAP_BLOCK; i++)
	{
		g_eBlockedMaps[i][MAPNAME] = "";
		g_eBlockedMaps[i][COUNT] = 0;
		g_eBlockedMaps[i][INDEX] = 0;
	}
	new szDir[128]; get_localinfo("amxx_datadir", szDir, charsmax(szDir));
	new szFile[128]; formatex(szFile, charsmax(szFile), "%s/%s", szDir, FILE_BLOCKEDMAPS);
	delete_file(szFile);
}
public plugin_end()
{
	set_pcvar_num(g_pCvars[CHATTIME], get_pcvar_num(g_pCvars[CHATTIME]) - 6);
	if(g_iExtendedMax)
	{
		set_pcvar_float(g_pCvars[TIMELIMIT], get_pcvar_float(g_pCvars[TIMELIMIT]) - float(g_iExtendedMax * get_pcvar_num(g_pCvars[EXENDED_TIME])));
	}
	
	if(g_fOldTimeLimit > 0.0) set_pcvar_float(g_pCvars[TIMELIMIT], g_fOldTimeLimit);
	
	#if MAP_BLOCK > 1
	SaveBlockedMaps();
	#endif
}
stock SaveBlockedMaps()
{
	new szDir[128]; get_localinfo("amxx_datadir", szDir, charsmax(szDir));
	new szFile[128]; formatex(szFile, charsmax(szFile), "%s/%s", szDir, FILE_BLOCKEDMAPS);
	new szTemp[128]; formatex(szTemp, charsmax(szTemp), "%s/temp.ini", szDir);
	
	new iTemp = fopen(szTemp, "wt");
	
	if(iTemp)
	{
		for(new i = 0; i < MAP_BLOCK; i++)
		{
			if(g_eBlockedMaps[i][COUNT])
			{
				fprintf(iTemp, "^"%s^" ^"%d^"^n", g_eBlockedMaps[i][MAPNAME], g_eBlockedMaps[i][COUNT]);
			}
		}	
		
		fprintf(iTemp, "^"%s^" ^"%d^"^n", g_szCurrentMap, MAP_BLOCK);	
		fclose(iTemp);
		
		delete_file(szFile);
		rename_file(szTemp, szFile, 1);
	}
}
//***** Events *****//
public Event_NewRound()
{
	new iCvar = get_pcvar_num(g_pCvars[MAXROUNDS]);
	if(iCvar && (g_iTeamScore[0] + g_iTeamScore[1]) >= iCvar)
	{
		StartVote(0);
	}
	iCvar = get_pcvar_num(g_pCvars[WINLIMIT]);
	if(iCvar && (g_iTeamScore[0] >= iCvar || g_iTeamScore[1] >= iCvar))
	{
		StartVote(0);
	}
	if(g_bVoteFinished && (get_pcvar_num(g_pCvars[LAST_ROUND]) || get_pcvar_num(g_pCvars[CHANGE_TYPE]) == 1 || g_bRockVote && get_pcvar_num(g_pCvars[ROCK_CHANGE_TYPE]) == 1))
	{
		if(get_pcvar_num(g_pCvars[LAST_ROUND])) set_pcvar_float(g_pCvars[TIMELIMIT], g_fOldTimeLimit);
		
		Intermission();
		
		new szMapName[32]; get_pcvar_string(g_pCvars[NEXTMAP], szMapName, charsmax(szMapName));
		client_print_color(0, DontChange, "%s^1 Следующая карта:^3 %s^1.", PREFIX, szMapName);
		
		set_task(5.0, "ChangeLevel", TASK_CHANGELEVEL);
	}
	
	if(g_bNightMode)
	{
		new szMapName[32]; get_pcvar_string(g_pCvars[NIGHT_MAP], szMapName, charsmax(szMapName));
		if(!equali(szMapName, g_szCurrentMap))
		{
			Intermission();
			set_pcvar_string(g_pCvars[NEXTMAP], szMapName);
			set_task(5.0, "ChangeLevel", TASK_CHANGELEVEL);
			client_print_color(0, DontChange, "%s^1 Включен ночной режим на карте:^3 %s^1.", PREFIX, szMapName);
		}
	}
}
public Event_GameRestart()
{
	g_iStartPlugin = get_systime();
}
public Event_TeamScore()
{
	new team[2]; read_data(1, team, charsmax(team));
	g_iTeamScore[(team[0]=='C') ? 0 : 1] = read_data(2);
}
public Event_Intermission()
{
	set_pcvar_num(g_pCvars[CHATTIME], get_pcvar_num(g_pCvars[CHATTIME]) + 6);
	set_task(3.0, "ChangeLevel", TASK_CHANGELEVEL);
}
//***************** Check Time **********************
public Task_CheckTime()
{
	if(g_bVoteFinished || g_bVoteStarted) return PLUGIN_CONTINUE;
	
	static Float:fTimeLimit; fTimeLimit = get_pcvar_float(g_pCvars[TIMELIMIT]);
	
	if(fTimeLimit > 0.0)
	{
		if(get_systime() - g_iStartPlugin >= (fTimeLimit - get_pcvar_num(g_pCvars[START_VOTE_BEFORE_END])) * 60)
		{
			StartVote(0);
		}
	}
	else
	{
		new iTime = get_pcvar_num(g_pCvars[START_VOTE_TIME]) * 60;
		if(iTime && get_systime() - g_iStartPlugin >= iTime)
		{
			StartVote(0);
		}
	}
	
	return PLUGIN_CONTINUE;
}
public Task_CheckNight()
{
	if(!get_pcvar_num(g_pCvars[NIGHT_MODE])) return;
	
	new szTime[16]; get_pcvar_string(g_pCvars[NIGHT_TIME], szTime, charsmax(szTime));
	new szStart[8], szEnd[8]; parse(szTime, szStart, charsmax(szStart), szEnd, charsmax(szEnd));
	new iStartHour, iStartMinutes, iEndHour, iEndMinutes;
	get_int_time(szStart, iStartHour, iStartMinutes);
	get_int_time(szEnd, iEndHour, iEndMinutes);
	
	get_time("%H:%M", szTime, charsmax(szTime));
	new iCurHour, iCurMinutes; get_int_time(szTime, iCurHour, iCurMinutes);	
	
	new bOldNightMode = g_bNightMode;
	
	if(iStartHour != iEndHour && (iStartHour == iCurHour && iCurMinutes >= iStartMinutes || iEndHour == iCurHour && iCurMinutes < iStartMinutes))
	{
		g_bNightMode = true;
	}
	else if(iStartHour == iEndHour && iStartMinutes <= iCurMinutes < iEndMinutes)
	{
		g_bNightMode = true;
	}
	else if(iStartHour > iEndHour && (iStartHour < iCurHour < 24 || 0 <= iCurHour < iEndHour))
	{
		g_bNightMode = true;
	}
	else if(iStartHour < iCurHour < iEndHour)
	{
		g_bNightMode = true;
	}
	else
	{
		g_bNightMode = false;
	}
	
	if(g_bNightMode && !bOldNightMode)
	{
		new szMapName[32]; get_pcvar_string(g_pCvars[NIGHT_MAP], szMapName, charsmax(szMapName));
		if(equali(szMapName, g_szCurrentMap))
		{
			g_fOldTimeLimit = get_pcvar_float(g_pCvars[TIMELIMIT]);
			set_pcvar_float(g_pCvars[TIMELIMIT], 0.0);
			client_print_color(0, DontChange, "%s^1 Включен ночной режим до^3 %02d:%02d^1.", PREFIX, iEndHour, iEndMinutes);
		}		
	}
	else if(!g_bNightMode && bOldNightMode)
	{
		set_pcvar_float(g_pCvars[TIMELIMIT], g_fOldTimeLimit);
		client_print_color(0, DontChange, "%s^1 Выключен ночной режим.", PREFIX, iEndHour, iEndMinutes);
	}
}
//***************************************************
public client_putinserver(id)
{
	if(!is_user_bot(id) && !is_user_hltv(id))
		remove_task(TASK_CHANGETODEFAULT);
}
public client_disconnect(id)
{
	remove_task(id + TASK_VOTEMENU);
	if(g_bRockVoted[id])
	{
		g_bRockVoted[id] = false;
		g_iRockVote--;
	}
	if(g_iNominatedMaps[id])
	{
		clear_nominated_maps(id);
	}
	
	set_task(get_pcvar_float(g_pCvars[CHANGE_TO_DEDAULT]) * 60.0, "Task_ChangeToDefault", TASK_CHANGETODEFAULT);
}
public Task_ChangeToDefault()
{
	new szMapName[32]; get_pcvar_string(g_pCvars[DEFAULT_MAP], szMapName, charsmax(szMapName));
	if(get_players_num() == 0 && !equali(szMapName, g_szCurrentMap))
	{		
		server_cmd("changelevel %s", szMapName);
	}
}
public Command_AmxMapCmd(id)
{
	if(g_bNightMode && get_pcvar_num(g_pCvars[NIGHT_BLOCK_CMDS]))
	{
		client_print_color(id, DontChange, "%s^1 Команда запрещена в ночном режиме.", PREFIX);
		return PLUGIN_HANDLED;
	}
	return PLUGIN_CONTINUE;
}
public Command_Votemap(id)
{
	return PLUGIN_HANDLED;
}
public Command_FriendlyFire(id)
{
	client_print_color(0, DontChange, "%s^1 На сервере^3 %s^1 огонь по своим.", PREFIX, get_pcvar_num(g_pCvars[FRIENDLYFIRE]) ? "разрешен" : "запрещен");
}
public Command_Nextmap(id)
{
	new szMapName[32]; get_pcvar_string(g_pCvars[NEXTMAP], szMapName, charsmax(szMapName));
	client_print_color(0, id, "%s^1 Следующая карта: ^3%s^1.", PREFIX, szMapName);
}
public Command_Timeleft(id)
{
	if (get_pcvar_num(g_pCvars[TIMELIMIT]))
	{
		new a = get_timeleft();
		client_print_color(0, id, "%s^1 До конца карты осталось:^3 %d:%02d", PREFIX, (a / 60), (a % 60));
	}
	else
	{
		client_print_color(0, DontChange, "%s^1 Карта не ограничена по времени.", PREFIX);
	}
}
public Command_CurrentMap(id)
{
	client_print_color(0, id, "%s^1 Текущая карта:^3 %s^1.", PREFIX, g_szCurrentMap);
}
public Command_MapsList(id)
{
	Show_MapsListMenu(id, g_iPage[id] = 0);
}
public Show_MapsListMenu(id, iPage)
{
	if(iPage < 0) return PLUGIN_HANDLED;
	
	new iMax = ArraySize(g_aMaps);
	new i = min(iPage * 8, iMax);
	new iStart = i - (i % 8);
	new iEnd = min(iStart + 8, iMax);
	
	iPage = iStart / 8;
	g_iPage[id] = iPage;
	
	static szMenu[512],	iLen, Info[MAPS_INFO]; iLen = 0;
	
	iLen = formatex(szMenu, charsmax(szMenu), "\yСписок карт \w[%d/%d]:^n", iPage + 1, ((iMax - 1) / 8) + 1);
	
	new Keys, Item, iBlock, iNominated;
	
	for (i = iStart; i < iEnd; i++)
	{
		ArrayGetArray(g_aMaps, i, Info);
		iBlock = is_map_blocked(Info[MAPNAME]);
		iNominated = is_map_nominated(Info[MAPNAME]);
		if(iBlock)
		{
			iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n\r%d.\d %s[\r%d\d]", ++Item, Info[MAPNAME], iBlock);
		}
		else if(iNominated)
		{
			new NomInfo[NOMINATEMAP_INFO]; ArrayGetArray(g_aNominatedMaps, iNominated - 1, NomInfo);
			if(NomInfo[PLAYER] == id)
			{
				Keys |= (1 << Item);
				iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n\r%d.\w %s[\y*\w]", ++Item, Info[MAPNAME]);
				
			}
			else
			{
				iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n\r%d.\d %s[\y*\d]", ++Item, Info[MAPNAME]);
			}
		}
		else
		{
			Keys |= (1 << Item);
			iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n\r%d.\w %s", ++Item, Info[MAPNAME]);
		}
	}
	while(Item <= 8)
	{
		Item++;
		iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n");
	}
	if (iEnd < iMax)
	{
		Keys |= (1 << 8)|(1 << 9);		
		formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n\r9.\w Вперед^n\r0.\w %s", iPage ? "Назад" : "Выход");
	}
	else
	{
		Keys |= (1 << 9);
		formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n^n\r0.\w %s", iPage ? "Назад" : "Выход");
	}
	show_menu(id, Keys, szMenu, -1, "MapsListMenu");
	return PLUGIN_HANDLED;
}
public MapsListMenu_Handler(id, key)
{
	switch (key)
	{
		case 8: Show_MapsListMenu(id, ++g_iPage[id]);
		case 9: Show_MapsListMenu(id, --g_iPage[id]);
		default:
		{
			new index = key + g_iPage[id] * 8;
			new Info[MAPS_INFO]; ArrayGetArray(g_aMaps, index, Info);
			new szMapName[32]; formatex(szMapName, charsmax(szMapName), Info[MAPNAME]);
			NominateMap(id, szMapName, index);
			Show_MapsListMenu(id, g_iPage[id]);
		}
	}
	return PLUGIN_HANDLED;
}
public Command_RTV(id)
{
	if(g_bVoteFinished || g_bVoteStarted) return PLUGIN_HANDLED;
	
	if(!get_pcvar_num(g_pCvars[ROCK_ENABLE])) return PLUGIN_CONTINUE;
	
	if(g_bNightMode)
	{
		client_print_color(id, DontChange, "%s^1 Команда запрещена в ночном режиме.", PREFIX);
		return PLUGIN_HANDLED;
	}
	
	if(get_pcvar_num(g_pCvars[ROCK_BLOCK_WITH_ADMIN]) && check_admins())
	{
		client_print_color(id, DontChange, "%s^1 Недоступно, на сервере есть администратор.", PREFIX);
		return PLUGIN_HANDLED;
	}
	if(get_timeleft() / 60 < get_pcvar_num(g_pCvars[ROCK_BEFORE_END_BLOCK]))
	{
		client_print_color(id, DontChange, "%s^1 Слишком поздно для досрочного голосования.", PREFIX);
		return PLUGIN_HANDLED;
	}
	
	new iTime = get_systime();
	if(iTime - g_iStartPlugin < get_pcvar_num(g_pCvars[ROCK_DELAY]) * 60)
	{
		new iMin = 1 + (get_pcvar_num(g_pCvars[ROCK_DELAY]) * 60 - (iTime - g_iStartPlugin)) / 60;
		new szMin[16]; get_ending(iMin, "минут", "минута", "минуты", szMin, charsmax(szMin));
				
		client_print_color(id, DontChange, "%s^1 Вы не можете голосовать за досрочную смену карты. Осталось:^3 %d^1 %s.", PREFIX, iMin, szMin);
		return PLUGIN_HANDLED;
	}
	
	if(!g_bRockVoted[id])
	{
		g_bRockVoted[id] = true;
		g_iRockVote++;
		
		new iVote;
		
		if(g_pCvars[ROCK_MODE])
		{
			iVote = get_pcvar_num(g_pCvars[ROCK_PLAYERS]) - g_iRockVote;
		}
		else
		{
			iVote = floatround(get_players_num() * get_pcvar_num(g_pCvars[ROCK_PERCENT]) / 100.0, floatround_ceil) - g_iRockVote;
		}
		
		if(iVote > 0)
		{
			new szVote[16];	get_ending(iVote, "голосов", "голос", "голоса", szVote, charsmax(szVote));
			
			switch(get_pcvar_num(g_pCvars[ROCK_SHOW]))
			{
				case 0:
				{
					new szName[33];	get_user_name(id, szName, charsmax(szName));
					client_print_color(0, DontChange, "%s^3 %s^1 проголосовал за смену карты. Осталось:^3 %d^1 %s.", PREFIX, szName, iVote, szVote);
				}
				case 1: client_print_color(id, DontChange, "%s^1 Ваш голос учтен. Осталось:^3 %d^1 %s.", PREFIX, iVote, szVote);
			}
		}
		else
		{
			g_bRockVote = true;
			StartVote(0);
			client_print_color(0, DontChange, "%s^1 Начинаем досрочное голосование.", PREFIX);
		}
	}
	else
	{
		new iVote = floatround(get_players_num() * get_pcvar_num(g_pCvars[ROCK_PERCENT]) / 100.0, floatround_ceil) - g_iRockVote;
		new szVote[16];	get_ending(iVote, "голосов", "голос", "голоса", szVote, charsmax(szVote));
		client_print_color(id, DontChange, "%s^1 Вы уже голосовали. Осталось:^3 %d^1 %s.", PREFIX, iVote, szVote);
	}
	
	return PLUGIN_HANDLED;
}
public Command_StartVote(id, flag)
{
	if(~get_user_flags(id) & flag) return PLUGIN_HANDLED;
	
	if(g_bNightMode && get_pcvar_num(g_pCvars[NIGHT_BLOCK_CMDS]))
	{
		client_print_color(id, DontChange, "%s^1 Команда запрещена в ночном режиме.", PREFIX);
		return PLUGIN_HANDLED;
	}
	
	StartVote(id);
	return PLUGIN_HANDLED;
}
public Command_StopVote(id, flag)
{
	if(~get_user_flags(id) & flag) return PLUGIN_HANDLED;
	
	if(g_bVoteStarted)
	{
		if(get_pcvar_num(g_pCvars[BLACK_SCREEN])) cmd_screen_fade(0);
		
		g_bVoteStarted = false;
		g_bRockVote = false;
		g_iRockVote = 0;
		arrayset(g_bRockVoted, false, 33);
		
		remove_task(TASK_SHOWMENU);
		remove_task(TASK_SHOWTIMER);
		remove_task(TASK_TIMER);
		for(new i = 1; i <= 32; i++)
		{
			remove_task(TASK_VOTEMENU + i);
		}
		show_menu(0, 0, "^n", 1);
		new szName[32]; get_user_name(id, szName, charsmax(szName));
		client_print_color(0, id, "%s^3 %s^1 отменил голосование.", PREFIX, szName);
	}
	
	return PLUGIN_HANDLED;
}
public Command_Say(id)
{
	if(!get_pcvar_num(g_pCvars[NOMINATION]) || g_bVoteStarted) return;
	
	new szText[32]; read_args(szText, charsmax(szText));
	remove_quotes(szText); trim(szText); strtolower(szText);
	
	new index = is_map_in_array(szText);
	if(index)
	{
		NominateMap(id, szText, index);
	}
	else
	{
		for(new i; i < sizeof(g_szMapPrefixes); i++)
		{
			new szFormat[32]; formatex(szFormat, charsmax(szFormat), "%s%s", g_szMapPrefixes[i], szText);
			index = is_map_in_array(szFormat);
			if(index)
			{
				NominateMap(id, szFormat, index);
			}
		}
	}
}
NominateMap(id, map[32], index)
{	
	if(is_map_blocked(map))
	{
		client_print_color(id, DontChange, "%s^1 Эта карта недоступна для номинации.", PREFIX);
		return PLUGIN_CONTINUE;
	}
	
	new Info[NOMINATEMAP_INFO], szName[33];	get_user_name(id, szName, charsmax(szName));
	new nominate_id = is_map_nominated(map);
	if(nominate_id)
	{
		ArrayGetArray(g_aNominatedMaps, nominate_id - 1, Info);
		if(id == Info[PLAYER])
		{
			g_iNominatedMaps[id]--;
			ArrayDeleteItem(g_aNominatedMaps, nominate_id - 1);
			
			client_print_color(0, id, "%s^3 %s^1 убрал номинацию с карты^3 %s^1.", PREFIX, szName, map);
			return PLUGIN_CONTINUE;
		}
		client_print_color(id, DontChange, "%s^1 Эта карта уже номинирована.", PREFIX);
		return PLUGIN_CONTINUE;
	}
	
	if(g_iNominatedMaps[id] == NOMINATE_PLAYER_MAX)
	{
		client_print_color(id, DontChange, "%s^1 Вы не можете больше номинировать карты.", PREFIX);
		return PLUGIN_CONTINUE;
	}
	
	Info[MAPNAME] = map;
	Info[PLAYER] = id;
	Info[INDEX] = index - 1;
	ArrayPushArray(g_aNominatedMaps, Info);
	
	g_iNominatedMaps[id]++;
	
	client_print_color(0, id, "%s^3 %s^1 номинировал на голосование^3 %s^1.", PREFIX, szName, map);
	
	return PLUGIN_HANDLED;
}
//************************************************
public StartVote(id)
{
	if(g_bVoteStarted)
	{
		client_print_color(id, DontChange, "%s^1 Голосование запущено.", PREFIX);
		return PLUGIN_HANDLED;
	}
	
	g_bVoteStarted = true;
	
	ResetInfo();
		
	new iMax = 8, Limits[2]; Limits[0] = SELECT_MAPS; Limits[1] = ArraySize(g_aMaps);
	for(new i = 0; i < sizeof(Limits); i++)
	{
		if(iMax > Limits[i]) iMax = Limits[i];
	}
	
	new iNomInMenu, iNum, NomInfo[NOMINATEMAP_INFO];
	new iNomMax, iNomNum = ArraySize(g_aNominatedMaps);
	iNomMax = iNomNum > NOMINATE_MAX ? NOMINATE_MAX : iNomNum;
	
	new Array:array = ArrayCreate(VOTE_INFO), VoteInfo[VOTE_INFO], MapsInfo[MAPS_INFO], players_num;
	new iVoteInfoSize, iVoteNum;
	for(new i; i < Limits[1]; i++)
	{
		ArrayGetArray(g_aMaps, i, MapsInfo);
		if(MapsInfo[MIN] <= players_num <= MapsInfo[MAX] && !is_map_blocked_num(i))
		{
			formatex(VoteInfo[MAPNAME], charsmax(VoteInfo[MAPNAME]), MapsInfo[MAPNAME]);
			VoteInfo[INDEX] = i;
			iVoteInfoSize++;
			ArrayPushArray(array, VoteInfo);
		}
	}
	for(new i = 0; i < iMax; i++)
	{
		if(iNomInMenu < iNomMax)
		{
			iNum = random_num(0, ArraySize(g_aNominatedMaps) - 1);
			ArrayGetArray(g_aNominatedMaps, iNum, NomInfo);
			formatex(g_eVoteMenu[i][MAPNAME], charsmax(g_eVoteMenu[][MAPNAME]), NomInfo[MAPNAME]);
			g_eVoteMenu[i][INDEX] = NomInfo[INDEX];
			ArrayDeleteItem(g_aNominatedMaps, iNum);
			g_iNominatedMaps[NomInfo[PLAYER]]--;
		}
		else if(iVoteNum < iVoteInfoSize)
		{
			iVoteNum++;
			
			iNum = random_num(0, ArraySize(array) - 1);
			while(is_map_in_menu(iNum))
			{
				ArrayDeleteItem(array, iNum);
				iNum = random_num(0, ArraySize(array) - 1);
			}
			ArrayGetArray(array, iNum, VoteInfo);
			formatex(g_eVoteMenu[i][MAPNAME], charsmax(g_eVoteMenu[][MAPNAME]), VoteInfo[MAPNAME]);
			g_eVoteMenu[i][INDEX] = VoteInfo[INDEX];
			ArrayDeleteItem(array, iNum);
		}
		else
		{
			do iNum = random_num(0, Limits[1] - 1);
			while(is_map_in_menu(iNum) || is_map_blocked_num(iNum));
			
			ArrayGetArray(g_aMaps, iNum, MapsInfo);
			formatex(g_eVoteMenu[i][MAPNAME], charsmax(g_eVoteMenu[][MAPNAME]), MapsInfo[MAPNAME]);
			g_eVoteMenu[i][INDEX] = iNum;
		}
	}
	
	ArrayDestroy(array);
	
	#if SOUND_TIME > 10
	g_iTimer = 10;
	#else
	g_iTimer = SOUND_TIME;
	#endif
	set_task(1.0, "Show_Timer", TASK_SHOWTIMER, _, _, "a", g_iTimer);
	set_task(float(g_iTimer) + 1.0, "Show_VoteMenu", TASK_SHOWMENU);
	
	return PLUGIN_HANDLED;
}
ResetInfo()
{
	arrayset(g_bPlayerVoted, false, 33);
	g_iTotalVotes = 0;
	for(new i; i < SELECT_MAPS + 1; i++)
	{
		g_eVoteMenu[i][VOTES] = 0;
		g_eVoteMenu[i][INDEX] = -1;
	}
}
public Show_Timer()
{
	new szSec[16]; get_ending(g_iTimer, "секунд", "секунда", "секунды", szSec, charsmax(szSec));
	for(new i = 1; i <= 32; i++)
	{
		if(!is_user_connected(i)) continue;
		set_hudmessage(50, 255, 50, -1.0, is_user_alive(i) ? 0.9 : 0.3, 0, 0.0, 1.0, 0.0, 0.0, 1);
		show_hudmessage(i, "До голосования осталось %d %s!", g_iTimer, szSec);
	}
	
	client_cmd(0, "spk %s", g_szSound[g_iTimer--]);
}
public Show_VoteMenu()
{
	new Players[32], pNum, iPlayer; get_players(Players, pNum, "ch");
	
	g_iTimer = VOTE_TIME;
	
	set_task(1.0, "Task_Timer", TASK_TIMER, _, _, "a", VOTE_TIME);
	
	for(new i = 0; i < pNum; i++)
	{
		iPlayer = Players[i];
		VoteMenu(iPlayer + TASK_VOTEMENU);
		set_task(1.0, "VoteMenu", iPlayer + TASK_VOTEMENU, _, _, "a", VOTE_TIME);
	}
	
	client_cmd(0, "spk Gman/Gman_Choose2");	
}
public VoteMenu(id)
{
	id -= TASK_VOTEMENU;
	if(g_iTimer == 0)
	{
		show_menu(id, 0, "^n", 1); remove_task(id+TASK_VOTEMENU);
		return PLUGIN_HANDLED;
	}
	
	if(get_pcvar_num(g_pCvars[BLACK_SCREEN]))
	{
		cmd_screen_fade(1);
	}
	
	static szMenu[512], len; len = 0;
	
	len = formatex(szMenu[len], charsmax(szMenu) - len, "\y%s:^n^n", g_bPlayerVoted[id] ? "Результаты голосования" : "Выберите карту");
	
	new Key, iPercent, i, iMax = maps_in_menu();
	
	for(i = 0; i < iMax; i++)
	{		
		iPercent = 0;
		if(g_iTotalVotes)
		{
			iPercent = floatround(g_eVoteMenu[i][VOTES] * 100.0 / g_iTotalVotes);
		}
		
		if(!g_bPlayerVoted[id])
		{
			len += formatex(szMenu[len], charsmax(szMenu) - len, "\r%d.\w %s\d[\r%d%%\d]^n", i + 1, g_eVoteMenu[i][MAPNAME], iPercent);	
			Key |= (1 << i);		
		}
		else
		{
			len += formatex(szMenu[len], charsmax(szMenu) - len, "\d%s[\r%d%%\d]^n", g_eVoteMenu[i][MAPNAME], iPercent);
		}		
	}
	
	if(!g_bRockVote && get_pcvar_num(g_pCvars[TIMELIMIT]) != 0 && g_iExtendedMax < get_pcvar_num(g_pCvars[EXENDED_MAX]))
	{
		iPercent = 0;
		if(g_iTotalVotes)
		{
			iPercent = floatround(g_eVoteMenu[i][VOTES] * 100.0 / g_iTotalVotes);
		}
		
		if(!g_bPlayerVoted[id])
		{
			len += formatex(szMenu[len], charsmax(szMenu) - len, "^n\r%d.\w %s\d[\r%d%%\d]\y[Продлить]^n", i + 1, g_szCurrentMap, iPercent);	
			Key |= (1 << i);		
		}
		else
		{
			len += formatex(szMenu[len], charsmax(szMenu) - len, "^n\d%s[\r%d%%\d]\y[Продлить]^n", g_szCurrentMap, iPercent);
		}
	}
	
	if(get_pcvar_num(g_pCvars[STOP_VOTE_IN_MENU]) && get_user_flags(id) & ADMIN_MAP)
	{
		i++;
		len += formatex(szMenu[len], charsmax(szMenu) - len, "^n\r%d. Отменить голосование^n", i + 1 == 10 ? 0 : i + 1);
		Key |= (1 << i);
	}
	
	new szSec[16]; get_ending(g_iTimer, "секунд", "секунда", "секунды", szSec, charsmax(szSec));
	len += formatex(szMenu[len], charsmax(szMenu) - len, "^n\dОсталось \r%d\d %s", g_iTimer, szSec);
	
	if(!Key) Key |= (1 << 9);
	
	if(g_bPlayerVoted[id] && get_pcvar_num(g_pCvars[SHOW_RESULT_TYPE]) == 2)
	{
		while(replace(szMenu, charsmax(szMenu), "\r", "")){}
		while(replace(szMenu, charsmax(szMenu), "\d", "")){}
		while(replace(szMenu, charsmax(szMenu), "\w", "")){}
		while(replace(szMenu, charsmax(szMenu), "\y", "")){}
		
		set_hudmessage(0, 55, 255, 0.02, -1.0, 0, 6.0, 1.0, 0.1, 0.2, 4);
		show_hudmessage(id, "%s", szMenu);
	}
	else
	{
		show_menu(id, Key, szMenu, -1, "VoteMenu");
	}
	
	return PLUGIN_HANDLED;
}
public VoteMenu_Handler(id, key)
{
	if(g_bPlayerVoted[id])
	{
		VoteMenu(id + TASK_VOTEMENU);
		return PLUGIN_HANDLED;
	}
	if(get_pcvar_num(g_pCvars[STOP_VOTE_IN_MENU]) && key == maps_in_menu() + 1)
	{
		Command_StopVote(id, ADMIN_MAP);
		return PLUGIN_HANDLED;
	}
	
	g_eVoteMenu[key][VOTES]++;
	g_iTotalVotes++;
	g_bPlayerVoted[id] = true;
	
	new iCvar = get_pcvar_num(g_pCvars[SHOW_SELECTS]);
	if(iCvar)
	{
		new szName[32];	get_user_name(id, szName, charsmax(szName));
		if(key == maps_in_menu())
		{
			switch(iCvar)
			{
				case 1:	client_print_color(0, id, "^4%s^1 ^3%s^1 выбрал продление карты.", PREFIX, szName);
				case 2: client_print_color(id, DontChange, "^4%s^1 Вы выбрали продление карты.", PREFIX);
			}
		}
		else
		{
			switch(iCvar)
			{
				case 1:	client_print_color(0, id, "^4%s^3 %s^1 выбрал^3 %s^1.", PREFIX, szName, g_eVoteMenu[key][MAPNAME]);
				case 2: client_print_color(id, DontChange, "^4%s^1 Вы выбрали^3 %s^1.", PREFIX, g_eVoteMenu[key][MAPNAME]);
			}
		}
	}
	
	if(get_pcvar_num(g_pCvars[SHOW_RESULT_TYPE]))
	{
		VoteMenu(id + TASK_VOTEMENU);
	}
	else
	{
		remove_task(id + TASK_VOTEMENU);
	}
	
	return PLUGIN_HANDLED;
}
public Task_Timer()
{
	if(--g_iTimer == 0)
	{
		FinishVote();
		show_menu(0, 0, "^n", 1);		
		remove_task(TASK_TIMER);
	}
}
FinishVote()
{
	new MaxVote = 0, iInMenu = maps_in_menu(), iRandom;
	new iMax = g_bRockVote ? iInMenu : iInMenu + 1;
	for(new i = 1; i < iMax ; i++)
	{
		iRandom = random_num(0, 1);
		switch(iRandom)
		{
			case 0: if(g_eVoteMenu[MaxVote][VOTES] < g_eVoteMenu[i][VOTES]) MaxVote = i;
			case 1: if(g_eVoteMenu[MaxVote][VOTES] <= g_eVoteMenu[i][VOTES]) MaxVote = i;
		}
	}
	
	g_bVoteStarted = false;
	g_bVoteFinished = true;
	
	if(get_pcvar_num(g_pCvars[BLACK_SCREEN])) cmd_screen_fade(0);
	
	if(!g_iTotalVotes || (MaxVote != iInMenu))
	{
		if(g_iTotalVotes)
		{
			client_print_color(0, DontChange, "%s^1 Следующая карта:^3 %s^1.", PREFIX, g_eVoteMenu[MaxVote][MAPNAME]);
		}
		else
		{
			MaxVote = random_num(0, iInMenu - 1);
			client_print_color(0, DontChange, "%s^1 Никто не голосовал. Следуйщей будет^3 %s^1.", PREFIX, g_eVoteMenu[MaxVote][MAPNAME]);
		}
		
		set_pcvar_string(g_pCvars[NEXTMAP], g_eVoteMenu[MaxVote][MAPNAME]);
		
		if(get_pcvar_num(g_pCvars[LAST_ROUND]))
		{
			g_fOldTimeLimit = get_pcvar_float(g_pCvars[TIMELIMIT]);
			set_pcvar_float(g_pCvars[TIMELIMIT], 0.0);
			client_print_color(0, DontChange, "%s^1 Это последний раунд.", PREFIX);
		}
		else if(g_bRockVote && get_pcvar_num(g_pCvars[ROCK_CHANGE_TYPE]) == 0 || get_pcvar_num(g_pCvars[CHANGE_TYPE]) == 0)
		{
			client_print_color(0, DontChange, "%s^1 Карта сменится через^3 5^1 секунд.", PREFIX);
			Intermission();
			set_task(5.0, "ChangeLevel", TASK_CHANGELEVEL);
		}
		else if(g_bRockVote && get_pcvar_num(g_pCvars[ROCK_CHANGE_TYPE]) == 1 || get_pcvar_num(g_pCvars[CHANGE_TYPE]) == 1)
		{
			client_print_color(0, DontChange, "%s^1 Карта сменится в следующем раунде.", PREFIX);
		}
	}
	else
	{
		g_bVoteFinished = false;
		g_iExtendedMax++;
		new iMin = get_pcvar_num(g_pCvars[EXENDED_TIME]);
		new szMin[16]; get_ending(iMin, "минут", "минута", "минуты", szMin, charsmax(szMin));
		
		client_print_color(0, DontChange, "^4%s^1 Текущая карта продлена на^3 %d^1 %s.", PREFIX, iMin, szMin);
		set_pcvar_float(g_pCvars[TIMELIMIT], get_pcvar_float(g_pCvars[TIMELIMIT]) + float(iMin));
	}
}
public ChangeLevel()
{
	new szMapName[33]; get_pcvar_string(g_pCvars[NEXTMAP], szMapName, charsmax(szMapName));
	server_cmd("changelevel %s", szMapName);
}
//************************************
bool:valid_map(map[])
{
	if(is_map_valid(map)) return true;
	
	new len = strlen(map) - 4;
	
	if(len < 0) return false;
	
	if(equali(map[len], ".bsp"))
	{
		map[len] = '^0';		
		if(is_map_valid(map)) return true;
	}
	
	return false;
}
is_map_in_array(map[])
{
	new Info[MAPS_INFO], iMax = ArraySize(g_aMaps);
	for(new i = 0; i < iMax; i++)
	{
		ArrayGetArray(g_aMaps, i, Info);
		if(equali(Info[MAPNAME], map))
		{
			return i + 1;
		}
	}
	return 0;
}
is_map_blocked(map[])
{
	for(new i = 0; i < MAP_BLOCK; i++)
	{
		if(equali(g_eBlockedMaps[i][MAPNAME], map)) return g_eBlockedMaps[i][COUNT];
	}
	return 0;
}
is_map_blocked_num(num)
{
	for(new i = 0; i < MAP_BLOCK; i++)
	{
		if(g_eBlockedMaps[i][INDEX] == num) return g_eBlockedMaps[i][COUNT];
	}
	return 0;
}
is_map_nominated(map[])
{
	new Info[NOMINATEMAP_INFO], iMax = ArraySize(g_aNominatedMaps);
	for(new i = 0; i < iMax; i++)
	{
		ArrayGetArray(g_aNominatedMaps, i, Info);
		if(equali(Info[MAPNAME], map))
		{
			return i + 1;
		}
	}
	return 0;
}
is_map_in_menu(num)
{
	for(new i; i < SELECT_MAPS; i++)
	{
		if(g_eVoteMenu[i][INDEX] == num) return true;
	}
	return false;
}
maps_in_menu()
{
	new count;
	for(new i; i < SELECT_MAPS; i++)
	{
		if(g_eVoteMenu[i][INDEX] != -1) count++;
	}
	return count;
}
clear_nominated_maps(id)
{
	new Info[NOMINATEMAP_INFO];
	for(new i = 0; i < ArraySize(g_aNominatedMaps); i++)
	{
		ArrayGetArray(g_aNominatedMaps, i, Info);
		if(Info[PLAYER] == id)
		{
			ArrayDeleteItem(g_aNominatedMaps, i--);	
			if(!--g_iNominatedMaps[id]) break;
		}
	}
}
stock get_players_num()
{
	new num;
	for(new i = 1; i <= 32; i++)
	{
		if(is_user_connected(i) && !is_user_bot(i) && !is_user_hltv(i)) num++;
	}
	return num;
}
stock get_ending(num, const a[], const b[], const c[], output[], lenght)
{
	new num100 = num % 100, num10 = num % 10;
	if(num100 >=5 && num100 <= 20 || num10 == 0 || num10 >= 5 && num10 <= 9) format(output, lenght, "%s", a);
	else if(num10 == 1) format(output, lenght, "%s", b);
	else if(num10 >= 2 && num10 <= 4) format(output, lenght, "%s", c);
}
stock check_admins()
{
	for(new i = 1; i <= 32; i++)
	{
		if(is_user_connected(i) && get_user_flags(i) & ADMIN_MAP) return 1;
	}
	return 0;
}
stock cmd_screen_fade (fade)
{
	new time, hold, flags;
	static msgScreenFade; if(!msgScreenFade) msgScreenFade = get_user_msgid("ScreenFade");
	switch (fade)
	{
		case 1:
		{
			time = 1;
			hold = 1;
			flags = 4;
		}
	
		default:
		{
			time = 4096;
			hold = 1024;
			flags = 2;
		}
	}

	message_begin 	( MSG_BROADCAST, msgScreenFade, {0,0,0}, 0 );
	write_short	( time );
	write_short	( hold );
	write_short	( flags );
	write_byte	( 0 );
	write_byte	( 0 );
	write_byte	( 0 );
	write_byte	( 255 );
	message_end();

	return PLUGIN_CONTINUE;
}
Intermission()
{
	message_begin(MSG_ALL, SVC_INTERMISSION);
	message_end();
}
get_int_time(string[], &hour, &minutes)
{
	new left[4], right[4]; strtok(string, left, charsmax(left), right, charsmax(right), ':');
	hour = str_to_num(left);
	minutes = str_to_num(right);
}
