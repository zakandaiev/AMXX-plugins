#include <amxmodx>
#include <amxmisc>

enum any:MENU_DATA {MENU_NAME[128], MENU_CMD[64]};

/* ■■■■■■■■■■■■■■■■■■■■■■■■■■■■ CONFIG START ■■■■■■■■■■■■■■■■■■■■■■■■■■■■ */
#define MENU_TITLE "\r[AWESOMECS.RU]\w Меню сервера"

new const menuData[][MENU_DATA] = {
  {"Информация^n", "say /info"},

  {"Обнулить счёт \r[\yRS\r]", "say /rs"},
  {"Поменять карту \r[\yRTV\r]", "say /rtv"},
  {"Номинировать карту \r[\yMAPS\r]^n", "say /maps"},

  {"Заткнуть игрока \r[\yMUTE\r]", "say /mute"},
  {"Забанить игрока \r[\yVOTEBAN\r]^n", "say /voteban"},

  {"\rАдмины\y онлайн", "say /admins"},

  {"Меню \r[\yVIP\r]", "vipmenu"},
  {"Меню ножей \r[\yVIP\r]", "knifemenu"},
  {"Меню управления \r[\yАдмин\r]", "amxmodmenu"},
  {"Меню возрождений \r[\yСпонсор\r]", "respawnmenu"}
};

new const menuCmds[][] =  {
  "say menu",
  "say_team menu",
  "say /menu",
  "say_team /menu",
  "menu",
  "nightvision"
}

#define ADVERT

#if defined ADVERT
#define ADVERT_TEXT "^3Меню^4 сервера на ^3N^4, или напиши ^3/menu^4 в чат!"
new const Float:ADVERT_INTERVAL = 183.0; // каждые n секунд
#endif
/* ■■■■■■■■■■■■■■■■■■■■■■■■■■■■ CONFIG END ■■■■■■■■■■■■■■■■■■■■■■■■■■■■ */

new menuId;

#if defined ADVERT
const TASK_ADVERT = 87;
#endif

public plugin_init() {
  register_plugin("Server Menu", "1.0", "szawesome");

  BuildMenu();
  
  #if defined ADVERT
    set_task_ex(ADVERT_INTERVAL, "SendAdvertMessage", TASK_ADVERT, .flags = SetTask_Repeat);
  #endif
}

BuildMenu() {
  for(new i = 0; i < sizeof menuCmds; i++) {
    register_clcmd(menuCmds[i], "ShowMenu");
  }

  menuId = menu_create(MENU_TITLE, "menuIdHandler");

  for(new i = 0; i < sizeof menuData; i++) {
    menu_additem(menuId, menuData[i][MENU_NAME], "", 0);
  }

  menu_setprop(menuId, MPROP_BACKNAME, "Назад");
  menu_setprop(menuId, MPROP_NEXTNAME, "Далее");
  menu_setprop(menuId, MPROP_EXITNAME, "Выход");
  menu_setprop(menuId, MPROP_PERPAGE, 7);
  menu_setprop(menuId, MPROP_EXIT, MEXIT_ALL);
  menu_setprop(menuId, MPROP_NUMBER_COLOR, "\w");
}

public menuIdHandler(id, menu, item) {
  if(!is_user_connected(id)) {
    return PLUGIN_HANDLED;
  }

  if(item == MENU_EXIT || item < 0) {
    return PLUGIN_HANDLED;
  }

  new key[sizeof menuData], name[sizeof menuData], access, callback;
  menu_item_getinfo(menu, item, access, key, sizeof key, name, sizeof name, callback);

  client_cmd(id, menuData[item][MENU_CMD]);

  return PLUGIN_HANDLED;
}

public ShowMenu(id) {
  if(!is_user_connected(id)) {
    return PLUGIN_HANDLED;
  }
  return menu_display(id, menuId, 0);
}

#if defined ADVERT
public SendAdvertMessage() {
  client_print_color(0, print_team_default, ADVERT_TEXT);
}
#endif