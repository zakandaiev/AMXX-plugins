#include <amxmodx>
#include <amxmisc>
#include <fakemeta>

/* ■■■■■■■■■■■■■■■■■■■■■■■■■■■■ CONFIG START ■■■■■■■■■■■■■■■■■■■■■■■■■■■■ */
#define LANG_NAME "mute_menu.txt" // название lang файла

new const menuCmds[][] = {
	"mute",
	"mutemenu",
	"mute_menu",
	"say /mute",
	"say_team /mute"
}
/* ■■■■■■■■■■■■■■■■■■■■■■■■■■■■ CONFIG END ■■■■■■■■■■■■■■■■■■■■■■■■■■■■ */

new cvar_alltalk, bool:playerMutes[MAX_PLAYERS + 1][MAX_PLAYERS + 1]; // [reciever][sender]

public plugin_init() {
	register_plugin("Mute Menu", "1.0.0", "szawesome");

	register_forward(FM_Voice_SetClientListening, "CBasePlayer_SetClientListening");

	for(new i = 0; i < sizeof menuCmds; i++) {
		register_clcmd(menuCmds[i], "ClCmd_ShowPlayersMenu");
	}
	
	cvar_alltalk = get_cvar_pointer("sv_alltalk");

	generate_dictionary();
	register_dictionary(LANG_NAME);
}

public client_putinserver(id) {
	ClearMutesList(id);
}

public CBasePlayer_SetClientListening(receiver, sender, listen) {
	if(receiver == sender) {
		return FMRES_IGNORED;
	}
	
	if(playerMutes[receiver][sender]) {
		engfunc(EngFunc_SetClientListening, receiver, sender, 0);
		return FMRES_SUPERCEDE;
	}

	return FMRES_IGNORED;
}

ClearMutesList(id) {
	for(new i = 0; i <= MaxClients; ++i) {
		playerMutes[id][i] = false;
	}
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

	new menu, menuTitle[64];
	formatex(menuTitle, charsmax(menuTitle), "%L", LANG_PLAYER, "MM_MENU_TITLE");

	menu = menu_create(menuTitle, "MenuHandler");

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
	menu_setprop(menu, MPROP_NUMBER_COLOR, "\w");

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

	new selectedPlayer = str_to_num(data);

	playerMutes[id][selectedPlayer] = !playerMutes[id][selectedPlayer];
	client_print_color(id, print_team_red, "%L", LANG_PLAYER, "MM_ALERT_CHAT", LANG_PLAYER, playerMutes[id][selectedPlayer] ? "MM_ALERT_OPTION_SET" : "MM_ALERT_OPTION_UNSET", selectedPlayer);

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
		write_file(cfg_file, "MM_MENU_LABEL_GAGGED = \r[\yзаткнут\r]");
		write_file(cfg_file, "MM_ALERT_OPTION_SET = заткнул");
		write_file(cfg_file, "MM_ALERT_OPTION_UNSET = снял мут с");
		write_file(cfg_file, "MM_ALERT_CHAT = Ты %L ^^3%n");
		write_file(cfg_file, "^n[en]");
		write_file(cfg_file, "MM_MENU_TITLE = \r[MUTE]\w Menu");
		write_file(cfg_file, "MM_MENU_LABEL_GAGGED = \r[\ymuted\r]");
		write_file(cfg_file, "MM_ALERT_OPTION_SET = muted");
		write_file(cfg_file, "MM_ALERT_OPTION_UNSET = unmuted");
		write_file(cfg_file, "MM_ALERT_CHAT = You %L ^^3%n");
	}
}