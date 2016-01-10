#include <amxmodx>

#if AMXX_VERSION_NUM < 183
#include <colorchat>
#endif

#define PLUGIN "Map Manager"
#define VERSION "2.5.0"
#define AUTHOR "Mistrick"

#pragma semicolon 1

///******** Settings ********///

#define FUNCTION_NEXTMAP //replace default nextmap
//#define FUNCTION_BLOCK_MAPS
#define FUNCTION_RTV
//#define FUNCTION_NOMINATION
#define FUNCTION_SOUND

#define SELECT_MAPS 5
#define PRE_START_TIME 5
#define VOTE_TIME 10

new const PREFIX[] = "^4[MapManager]";

///**************************///

enum (+=100)
{
	TASK_CHECKTIME,
	TASK_SHOWTIMER,
	TASK_TIMER,
	TASK_VOTEMENU
};

enum _:MAP_INFO
{
	m_Name[32],
	m_Min,
	m_Max
};
enum _:MENU_INFO
{
	n_Name[32],
	n_Index,
	n_Votes
};

new Array: g_aMaps;

enum _:CVARS
{
	START_VOTE_BEFORE_END,
	SHOW_RESULT_TYPE,
	SHOW_SELECTS,
	EXENDED_MAX,
	EXENDED_TIME,
	ROCK_MODE,
	ROCK_PERCENT,
	ROCK_PLAYERS,
	ROCK_CHANGE_TYPE,
	MAXROUNDS,
	WINLIMIT,
	TIMELIMIT,
	CHATTIME,
	NEXTMAP
};

new const MAPS_FILE[] = "maps.ini";

new g_pCvars[CVARS];
new g_iTeamScore[2];
new g_szCurrentMap[32];
new g_bVoteStarted;
new g_bVoteFinished;

new g_eMenuItems[SELECT_MAPS + 1][MENU_INFO];
new g_iMenuItemsCount;
new g_iTotalVotes;
new g_iTimer;
new g_bPlayerVoted[33];
new g_iExtendedMax;

#if defined FUNCTION_SOUND
new const g_szSound[][] =
{
	"", "sound/fvox/one.wav", "sound/fvox/two.wav", "sound/fvox/three.wav", "sound/fvox/four.wav", "sound/fvox/five.wav",
	"sound/fvox/six.wav", "sound/fvox/seven.wav", "sound/fvox/eight.wav", "sound/fvox/nine.wav", "sound/fvox/ten.wav"
};
#endif

#if defined FUNCTION_RTV
new g_bRockVoted[33];
new g_iRockVotes;
new g_bRockVote;
#endif
 
