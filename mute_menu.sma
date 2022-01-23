#include <amxmodx>
#include <amxmisc>
#tryinclude <reapi>
#if !defined _reapi_included
	#include <fakemeta>
#endif

/* ■■■■■■■■■■■■■■■■■■■■■■■■■■■■ CONFIG START ■■■■■■■■■■■■■■■■■■■■■■■■■■■■ */
#define MENU_NUBER_COLOR "\w" // цвет нумерации меню: \w - белый, \y - желтый, \r - красный, \d - серый
#define LANG_NAME "mute_menu.txt" // название lang файла
// #define LANG_PLAYER id // расскомментируйте если мультиязычность работает некорректно (появится предупреждение при компиляции плагина, но это на его работу не повлияет)

new const menuCmds[][] = {
	"mute",
	"mutemenu",
	"mute_menu",
	"say /mute",
	"say_team /mute"
}
/* ■■■■■■■■■■■■■■■■■■■■■■■■■■■■ CONFIG END ■■■■■■■■■■■■■■■■■■■■■■■■■■■■ */

new cvar_alltalk,
		bool:playerMutes[MAX_PLAYERS + 1][MAX_PLAYERS + 1], // [reciever][sender]
		bool:playerMuteAll[MAX_PLAYERS + 1];

public plugin_init() {
	register_plugin("Mute Menu", "1.1.0", "szawesome");

	#if defined _reapi_included
		RegisterHookChain(RG_CSGameRules_CanPlayerHearPlayer, "CanPlayerHearPlayer_Pre", false);
	#else
		register_forward(FM_Voice_SetClientListening, "SetClientListening_Pre", false);
	#endif

	for(new i = 0; i < sizeof menuCmds; i++) {
		register_clcmd(menuCmds[i], "ClCmd_ShowPlayersMenu");
	}
	
	cvar_alltalk = get_cvar_pointer("sv_alltalk");

	generate_dictionary();
	register_dictionary(LANG_NAME);
}

public client_putinserver(id) {
	playerMuteAll[id] = false;
	for(new i = 1; i <= MaxClients; i++) {
		playerMutes[id][i] = false;
		if(playerMuteAll[i]) {
			playerMutes[i][id] = true;
		} else {
			playerMutes[i][id] = false;
		}
	}
}

