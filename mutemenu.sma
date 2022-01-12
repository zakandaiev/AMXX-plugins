#include <amxmodx>
#include <amxmisc>
#include <fakemeta>

/* ■■■■■■■■■■■■■■■■■■■■■■■■■■■■ CONFIG START ■■■■■■■■■■■■■■■■■■■■■■■■■■■■ */
#define MENU_TITLE          "\r[MUTE]\w Меню"
#define MENU_LABEL_GAGGED   "\r[\yзаткнут\r]"
/* ■■■■■■■■■■■■■■■■■■■■■■■■■■■■ CONFIG END ■■■■■■■■■■■■■■■■■■■■■■■■■■■■ */

new bool:playerMutes[MAX_PLAYERS + 1][MAX_PLAYERS + 1];

new cvar_alltalk;

public plugin_init() {
  register_plugin("Mute Menu", "1.0", "szawesome");

  register_forward(FM_Voice_SetClientListening, "CBasePlayer_SetClientListening");

  register_clcmd("say /mute", "ClCmd_ShowPlayersMenu");
  register_clcmd("say_team /mute", "ClCmd_ShowPlayersMenu");
  
  cvar_alltalk = get_cvar_pointer("sv_alltalk");
}

public client_putinserver(id) {
  ClearMutesList(id);
}
  
public client_disconnected(id) {
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

  new menu = menu_create(MENU_TITLE, "MenuHandler");

  new players[MAX_PLAYERS], playersCount;

  static pTeam[16];
  get_user_team(id, pTeam, sizeof pTeam);

  if(get_pcvar_num(cvar_alltalk) == 0 && (equal(pTeam, "CT") || equal(pTeam, "TERRORIST"))) {
    get_players_ex(players, playersCount, (GetPlayers_ExcludeBots | GetPlayers_ExcludeHLTV | GetPlayers_MatchTeam), pTeam);
  } else {
    get_players_ex(players, playersCount, (GetPlayers_ExcludeBots | GetPlayers_ExcludeHLTV));
  }

  new menuName[64], menuData[2];

  for(new item = 0; item < playersCount; item++) {
    if(id == players[item]) {
      continue;
    }
    if(playerMutes[id][players[item]]) {
      formatex(menuName, charsmax(menuName), "%n %s", players[item], MENU_LABEL_GAGGED);
    } else {
      formatex(menuName, charsmax(menuName), "%n", players[item]);
    }
    num_to_str(players[item], menuData, charsmax(menuData));
    menu_additem(menu, menuName, menuData);
  }

  menu_setprop(menu, MPROP_BACKNAME, "Назад");
  menu_setprop(menu, MPROP_NEXTNAME, "Далее");
  menu_setprop(menu, MPROP_EXITNAME, "Выход");
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

  new data[2], name[64], access, callback;
  menu_item_getinfo(menu, item, access, data, sizeof data, name, sizeof name, callback);

  new selectedPlayer = str_to_num(data);

  playerMutes[id][selectedPlayer] = playerMutes[id][selectedPlayer] ? false : true;
  client_print_color(id, print_team_red, "Ты %s ^3%n", playerMutes[id][selectedPlayer] ? "заткнул" : "снял мут с", selectedPlayer);

  new uMenu, uNewmenu, uMenupage;
  player_menu_info(id, uMenu, uNewmenu, uMenupage);

  menu_destroy(menu);

  if(uMenupage >= 0) {
    ShowPlayersMenu(id, uMenupage);
  }

  return PLUGIN_HANDLED;
}