public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);
	
	register_cvar("mm_version", VERSION, FCVAR_SERVER | FCVAR_SPONLY);
	
	g_pCvars[START_VOTE_BEFORE_END] = register_cvar("mm_start_vote_before_end", "2");//minutes
	g_pCvars[SHOW_RESULT_TYPE] = register_cvar("mm_show_result_type", "1");//0 - disable, 1 - menu
	g_pCvars[SHOW_SELECTS] = register_cvar("mm_show_selects", "1");//0 - disable, 1 - all
	
	g_pCvars[EXENDED_MAX] = register_cvar("mm_extended_map_max", "3");
	g_pCvars[EXENDED_TIME] = register_cvar("mm_extended_time", "15");//minutes
	
	#if defined FUNCTION_RTV
	g_pCvars[ROCK_MODE] = register_cvar("mm_rtv_mode", "0");//0 - percents, 1 - players
	g_pCvars[ROCK_PERCENT] = register_cvar("mm_rtv_percent", "60");
	g_pCvars[ROCK_PLAYERS] = register_cvar("mm_rtv_players", "5");
	g_pCvars[ROCK_CHANGE_TYPE] = register_cvar("mm_rtv_change_type", "1");//0 - after vote, 1 - in round end
	#endif
	
	g_pCvars[MAXROUNDS] = get_cvar_pointer("mp_maxrounds");
	g_pCvars[WINLIMIT] = get_cvar_pointer("mp_winlimit");
	g_pCvars[TIMELIMIT] = get_cvar_pointer("mp_timelimit");
	
	g_pCvars[NEXTMAP] = register_cvar("amx_nextmap", "", FCVAR_SERVER|FCVAR_EXTDLL|FCVAR_SPONLY);
	
	#if defined FUNCTION_NEXTMAP
	g_pCvars[CHATTIME] = get_cvar_pointer("mp_chattime");
	#endif
	
	register_event("TeamScore", "Event_TeamScore", "a");
	register_event("HLTV", "Event_NewRound", "a", "1=0", "2=0");
	
	#if defined FUNCTION_NEXTMAP
	register_event("30", "Event_Intermisson", "a");
	#endif
	
	register_concmd("mm_debug", "Commang_Debug", ADMIN_MAP);
	register_concmd("mm_startvote", "Command_StartVote", ADMIN_MAP);
	register_concmd("mm_stopvote", "Command_StopVote", ADMIN_MAP);
	
	#if defined FUNCTION_NEXTMAP
	register_clcmd("say nextmap", "Command_Nextmap");
	register_clcmd("say currentmap", "Command_CurrentMap");
	#endif
	
	#if defined FUNCTION_RTV
	register_clcmd("say rtv", "Command_RockTheVote");
	register_clcmd("say /rtv", "Command_RockTheVote");
	#endif
	
	register_menucmd(register_menuid("VoteMenu"), 1023, "VoteMenu_Handler");
	
	set_task(10.0, "Task_CheckTime", TASK_CHECKTIME, .flags = "b");
}
public Commang_Debug(id)
{
	console_print(id, "^nLoaded maps:");
	
	new eMapInfo[MAP_INFO], iSize = ArraySize(g_aMaps);
	for(new i; i < iSize; i++)
	{
		ArrayGetArray(g_aMaps, i, eMapInfo);
		console_print(id, "%3d %32s ^t%d^t%d", i, eMapInfo[m_Name], eMapInfo[m_Min], eMapInfo[m_Max]);
	}
}
public Command_StartVote(id, flag)
{
	if(~get_user_flags(id) & flag) return PLUGIN_HANDLED;
	StartVote(id);	
	return PLUGIN_HANDLED;
}
public Command_StopVote(id, flag)
{
	if(~get_user_flags(id) & flag) return PLUGIN_HANDLED;
	
	if(g_bVoteStarted)
	{		
		g_bVoteStarted = false;
		
		#if defined FUNCTION_RTV
		g_bRockVote = false;
		g_iRockVotes = 0;
		arrayset(g_bRockVoted, false, 33);
		#endif
		
		remove_task(TASK_VOTEMENU);
		remove_task(TASK_SHOWTIMER);
		remove_task(TASK_TIMER);
		
		for(new i = 1; i <= 32; i++)
		{
			remove_task(TASK_VOTEMENU + i);
		}
		show_menu(0, 0, "^n", 1);
		new szName[32];
		
		if(id) get_user_name(id, szName, charsmax(szName));
		else szName = "Server";
		
		client_print_color(0, id, "%s^3 %s^1 отменил голосование.", PREFIX, szName);
	}
	
	return PLUGIN_HANDLED;
}

#if defined FUNCTION_NEXTMAP
public Command_Nextmap(id)
{
	new szMap[32]; get_pcvar_string(g_pCvars[NEXTMAP], szMap, charsmax(szMap));
	client_print_color(0, id, "%s^1 Следующая карта: ^3%s^1.", PREFIX, szMap);
}
public Command_CurrentMap(id)
{
	client_print_color(0, id, "%s^1 Текущая карта:^3 %s^1.", PREFIX, g_szCurrentMap);
}
#endif