#if defined _reapi_included
public CanPlayerHearPlayer_Pre(receiver, sender, bool:listen) {
#else
public SetClientListening_Pre(receiver, sender, bool:listen) {
#endif
	if(	receiver != sender && is_user_connected(receiver) & is_user_connected(sender)
			&& (playerMutes[receiver][sender] || playerMuteAll[receiver])
		) {
		#if defined _reapi_included
			SetHookChainReturn(ATYPE_BOOL, false);
			return HC_SUPERCEDE;
		#else
			engfunc(EngFunc_SetClientListening, receiver, sender, false);
			return FMRES_SUPERCEDE;
		#endif
	}

	#if defined _reapi_included
		return HC_CONTINUE;
	#else
		return FMRES_IGNORED;
	#endif
}

public ClCmd_ShowPlayersMenu(id) {
	if(!is_user_connected(id)) {
		return PLUGIN_HANDLED;
	}
	
	return ShowPlayersMenu(id);
}

ShowPlayersMenu(id, page = 0) {
	if(!is_user_connected(id)) {
		return PLUGIN_HANDLED;
	}

	new menu, menuTitle[64], menuItem_muteAll[64];
	formatex(menuTitle, charsmax(menuTitle), "%L", LANG_PLAYER, "MM_MENU_TITLE");
	if(playerMuteAll[id]) {
		formatex(menuItem_muteAll, charsmax(menuItem_muteAll), "%L %L^n", LANG_PLAYER, "MM_MENU_ITEM_ALL", LANG_PLAYER, "MM_MENU_LABEL_GAGGED");
	} else {
		formatex(menuItem_muteAll, charsmax(menuItem_muteAll), "%L^n", LANG_PLAYER, "MM_MENU_ITEM_ALL");
	}

	menu = menu_create(menuTitle, "MenuHandler");
	menu_additem(menu, menuItem_muteAll, "mute_all");

	new players[MAX_PLAYERS], playersCount;

	static pTeam[16];
	get_user_team(id, pTeam, charsmax(pTeam));

	if(get_pcvar_num(cvar_alltalk) == 0 && (equal(pTeam, "CT") || equal(pTeam, "TERRORIST"))) {
		get_players_ex(players, playersCount, (GetPlayers_ExcludeBots | GetPlayers_ExcludeHLTV | GetPlayers_MatchTeam), pTeam);
	} else {
		get_players_ex(players, playersCount, (GetPlayers_ExcludeBots | GetPlayers_ExcludeHLTV));
	}

	new menuName[64], menuData[16];

	for(new item = 0; item < playersCount; item++) {
		if(id == players[item]) {
			continue;
		}
		if(playerMutes[id][players[item]]) {
			formatex(menuName, charsmax(menuName), "%n %L", players[item], LANG_PLAYER, "MM_MENU_LABEL_GAGGED");
		} else {
			formatex(menuName, charsmax(menuName), "%n", players[item]);
		}
		num_to_str(players[item], menuData, charsmax(menuData));
		menu_additem(menu, menuName, menuData);
	}

	menu_setprop(menu, MPROP_PERPAGE, 7);
	menu_setprop(menu, MPROP_EXIT, MEXIT_ALL);
	menu_setprop(menu, MPROP_NUMBER_COLOR, MENU_NUBER_COLOR);
	menu_setprop(menu, MPROP_BACKNAME, fmt("%L", LANG_PLAYER, "BACK"));
	menu_setprop(menu, MPROP_NEXTNAME, fmt("%L", LANG_PLAYER, "MORE"));
	menu_setprop(menu, MPROP_EXITNAME, fmt("%L", LANG_PLAYER, "EXIT"));

	return menu_display(id, menu, page);
}

public MenuHandler(id, menu, item) {
	if(!is_user_connected(id)) {
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}

	if(item == MENU_EXIT || item < 0) {
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}

	new data[16], name[64], access, callback;
	menu_item_getinfo(menu, item, access, data, charsmax(data), name, charsmax(name), callback);

	if(equal(data, "mute_all")) {
		playerMuteAll[id] = !playerMuteAll[id];
		for(new i = 1; i <= MaxClients; i++) {
			playerMutes[id][i] = playerMuteAll[id];
		}
		client_print_color(id, print_team_red, "%L", LANG_PLAYER, playerMuteAll[id] ? "MM_ALERT_CHAT_ALL_SET" : "MM_ALERT_CHAT_ALL_UNSET");
	} else {
		new selectedPlayer = str_to_num(data);
		playerMutes[id][selectedPlayer] = !playerMutes[id][selectedPlayer];
		client_print_color(id, print_team_red, "%L", LANG_PLAYER, "MM_ALERT_CHAT", LANG_PLAYER, playerMutes[id][selectedPlayer] ? "MM_ALERT_OPTION_SET" : "MM_ALERT_OPTION_UNSET", selectedPlayer);
	}

	new uMenu, uNewmenu, uMenupage;
	player_menu_info(id, uMenu, uNewmenu, uMenupage);

	menu_destroy(menu);

	if(uMenupage >= 0) {
		ShowPlayersMenu(id, uMenupage);
	}

	return PLUGIN_HANDLED;
}

stock generate_dictionary() {
	new cfg_dir[64], cfg_file[128];
	get_localinfo("amxx_datadir", cfg_dir, charsmax(cfg_dir));
	formatex(cfg_file, charsmax(cfg_file), "%s/lang/%s", cfg_dir, LANG_NAME);
	
	if(!file_exists(cfg_file)) {
		write_file(cfg_file, "[ru]");
		write_file(cfg_file, "MM_MENU_TITLE = \r[MUTE]\w Меню");
		write_file(cfg_file, "MM_MENU_ITEM_ALL = Заткнуть всех");
		write_file(cfg_file, "MM_MENU_LABEL_GAGGED = \r[\yзаткнут\r]");
		write_file(cfg_file, "MM_ALERT_OPTION_SET = заткнул");
		write_file(cfg_file, "MM_ALERT_OPTION_UNSET = снял мут с");
		write_file(cfg_file, "MM_ALERT_CHAT = Ты %L ^^3%n");
		write_file(cfg_file, "MM_ALERT_CHAT_ALL_SET = Ты заткнул ^^3всех");
		write_file(cfg_file, "MM_ALERT_CHAT_ALL_UNSET = Ты снял мут ^^3со всех");
		write_file(cfg_file, "^n[en]");
		write_file(cfg_file, "MM_MENU_TITLE = \r[MUTE]\w Menu");
		write_file(cfg_file, "MM_MENU_ITEM_ALL = Mute all");
		write_file(cfg_file, "MM_MENU_LABEL_GAGGED = \r[\ymuted\r]");
		write_file(cfg_file, "MM_ALERT_OPTION_SET = muted");
		write_file(cfg_file, "MM_ALERT_OPTION_UNSET = unmuted");
		write_file(cfg_file, "MM_ALERT_CHAT = You %L ^^3%n");
		write_file(cfg_file, "MM_ALERT_CHAT_ALL_SET = You muted ^^3all");
		write_file(cfg_file, "MM_ALERT_CHAT_ALL_UNSET = You unmuted ^^3all");
	}
}