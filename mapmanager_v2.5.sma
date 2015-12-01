#include <amxmodx>

#if AMXX_VERSION_NUM < 183
#include <colorchat>
#endif

#define PLUGIN "Map Manager"
#define VERSION "2.5.0"
#define AUTHOR "Mistrick"

#pragma semicolon 1

///******** Settings ********///

//#define FUNCTION_NEXTMAP//replace default nextmap
//#define FUNCTION_BLOCK_MAPS
//#define FUNCTION_RTV
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
	"",	"fvox/one",	"fvox/two",	"fvox/three", "fvox/four", "fvox/five",
	"fvox/six", "fvox/seven", "fvox/eight",	"fvox/nine", "fvox/ten"
};
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
	
	g_pCvars[MAXROUNDS] = get_cvar_pointer("mp_maxrounds");
	g_pCvars[WINLIMIT] = get_cvar_pointer("mp_winlimit");
	g_pCvars[TIMELIMIT] = get_cvar_pointer("mp_timelimit");
	
	g_pCvars[NEXTMAP] = register_cvar("amx_nextmap", "", FCVAR_SERVER|FCVAR_EXTDLL|FCVAR_SPONLY);
	
	#if defined FUNCTION_NEXTMAP
	g_pCvars[CHATTIME] = get_cvar_pointer("mp_chattime");
	#endif
	
	register_event("TeamScore", "Event_TeamScore", "a");
	
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
	
	register_menucmd(register_menuid("VoteMenu"), 1023, "VoteMenu_Handler");
	
	set_task(10.0, "Task_CheckTime", TASK_CHECKTIME, .flags = "b");
}
public Commang_Debug(id)
{
	console_print(id, "^nLoaded maps:");
	
	new eMapInfo[MAP_INFO], size = ArraySize(g_aMaps);
	for(new i; i < size; i++)
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
				
				if(!szMap[0] || szMap[0] == ';' || !valid_map(szMap) || is_map_in_array(szMap) || equali(szMap, g_szCurrentMap)) continue;
				
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
			
			#if defined FUNCTION_NEXTMAP
			new RandomMap = random_num(0, ArraySize(g_aMaps));
			ArrayGetArray(g_aMaps, RandomMap, eMapInfo);
			set_pcvar_string(g_pCvars[NEXTMAP], eMapInfo[m_Name]);
			#endif
		}		
	}
	else
	{
		set_fail_state("Maps file don't exists.");
	}
}
#if defined FUNCTION_NEXTMAP
public Event_Intermisson()
{
	new Float:ChatTime = get_pcvar_float(g_pCvars[CHATTIME]);
	set_pcvar_float(g_pCvars[CHATTIME], ChatTime + 2.0);
	set_task(ChatTime, "DelayedChange");
}
public DelayedChange()
{
	new NextMap[32]; get_pcvar_string(g_pCvars[NEXTMAP], NextMap, charsmax(NextMap));
	set_pcvar_float(g_pCvars[CHATTIME], get_pcvar_float(g_pCvars[CHATTIME]) - 2.0);
	server_cmd("changelevel %s", NextMap);
}
#endif
public Event_TeamScore()
{
	new team[2]; read_data(1, team, charsmax(team));
	g_iTeamScore[(team[0]=='C') ? 0 : 1] = read_data(2);
}
public Task_CheckTime()
{
	if(g_bVoteFinished) return PLUGIN_CONTINUE;
	
	new TimeLeft = get_timeleft();	
	if(TimeLeft <= get_pcvar_num(g_pCvars[START_VOTE_BEFORE_END]) * 60)
	{
		log_amx("StartVote: timeleft %d", TimeLeft);
		StartVote(0);
	}
	
	new MaxRounds = get_pcvar_num(g_pCvars[MAXROUNDS]);
	if(MaxRounds && (g_iTeamScore[0] + g_iTeamScore[1]) >= MaxRounds - 2)
	{
		log_amx("StartVote: maxrounds %d [%d]", MaxRounds, g_iTeamScore[0] + g_iTeamScore[1]);
		StartVote(0);
	}
	
	new WinLimit = get_pcvar_num(g_pCvars[WINLIMIT]) - 2;
	if(WinLimit > 0 && (g_iTeamScore[0] >= WinLimit || g_iTeamScore[1] >= WinLimit))
	{
		log_amx("StartVote: winlimit %d [%d/%d]", WinLimit, g_iTeamScore[0], g_iTeamScore[1]);
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
	new eMenuInfo[MENU_INFO], eMapInfo[MAP_INFO], GlobalSize = ArraySize(g_aMaps);
	new PlayersNum = get_players_num();
	
	for(new i = 1; i < GlobalSize; i++)
	{
		ArrayGetArray(g_aMaps, i, eMapInfo);
		if(eMapInfo[m_Min] <= PlayersNum <= eMapInfo[m_Max])
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
		for(new RandomMap; Item < g_iMenuItemsCount; Item++)
		{
			RandomMap = random_num(0, ArraySize(aMaps) - 1);
			ArrayGetArray(aMaps, RandomMap, eMenuInfo);
			
			formatex(g_eMenuItems[Item][n_Name], charsmax(g_eMenuItems[][n_Name]), eMenuInfo[n_Name]);
			g_eMenuItems[Item][n_Index] = eMenuInfo[n_Index];
			
			ArrayDeleteItem(aMaps, RandomMap);
		}
	}
	
	if(Item < SELECT_MAPS)
	{
		g_iMenuItemsCount = min(GlobalSize, SELECT_MAPS);
		for(new RandomMap; Item < g_iMenuItemsCount; Item++)
		{
			do	RandomMap = random_num(0, GlobalSize - 1);
			while(is_map_in_menu(RandomMap));	
			
			ArrayGetArray(g_aMaps, RandomMap, eMapInfo);
			
			formatex(g_eMenuItems[Item][n_Name], charsmax(g_eMenuItems[][n_Name]), eMapInfo[n_Name]);
			g_eMenuItems[Item][n_Index] = RandomMap;
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
		client_cmd(0, "spk Gman/Gman_Choose2");
		#endif
		ShowVoteMenu();
		return;
	}
	new szSec[16]; get_ending(g_iTimer, "секунд", "секунда", "секунды", szSec, charsmax(szSec));
	for(new i = 1; i <= 32; i++)
	{
		if(!is_user_connected(i)) continue;
		set_hudmessage(50, 255, 50, -1.0, is_user_alive(i) ? 0.9 : 0.3, 0, 0.0, 1.0, 0.0, 0.0, 1);
		show_hudmessage(i, "До голосования осталось %d %s!", g_iTimer, szSec);
	}
	
	#if defined FUNCTION_SOUND
	if(g_iTimer <= 10) client_cmd(0, "spk %s", g_szSound[g_iTimer]);
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
	new Keys, Percent, i, Len;
	
	Len = formatex(szMenu[Len], charsmax(szMenu) - Len, "\y%s:^n^n", g_bPlayerVoted[id] ? "Результаты голосования" : "Выберите карту");
	
	for(i = 0; i < g_iMenuItemsCount; i++)
	{		
		Percent = 0;
		if(g_iTotalVotes)
		{
			Percent = floatround(g_eMenuItems[i][n_Votes] * 100.0 / g_iTotalVotes);
		}
		
		if(!g_bPlayerVoted[id])
		{
			Len += formatex(szMenu[Len], charsmax(szMenu) - Len, "\r%d.\w %s\d[\r%d%%\d]^n", i + 1, g_eMenuItems[i][n_Name], Percent);	
			Keys |= (1 << i);
		}
		else
		{
			Len += formatex(szMenu[Len], charsmax(szMenu) - Len, "\d%s[\r%d%%\d]^n", g_eMenuItems[i][n_Name], Percent);
		}
	}
	
	if(g_iExtendedMax < get_pcvar_num(g_pCvars[EXENDED_MAX]))
	{
		Percent = 0;
		if(g_iTotalVotes)
		{
			Percent = floatround(g_eMenuItems[i][n_Votes] * 100.0 / g_iTotalVotes);
		}
		
		if(!g_bPlayerVoted[id])
		{
			Len += formatex(szMenu[Len], charsmax(szMenu) - Len, "^n\r%d.\w %s\d[\r%d%%\d]\y[Продлить]^n", i + 1, g_szCurrentMap, Percent);	
			Keys |= (1 << i);		
		}
		else
		{
			Len += formatex(szMenu[Len], charsmax(szMenu) - Len, "^n\d%s[\r%d%%\d]\y[Продлить]^n", g_szCurrentMap, Percent);
		}
	}
	
	new szSec[16]; get_ending(g_iTimer, "секунд", "секунда", "секунды", szSec, charsmax(szSec));
	Len += formatex(szMenu[Len], charsmax(szMenu) - Len, "^n\dОсталось \r%d\d %s", g_iTimer, szSec);
	
	if(!Keys) Keys |= (1 << 9);
	
	show_menu(id, Keys, szMenu, -1, "VoteMenu");
	
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
		
	new MaxVote = 0, Random;
	for(new i = 1; i < g_iMenuItemsCount + 1; i++)
	{
		Random = random_num(0, 1);
		switch(Random)
		{
			case 0: if(g_eMenuItems[MaxVote][n_Votes] < g_eMenuItems[i][n_Votes]) MaxVote = i;
			case 1: if(g_eMenuItems[MaxVote][n_Votes] <= g_eMenuItems[i][n_Votes]) MaxVote = i;
		}
	}
	
	
	
	if(!g_iTotalVotes || (MaxVote != g_iMenuItemsCount))
	{
		if(g_iTotalVotes)
		{
			client_print_color(0, print_team_default, "%s^1 Следующая карта:^3 %s^1.", PREFIX, g_eMenuItems[MaxVote][n_Name]);
		}
		else
		{
			MaxVote = random_num(0, g_iMenuItemsCount - 1);
			client_print_color(0, print_team_default, "%s^1 Никто не голосовал. Следуйщей будет^3 %s^1.", PREFIX, g_eMenuItems[MaxVote][n_Name]);
		}
		set_pcvar_string(g_pCvars[NEXTMAP], g_eMenuItems[MaxVote][n_Name]);
	}
	else
	{
		g_bVoteFinished = false;
		g_iExtendedMax++;
		new iMin = get_pcvar_num(g_pCvars[EXENDED_TIME]);
		new szMin[16]; get_ending(iMin, "минут", "минута", "минуты", szMin, charsmax(szMin));
		
		client_print_color(0, print_team_default, "^4%s^1 Текущая карта продлена на^3 %d^1 %s.", PREFIX, iMin, szMin);
		set_pcvar_float(g_pCvars[TIMELIMIT], get_pcvar_float(g_pCvars[TIMELIMIT]) + float(iMin));
	}
}
///**************************///
stock get_players_num()
{
	new count = 0;
	for(new i = 1; i < 33; i++)
	{
		if(is_user_connected(i) && !is_user_bot(i) && !is_user_hltv(i)) count++;
	}
	return count;
}
stock valid_map(map[])
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
stock get_ending(num, const a[], const b[], const c[], output[], lenght)
{
	new num100 = num % 100, num10 = num % 10;
	if(num100 >=5 && num100 <= 20 || num10 == 0 || num10 >= 5 && num10 <= 9) format(output, lenght, "%s", a);
	else if(num10 == 1) format(output, lenght, "%s", b);
	else if(num10 >= 2 && num10 <= 4) format(output, lenght, "%s", c);
}