#if defined FUNCTION_RTV
public Command_RockTheVote(id)
{
	if(g_bVoteFinished || g_bVoteStarted) return PLUGIN_HANDLED;
	
	if(!g_bRockVoted[id]) g_iRockVotes++;
	
	new iVotes;
	if(get_pcvar_num(g_pCvars[ROCK_MODE]))
	{
		iVotes = get_pcvar_num(g_pCvars[ROCK_PLAYERS]) - g_iRockVotes;
	}
	else
	{
		iVotes = floatround(GetPlayersNum() * get_pcvar_num(g_pCvars[ROCK_PERCENT]) / 100.0, floatround_ceil) - g_iRockVotes;
	}
	
	if(!g_bRockVoted[id])
	{
		g_bRockVoted[id] = true;		
		
		if(iVotes > 0)
		{
			new szName[33];	get_user_name(id, szName, charsmax(szName));
			new szVote[16];	GetEnding(iVotes, "голосов", "голос", "голоса", szVote, charsmax(szVote));
			client_print_color(0, print_team_default, "%s^3 %s^1 проголосовал за смену карты. Осталось:^3 %d^1 %s.", PREFIX, szName, iVotes, szVote);
		}
		else
		{
			g_bRockVote = true;
			StartVote(0);
			client_print_color(0, print_team_default, "%s^1 Начинаем досрочное голосование.", PREFIX);
		}
	}
	else
	{
		new szVote[16];	GetEnding(iVotes, "голосов", "голос", "голоса", szVote, charsmax(szVote));
		client_print_color(id, print_team_default, "%s^1 Вы уже голосовали. Осталось:^3 %d^1 %s.", PREFIX, iVotes, szVote);
	}
	
	return PLUGIN_HANDLED;
}
#endif

