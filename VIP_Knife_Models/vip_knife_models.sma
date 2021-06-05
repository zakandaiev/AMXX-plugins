#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <nvault>

#define ACCESS_FLAG ADMIN_LEVEL_H

new dMenu[36][64], dView[36][64], dPlayer[36][64], dLines;
new knife[33];
new g_vault;

new menuId, menuId_Callback;

public plugin_init() {
  register_plugin("VIP Knife Models", "1.0", "szawesome");
  
  g_vault = nvault_open("VIPKnifeModels");
  
  RegisterHam(Ham_Item_Deploy, "weapon_knife", "fwd_Deploy_Knife", true);

  BuildMenu();
}

BuildMenu() {
  register_clcmd("say /knife", "ShowMenu");
  register_clcmd("say_team /knife", "ShowMenu");
  register_clcmd("knifemenu", "ShowMenu");

  menuId = menu_create("\r[VIP]\w Меню ножей", "menuIdHandler");
  menuId_Callback = menu_makecallback("menuIdCallback");

  for(new i; i < dLines; i++) {
    new szTemp[10];
    num_to_str(i, szTemp, charsmax(szTemp));
    menu_additem(menuId, dMenu[i], szTemp, 0, menuId_Callback);
  }

  menu_setprop(menuId, MPROP_BACKNAME, "Назад");
  menu_setprop(menuId, MPROP_NEXTNAME, "Далее");
  menu_setprop(menuId, MPROP_EXITNAME, "Выход");
  menu_setprop(menuId, MPROP_PERPAGE, 7);
  menu_setprop(menuId, MPROP_EXIT, MEXIT_ALL);
  menu_setprop(menuId, MPROP_NUMBER_COLOR, "\w");
}

public menuIdCallback(id, menu, item) {
  if(item < 0) {
    return PLUGIN_HANDLED;
  }

  new data[16], name[128], access, callback;
  menu_item_getinfo(menu, item, access, data, sizeof data, name, sizeof name, callback);

  new menuNewItemName[128];

  // menu_item_setname меняет название пункта навсегда, поэтому надо возвращать по дефолту вот так:
  formatex(menuNewItemName, charsmax(menuNewItemName), "%s", dMenu[item]);
  menu_item_setname(menu, item, menuNewItemName);
  // а потом уже отображать состояние пунктов:

  if(knife[id] == item) {
    formatex(menuNewItemName, charsmax(menuNewItemName), "%s \r[\yвыбран\r]", dMenu[item]);
    menu_item_setname(menu, item, menuNewItemName);
    return ITEM_DISABLED;
  }
  
  return ITEM_IGNORE;
}

public menuIdHandler(id, menu, item) {
  if(!is_user_connected(id)) {
    return PLUGIN_HANDLED;
  }

  if(item == MENU_EXIT || item < 0) {
    return PLUGIN_HANDLED;
  }

  new data[16], name[128], access, callback;
  menu_item_getinfo(menu, item, access, data, sizeof data, name, sizeof name, callback);

  new key = str_to_num(data);
  knife[id]= key;
  SaveKnife(id);
  set_user_knife(id);

  return PLUGIN_HANDLED;
}

public ShowMenu(id) {
  if(!is_user_connected(id)) {
    return PLUGIN_HANDLED;
  }
  if(~get_user_flags(id) & ACCESS_FLAG) {
    client_print_color(id, print_team_default, "^4Доступно только ^3VIP^4 игрокам!");
    return PLUGIN_HANDLED;
  }
  return menu_display(id, menuId, 0);
}

public plugin_precache() {
  read_data_ini ();
  for(new index; index < dLines; index++){
    precache_model(dView[index]);
    precache_model(dPlayer[index]);
  }
}

public client_putinserver(id) {
  knife[id] = 0;
  LoadKnife(id);
}
public client_disconnected(id) {
  knife[id] = 0;
}

public fwd_Deploy_Knife(weapon) {
  new id = get_pdata_cbase(weapon, 41, 4);

  if(~get_user_flags(id) & ACCESS_FLAG) return HAM_IGNORED;
  
  if(is_user_alive(id)) {
    set_pev(id, pev_viewmodel2, dView[knife[id]]);
    set_pev(id, pev_weaponmodel2, dPlayer[knife[id]]);
  }
  
  return HAM_IGNORED;
}

public LoadKnife(id) {
  new g_name[33][64];
  new vaultkey[64],vaultdata[128];
  get_user_authid(id, g_name[id], 63);
  formatex(vaultkey,63,"%s", g_name[id]);
  if(nvault_get(g_vault,vaultkey,vaultdata,127)) {
    new knifeid[16];
    parse(vaultdata, knifeid, 15);
    knife[id] = str_to_num(knifeid);
  }
  return PLUGIN_CONTINUE;
}
public SaveKnife(id) {
  new g_name[33][64];
  new vaultkey[64],vaultdata[128];
  get_user_authid(id, g_name[id], 63);
  formatex(vaultkey,63,"%s", g_name[id]);
  formatex(vaultdata,127," %i", knife[id]);
  nvault_set(g_vault,vaultkey,vaultdata);
  return PLUGIN_CONTINUE;
}

stock set_user_knife(id){
  if(is_user_alive(id)) {
    engclient_cmd(id, "weapon_knife");
    set_pev(id, pev_viewmodel2, dView[knife[id]]);
    set_pev(id, pev_weaponmodel2, dPlayer[knife[id]]);
  }
}

stock read_data_ini () {
  new len, buffer[256];
  new file = fopen("/addons/amxmodx/configs/vip_knife_models.ini", "r");
  
  while(!feof(file)) {
    fgets(file, buffer, 255);
    trim(buffer);
    
    if(buffer[0]== '"') {
      parse(buffer, dMenu[len], 63, dView[len], 63, dPlayer[len], 63);
    } else {
      continue;
    }
    len++;
  }
  dLines = len;
  fclose(file);
}