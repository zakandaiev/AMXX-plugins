#include <amxmodx>
#include <amxmisc>
#include <reapi>

/* ■■■■■■■■■■■■■■■■■■■■■■■■■■■■ CONFIG START ■■■■■■■■■■■■■■■■■■■■■■■■■■■■ */
#define AUTO_CFG // автоматическое создание конфига с кварами
#define LANG_NAME "respawn_menu.txt" // название lang файла

new const menuCmds[][] = {
  "respawnmenu",
  "respawn_menu",
  "say /respawn",
  "say_team /respawn"
}
/* ■■■■■■■■■■■■■■■■■■■■■■■■■■■■ CONFIG END ■■■■■■■■■■■■■■■■■■■■■■■■■■■■ */

new menuId, cvar_access[32];

public plugin_init() {
  register_plugin("Respawn Menu", "1.0", "szawesome");

  bind_pcvar_string(
    create_cvar(
      .name = "rm_access",
      .string = "r",
      .flags = FCVAR_NONE,
      .description = "Флаг доступа к меню. Можно сочитать, например: ar"
    ),
    cvar_access, charsmax(cvar_access)
  );

  #if defined AUTO_CFG
  AutoExecConfig();
  #endif

  BuildMenu();

  for(new i = 0; i < sizeof menuCmds; i++) {
    register_clcmd(menuCmds[i], "ShowMenu");
  }
  
  GenerateDictionary();
  register_dictionary(LANG_NAME);
}

BuildMenu() {
  new menuTitle[64];
  formatex(menuTitle, sizeof menuTitle, "%L", LANG_PLAYER, "RM_TITLE");

  menuId = menu_create(menuTitle, "MenuHandler");

  new menuItem[64], langItem[16];

  for(new i = 1; i <= 5; i++) {
    formatex(langItem, sizeof langItem, "RM_ITEM_%d", i);
    formatex(menuItem, sizeof menuItem, "%L", LANG_PLAYER, langItem);
    menu_additem(menuId, menuItem);
  }

  menu_setprop(menuId, MPROP_BACKNAME, "Назад");
  menu_setprop(menuId, MPROP_NEXTNAME, "Далее");
  menu_setprop(menuId, MPROP_EXITNAME, "Выход");
  menu_setprop(menuId, MPROP_PERPAGE, 7);
  menu_setprop(menuId, MPROP_EXIT, MEXIT_ALL);
  menu_setprop(menuId, MPROP_NUMBER_COLOR, "\w");
}

public MenuHandler(id, menu, item) {
  if(!is_user_connected(id) || !has_flag(id, cvar_access)) {
    return PLUGIN_HANDLED;
  }

  if(item == MENU_EXIT || item < 0) {
    return PLUGIN_HANDLED;
  }

  switch(item) {
    case 0: {
      if(is_player_abled_to_respawn(id)) {
        rg_round_respawn(id);
        client_print_color(0, id, "%L", LANG_PLAYER, "RM_ITEM_1_ALERT", id);
      }
    }
    case 1: {
      ShowPlayersMenu(id);
    }
    case 2: {
      new players[MAX_PLAYERS], players_num;
      get_players(players, players_num, "beh", "CT");
      for(new i = 0; i < players_num; i++) {
        if(is_player_abled_to_respawn(players[i])) {
          rg_round_respawn(players[i]);
        }
      }
      client_print_color(0, print_team_blue, "%L", LANG_PLAYER, "RM_ITEM_3_ALERT", id);
    }
    case 3: {
      new players[MAX_PLAYERS], players_num;
      get_players(players, players_num, "beh", "TERRORIST");
      for(new i = 0; i < players_num; i++) {
        if(is_player_abled_to_respawn(players[i])) {
          rg_round_respawn(players[i]);
        }
      }
      client_print_color(0, print_team_red, "%L", LANG_PLAYER, "RM_ITEM_4_ALERT", id);
    }
    case 4: {
      new players[MAX_PLAYERS], players_num;
      get_players(players, players_num, "bh");
      for(new i = 0; i < players_num; i++) {
        if(is_player_abled_to_respawn(players[i])) {
          rg_round_respawn(players[i]);
        }
      }
      client_print_color(0, print_team_blue, "%L", LANG_PLAYER, "RM_ITEM_5_ALERT", id);
    }
  }

  return PLUGIN_HANDLED;
}

public ShowPlayersMenu(id) {
  if(!is_user_connected(id) || !has_flag(id, cvar_access)) {
    return PLUGIN_HANDLED;
  }

  new players[MAX_PLAYERS], players_num;
  get_players(players, players_num, "bh");

  if(players_num <= 0) {
    return PLUGIN_HANDLED;
  }

  new menu, menuTitle[64], menuName[64], menuData[2];

  formatex(menuTitle, sizeof menuTitle, "%L", LANG_PLAYER, "RM_TITLE_PLAYERS");

  menu = menu_create(menuTitle, "MenuHandler_Players");

  for(new i = 0; i < players_num; i++) {
    if(!is_player_abled_to_respawn(players[i])) {
      continue;
    }
    formatex(menuName, charsmax(menuName), "%n", players[i]);
    num_to_str(players[i], menuData, charsmax(menuData));
    menu_additem(menu, menuName, menuData);
  }

  menu_setprop(menu, MPROP_BACKNAME, "Назад");
  menu_setprop(menu, MPROP_NEXTNAME, "Далее");
  menu_setprop(menu, MPROP_EXITNAME, "Выход");
  menu_setprop(menu, MPROP_PERPAGE, 7);
  menu_setprop(menu, MPROP_EXIT, MEXIT_ALL);
  menu_setprop(menu, MPROP_NUMBER_COLOR, "\w");

  return menu_display(id, menu);
}