public plugin_end()
{
	if(g_iExtendedMax)
	{
		set_pcvar_float(g_pCvars[TIMELIMIT], get_pcvar_float(g_pCvars[TIMELIMIT]) - float(g_iExtendedMax * get_pcvar_num(g_pCvars[EXENDED_TIME])));
	}
}
public plugin_cfg()
{
	g_aMaps = ArrayCreate(MAP_INFO);
	
	LoadMapsFromFile();
	
	if( is_plugin_loaded("Nextmap Chooser") > -1 )
	{
		pause("cd", "mapchooser.amxx");
		log_amx("MapManager: mapchooser.amxx has been stopped.");
	}
	
	#if defined FUNCTION_NEXTMAP
	if( is_plugin_loaded("NextMap") > -1 )
	{
		pause("cd", "nextmap.amxx");
		log_amx("MapManager: nextmap.amxx has been stopped.");
	}	
	#endif
}
LoadMapsFromFile()
{
	new szDir[128]; get_localinfo("amxx_configsdir", szDir, charsmax(szDir));
	new szFile[128]; formatex(szFile, charsmax(szFile), "%s/%s", szDir, MAPS_FILE);
		
	get_mapname(g_szCurrentMap, charsmax(g_szCurrentMap));
	
	if(file_exists(szFile))
	{
		new f = fopen(szFile, "rt");
		
		if(f)
		{
			new eMapInfo[MAP_INFO];
			new szText[48], szMap[32], szMin[3], szMax[3];
			while(!feof(f))
			{
				fgets(f, szText, charsmax(szText));
				parse(szText, szMap, charsmax(szMap), szMin, charsmax(szMin), szMax, charsmax(szMax));
				
				if(!szMap[0] || szMap[0] == ';' || !ValidMap(szMap) || is_map_in_array(szMap) || equali(szMap, g_szCurrentMap)) continue;
				
				#if defined FUNCTION_BLOCK_MAPS
				if(is_map_blocked(szMap)) continue;
				#endif
				
				eMapInfo[m_Name] = szMap;
				eMapInfo[m_Min] = str_to_num(szMin);
				eMapInfo[m_Max] = str_to_num(szMax) == 0 ? 32 : str_to_num(szMax);
				
				ArrayPushArray(g_aMaps, eMapInfo);
				szMin = ""; szMax = "";
			}
			fclose(f);
			
			new iSize = ArraySize(g_aMaps);
			
			if(iSize == 0)
			{
				set_fail_state("Nothing loaded from file.");
			}
			
			#if defined FUNCTION_NEXTMAP
			new RandomMap = random_num(0, iSize - 1);
			ArrayGetArray(g_aMaps, RandomMap, eMapInfo);
			set_pcvar_string(g_pCvars[NEXTMAP], eMapInfo[m_Name]);
			#endif
		}		
	}
	else
	{
		set_fail_state("Maps file doesn't exist.");
	}
}
#if defined FUNCTION_NEXTMAP
public Event_Intermisson()
{
	new Float:fChatTime = get_pcvar_float(g_pCvars[CHATTIME]);
	set_pcvar_float(g_pCvars[CHATTIME], fChatTime + 2.0);
	set_task(fChatTime, "DelayedChange");
}
public DelayedChange()
{
	new szNextMap[32]; get_pcvar_string(g_pCvars[NEXTMAP], szNextMap, charsmax(szNextMap));
	set_pcvar_float(g_pCvars[CHATTIME], get_pcvar_float(g_pCvars[CHATTIME]) - 2.0);
	server_cmd("changelevel %s", szNextMap);
}
#endif
public Event_NewRound()
{
	new iMaxRounds = get_pcvar_num(g_pCvars[MAXROUNDS]);
	if(iMaxRounds && (g_iTeamScore[0] + g_iTeamScore[1]) >= iMaxRounds - 2)
	{
		log_amx("StartVote: maxrounds %d [%d]", iMaxRounds, g_iTeamScore[0] + g_iTeamScore[1]);
		StartVote(0);
	}
	
	new iWinLimit = get_pcvar_num(g_pCvars[WINLIMIT]) - 2;
	if(iWinLimit > 0 && (g_iTeamScore[0] >= iWinLimit || g_iTeamScore[1] >= iWinLimit))
	{
		log_amx("StartVote: winlimit %d [%d/%d]", iWinLimit, g_iTeamScore[0], g_iTeamScore[1]);
		StartVote(0);
	}
	
	#if defined FUNCTION_RTV
	if(g_bVoteFinished && g_bRockVote && get_pcvar_num(g_pCvars[ROCK_CHANGE_TYPE]) == 1)
	{
		Intermission();
		new szMapName[32]; get_pcvar_string(g_pCvars[NEXTMAP], szMapName, charsmax(szMapName));
		client_print_color(0, print_team_default, "%s^1 Следующая карта:^3 %s^1.", PREFIX, szMapName);
	}
	#endif
}
public Event_TeamScore()
{
	new team[2]; read_data(1, team, charsmax(team));
	g_iTeamScore[(team[0]=='C') ? 0 : 1] = read_data(2);
}
public Task_CheckTime()
{
	if(g_bVoteFinished) return PLUGIN_CONTINUE;
	
	new iTimeLeft = get_timeleft();
	if(iTimeLeft <= get_pcvar_num(g_pCvars[START_VOTE_BEFORE_END]) * 60)
	{
		log_amx("StartVote: timeleft %d", iTimeLeft);
		StartVote(0);
	}	
	
	return PLUGIN_CONTINUE;
}
public StartVote(id)
{
	if(g_bVoteStarted) return 0;
	
	g_bVoteStarted = true;
	
	ResetInfo();
	
	new Array:aMaps = ArrayCreate(MENU_INFO), CurrentSize = 0;
	new eMenuInfo[MENU_INFO], eMapInfo[MAP_INFO], iGlobalSize = ArraySize(g_aMaps);
	new iPlayersNum = GetPlayersNum();
	
	for(new i = 0; i < iGlobalSize; i++)
	{
		ArrayGetArray(g_aMaps, i, eMapInfo);
		if(eMapInfo[m_Min] <= iPlayersNum <= eMapInfo[m_Max])
		{
			formatex(eMenuInfo[n_Name], charsmax(eMenuInfo[n_Name]), eMapInfo[m_Name]);
			eMenuInfo[n_Index] = i; CurrentSize++;
			ArrayPushArray(aMaps, eMenuInfo);
		}
	}
	new Item = 0;
	if(CurrentSize)
	{
		g_iMenuItemsCount = min(CurrentSize, SELECT_MAPS);
		for(new iRandomMap; Item < g_iMenuItemsCount; Item++)
		{
			iRandomMap = random_num(0, ArraySize(aMaps) - 1);
			ArrayGetArray(aMaps, iRandomMap, eMenuInfo);
			
			formatex(g_eMenuItems[Item][n_Name], charsmax(g_eMenuItems[][n_Name]), eMenuInfo[n_Name]);
			g_eMenuItems[Item][n_Index] = eMenuInfo[n_Index];
			
			ArrayDeleteItem(aMaps, iRandomMap);
		}
	}
	
	if(Item < SELECT_MAPS)
	{
		g_iMenuItemsCount = min(iGlobalSize, SELECT_MAPS);
		for(new iRandomMap; Item < g_iMenuItemsCount; Item++)
		{
			do	iRandomMap = random_num(0, iGlobalSize - 1);
			while(is_map_in_menu(iRandomMap));	
			
			ArrayGetArray(g_aMaps, iRandomMap, eMapInfo);
			
			formatex(g_eMenuItems[Item][n_Name], charsmax(g_eMenuItems[][n_Name]), eMapInfo[n_Name]);
			g_eMenuItems[Item][n_Index] = iRandomMap;
		}
	}
	
	ArrayDestroy(aMaps);
	
	ForwardPreStartVote();
	
	return 0;
}
ResetInfo()
{
	g_iTotalVotes = 0;
	for(new i; i < sizeof(g_eMenuItems); i++)
	{
		g_eMenuItems[i][n_Name] = "";
		g_eMenuItems[i][n_Index] = -1;
		g_eMenuItems[i][n_Votes] = 0;
	}
	arrayset(g_bPlayerVoted, false, 33);
}
ForwardPreStartVote()
{
	#if PRE_START_TIME > 0
	g_iTimer = PRE_START_TIME;
	ShowTimer();
	#else
	ShowVoteMenu();
	#endif
}
public ShowTimer()
{
	if(g_iTimer > 0)
	{
		set_task(1.0, "ShowTimer", TASK_SHOWTIMER);
	}
	else
	{
		#if defined FUNCTION_SOUND
		SendAudio(0, "sound/Gman/Gman_Choose2.wav", PITCH_NORM);
		#endif
		ShowVoteMenu();
		return;
	}
	new szSec[16]; GetEnding(g_iTimer, "секунд", "секунда", "секунды", szSec, charsmax(szSec));
	new iPlayers[32], pNum; get_players(iPlayers, pNum, "ch");
	for(new id, i; i < pNum; i++)
	{
		id = iPlayers[i];
		set_hudmessage(50, 255, 50, -1.0, is_user_alive(id) ? 0.9 : 0.3, 0, 0.0, 1.0, 0.0, 0.0, 1);
		show_hudmessage(id, "До голосования осталось %d %s!", g_iTimer, szSec);
	}
	
	#if defined FUNCTION_SOUND
	if(g_iTimer <= 10)
	{
		for(new id, i; i < pNum; i++)
		{
			id = iPlayers[i];
			SendAudio(id, g_szSound[g_iTimer], PITCH_NORM);
		}
	}
	#endif
	
	g_iTimer--;
}
ShowVoteMenu()
{
	g_iTimer = VOTE_TIME;
	
	set_task(1.0, "Task_Timer", TASK_TIMER, .flags = "a", .repeat = VOTE_TIME);
	
	new Players[32], pNum, iPlayer; get_players(Players, pNum, "ch");
	for(new i = 0; i < pNum; i++)
	{
		iPlayer = Players[i];
		VoteMenu(iPlayer + TASK_VOTEMENU);
		set_task(1.0, "VoteMenu", iPlayer + TASK_VOTEMENU, _, _, "a", VOTE_TIME);
	}
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
public VoteMenu(id)
{
	id -= TASK_VOTEMENU;
	
	if(g_iTimer == 0)
	{
		show_menu(id, 0, "^n", 1); remove_task(id+TASK_VOTEMENU);
		return PLUGIN_HANDLED;
	}
	
	static szMenu[512];
	new iKeys, iPercent, i, iLen;
	
	iLen = formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\y%s:^n^n", g_bPlayerVoted[id] ? "Результаты голосования" : "Выберите карту");
	
	for(i = 0; i < g_iMenuItemsCount; i++)
	{		
		iPercent = 0;
		if(g_iTotalVotes)
		{
			iPercent = floatround(g_eMenuItems[i][n_Votes] * 100.0 / g_iTotalVotes);
		}
		
		if(!g_bPlayerVoted[id])
		{
			iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r%d.\w %s\d[\r%d%%\d]^n", i + 1, g_eMenuItems[i][n_Name], iPercent);	
			iKeys |= (1 << i);
		}
		else
		{
			iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\d%s[\r%d%%\d]^n", g_eMenuItems[i][n_Name], iPercent);
		}
	}
	
	#if defined FUNCTION_RTV
	if(!g_bRockVote && g_iExtendedMax < get_pcvar_num(g_pCvars[EXENDED_MAX]))
	#else
	if(g_iExtendedMax < get_pcvar_num(g_pCvars[EXENDED_MAX]))
	#endif
	{
		iPercent = 0;
		if(g_iTotalVotes)
		{
			iPercent = floatround(g_eMenuItems[i][n_Votes] * 100.0 / g_iTotalVotes);
		}
		
		if(!g_bPlayerVoted[id])
		{
			iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n\r%d.\w %s\d[\r%d%%\d]\y[Продлить]^n", i + 1, g_szCurrentMap, iPercent);	
			iKeys |= (1 << i);
		}
		else
		{
			iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n\d%s[\r%d%%\d]\y[Продлить]^n", g_szCurrentMap, iPercent);
		}
	}
	
	new szSec[16]; GetEnding(g_iTimer, "секунд", "секунда", "секунды", szSec, charsmax(szSec));
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n\dОсталось \r%d\d %s", g_iTimer, szSec);
	
	if(!iKeys) iKeys |= (1 << 9);
	
	show_menu(id, iKeys, szMenu, -1, "VoteMenu");
	
	return PLUGIN_HANDLED;
}
public VoteMenu_Handler(id, key)
{
	if(g_bPlayerVoted[id])
	{
		VoteMenu(id + TASK_VOTEMENU);
		return PLUGIN_HANDLED;
	}
	
	g_eMenuItems[key][n_Votes]++;
	g_iTotalVotes++;
	g_bPlayerVoted[id] = true;
	
	if(get_pcvar_num(g_pCvars[SHOW_SELECTS]))
	{
		new szName[32];	get_user_name(id, szName, charsmax(szName));
		if(key == g_iMenuItemsCount)
		{
			client_print_color(0, id, "^4%s^1 ^3%s^1 выбрал продление карты.", PREFIX, szName);
		}
		else
		{
			client_print_color(0, id, "^4%s^3 %s^1 выбрал^3 %s^1.", PREFIX, szName, g_eMenuItems[key][n_Name]);
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
FinishVote()
{
	g_bVoteStarted = false;
	g_bVoteFinished = true;
		
	new iMaxVote = 0, iRandom;
	for(new i = 1; i < g_iMenuItemsCount + 1; i++)
	{
		iRandom = random_num(0, 1);
		switch(iRandom)
		{
			case 0: if(g_eMenuItems[iMaxVote][n_Votes] < g_eMenuItems[i][n_Votes]) iMaxVote = i;
			case 1: if(g_eMenuItems[iMaxVote][n_Votes] <= g_eMenuItems[i][n_Votes]) iMaxVote = i;
		}
	}	
	
	if(!g_iTotalVotes || (iMaxVote != g_iMenuItemsCount))
	{
		if(g_iTotalVotes)
		{
			client_print_color(0, print_team_default, "%s^1 Следующая карта:^3 %s^1.", PREFIX, g_eMenuItems[iMaxVote][n_Name]);
		}
		else
		{
			iMaxVote = random_num(0, g_iMenuItemsCount - 1);
			client_print_color(0, print_team_default, "%s^1 Никто не голосовал. Следуйщей будет^3 %s^1.", PREFIX, g_eMenuItems[iMaxVote][n_Name]);
		}
		set_pcvar_string(g_pCvars[NEXTMAP], g_eMenuItems[iMaxVote][n_Name]);
		
		#if defined FUNCTION_RTV
		if(g_bRockVote && get_pcvar_num(g_pCvars[ROCK_CHANGE_TYPE]) == 0)
		{
			client_print_color(0, print_team_default, "%s^1 Карта сменится через^3 5^1 секунд.", PREFIX);
			Intermission();
		}
		else if(g_bRockVote && get_pcvar_num(g_pCvars[ROCK_CHANGE_TYPE]) == 1)
		{
			client_print_color(0, print_team_default, "%s^1 Карта сменится в следующем раунде.", PREFIX);
		}
		#endif
	}
	else
	{
		g_bVoteFinished = false;
		g_iExtendedMax++;
		new iMin = get_pcvar_num(g_pCvars[EXENDED_TIME]);
		new szMin[16]; GetEnding(iMin, "минут", "минута", "минуты", szMin, charsmax(szMin));
		
		client_print_color(0, print_team_default, "^4%s^1 Текущая карта продлена на^3 %d^1 %s.", PREFIX, iMin, szMin);
		set_pcvar_float(g_pCvars[TIMELIMIT], get_pcvar_float(g_pCvars[TIMELIMIT]) + float(iMin));
	}
}
///**************************///
stock GetPlayersNum()
{
	new count = 0;
	for(new i = 1; i < 33; i++)
	{
		if(is_user_connected(i) && !is_user_bot(i) && !is_user_hltv(i)) count++;
	}
	return count;
}
stock ValidMap(map[])
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
stock is_map_in_array(map[])
{
	new eMapInfo[MAP_INFO], size = ArraySize(g_aMaps);
	for(new i; i < size; i++)
	{
		ArrayGetArray(g_aMaps, i, eMapInfo);
		if(equali(map, eMapInfo[m_Name]))
		{
			return true;
		}
	}
	return false;
}
stock is_map_blocked(map[])
{
	return false;
}
stock is_map_in_menu(index)
{
	for(new i; i < sizeof(g_eMenuItems); i++)
	{
		if(g_eMenuItems[i][n_Index] == index) return true;
	}
	return false;
}
stock GetEnding(num, const a[], const b[], const c[], output[], lenght)
{
	new num100 = num % 100, num10 = num % 10;
	if(num100 >=5 && num100 <= 20 || num10 == 0 || num10 >= 5 && num10 <= 9) format(output, lenght, "%s", a);
	else if(num10 == 1) format(output, lenght, "%s", b);
	else if(num10 >= 2 && num10 <= 4) format(output, lenght, "%s", c);
}
stock SendAudio(id, audio[], pitch)
{
	static iMsgSendAudio;
	if(!iMsgSendAudio) iMsgSendAudio = get_user_msgid("SendAudio");
	
	if(id)
	{
		message_begin(MSG_ONE_UNRELIABLE, iMsgSendAudio, _, id);
		write_byte(id);
		write_string(audio);
		write_short(pitch);
		message_end();
	}
	else
	{
		new iPlayers[32], pNum; get_players(iPlayers, pNum, "ch");
		for(new id, i; i < pNum; i++)
		{
			id = iPlayers[i];
			message_begin(MSG_ONE_UNRELIABLE, iMsgSendAudio, _, id);
			write_byte(id);
			write_string(audio);
			write_short(pitch);
			message_end();
		}
	}
}
stock Intermission()
{
	emessage_begin(MSG_ALL, SVC_INTERMISSION);
	emessage_end();
}