public MenuHandler_Players(id, menu, item) {
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

  if(is_player_abled_to_respawn(selectedPlayer)) {
    rg_round_respawn(selectedPlayer);
    client_print_color(0, selectedPlayer, "%L", LANG_PLAYER, "RM_ITEM_2_ALERT", id, selectedPlayer);
  }

  menu_destroy(menu);

  return PLUGIN_HANDLED;
}

public ShowMenu(id) {
  if(!is_user_connected(id)) {
    return PLUGIN_HANDLED;
  }

  if(!has_flag(id, cvar_access)) {
    client_print_color(id, print_team_default, "%L", LANG_PLAYER, "RM_ACCESS");
    return PLUGIN_HANDLED;
  }

  return menu_display(id, menuId);
}

is_player_abled_to_respawn(id) {
  if(!is_user_connected(id)) {
    return false;
  }

  new TeamName:pTeam = get_member(id, m_iTeam);

  if(!is_user_alive(id) && (pTeam == TEAM_CT || pTeam == TEAM_TERRORIST)) {
    return true;
  }

  return false;
}

stock GenerateDictionary() {
  new cfg_dir[64], cfg_file[128];
  get_localinfo("amxx_datadir", cfg_dir, charsmax(cfg_dir));
  formatex(cfg_file, charsmax(cfg_file), "%s/lang/%s", cfg_dir, LANG_NAME);
  
  if(!file_exists(cfg_file)) {
    write_file(cfg_file, "[ru]");
    write_file(cfg_file, "RM_ACCESS = ^^4Доступно только ^^3спонсорам^^4!");
    write_file(cfg_file, "RM_TITLE = \r[RESPAWN]\w Меню");
    write_file(cfg_file, "RM_TITLE_PLAYERS = \r[RESPAWN]\w Выбери игрока");
    write_file(cfg_file, "RM_ITEM_1 = Возродить себя");
    write_file(cfg_file, "RM_ITEM_2 = Возродить игрока^^n");
    write_file(cfg_file, "RM_ITEM_3 = Возродить мёртвых КТ");
    write_file(cfg_file, "RM_ITEM_4 = Возродить мёртвых ТТ");
    write_file(cfg_file, "RM_ITEM_5 = Возродить всех мёртвых");
    write_file(cfg_file, "RM_ITEM_1_ALERT = ^^3%n^^1 возродил^^3 сам себя");
    write_file(cfg_file, "RM_ITEM_2_ALERT = ^^3%n^^1 возродил^^3 %n");
    write_file(cfg_file, "RM_ITEM_3_ALERT = ^^3%n^^1 возродил всех мёртвых^^3 Контр-Террористов");
    write_file(cfg_file, "RM_ITEM_4_ALERT = ^^3%n^^1 возродил всех мёртвых^^3 Террористов");
    write_file(cfg_file, "RM_ITEM_5_ALERT = ^^3%n^^1 возродил ^^3всех мёртвых игроков");
    write_file(cfg_file, "^n[en]");
    write_file(cfg_file, "RM_ACCESS = ^^4Aviable only for ^^3sponsors^^4!");
    write_file(cfg_file, "RM_TITLE = \r[RESPAWN]\w Menu");
    write_file(cfg_file, "RM_TITLE_PLAYERS = \r[RESPAWN]\w Choose the player");
    write_file(cfg_file, "RM_ITEM_1 = Respawn myself");
    write_file(cfg_file, "RM_ITEM_2 = Respawn an player^^n");
    write_file(cfg_file, "RM_ITEM_3 = Respawn dead CTs");
    write_file(cfg_file, "RM_ITEM_4 = Respawn dead TTs");
    write_file(cfg_file, "RM_ITEM_5 = Respawn all deads");
    write_file(cfg_file, "RM_ITEM_1_ALERT = ^^3%n^^1 respawned^^3 himself");
    write_file(cfg_file, "RM_ITEM_2_ALERT = ^^3%n^^1 respawned^^3 %n");
    write_file(cfg_file, "RM_ITEM_3_ALERT = ^^3%n^^1 respawned all dead^^3 CTs");
    write_file(cfg_file, "RM_ITEM_4_ALERT = ^^3%n^^1 respawned all dead^^3 TTs");
    write_file(cfg_file, "RM_ITEM_5_ALERT = ^^3%n^^1 respawned ^^3all deads");
  }
}