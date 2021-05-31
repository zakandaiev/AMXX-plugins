#include <amxmodx>
#include <amxmisc>
#include <fun>
#include <reapi>

/****************** НАСТРОЙКИ ******************/
// ОПОВЕЩЕНИЕ В ЧАТ
#define ADVERT

#if defined ADVERT
#define ADVERT_TEXT "^3CSDM^4 магазин на букву ^3Ш^4, или пиши ^3/shop^4 в чат!"
new const Float:ADVERT_INTERVAL = 200.0; // каждые секунд
#endif

// % выпадения рандомной возможности из магазина (при каждом респауне)
#define FREE_ITEM_CHANCE 5

#if defined FREE_ITEM_CHANCE
#define chance(%1) (%1 > random(100))
#endif

// МЕНЮ
enum any:MENU_DATA  { MENU_NAME[64], MENU_PRICE, MENU_FLAG };

enum any:SERVICES_LIST {
  SERVICE_SILENT_STEPS = 0,
  SERVICE_BHOP,
  SERVICE_FAST_RUN,
  SERVICE_GRAVITY,
  SERVICE_150HP,
  SERVICE_MULTIJUMP,
  SERVICE_OPACITY,
  SERVICE_VAMPIRE,
  SERVICE_AUTORELOAD,
  SERVICE_RPG7
};

new const menuData[][MENU_DATA] = {
  {"Тихий шаг", 3000, ADMIN_ALL},
  {"Банни-хоп", 3000, ADMIN_ALL},
  {"Быстрый бег", 4000, ADMIN_ALL},
  {"Гравитация", 5000, ADMIN_ALL},
  {"150 HP + 150 AP", 5500, ADMIN_ALL},
  {"Двойной прыжок", 6000, ADMIN_ALL},
  {"Полупрозрачность", 8000, ADMIN_ALL},
  {"Вампиризм", 10000, ADMIN_ALL},
  {"Автоперезарядка", 10000, ADMIN_ALL},
  {"RPG-7", 15000, ADMIN_ALL}
};

new const menuCmds[][] =  {
  "say shop",
  "say_team shop",
  "say /shop",
  "say_team /shop",
  "say /csdm_shop",
  "say_team /csdm_shop",
  "shop",
  "csdm_shop",
  "showbriefing"
}
/****************** КОНЕЦ НАСТРОЕК ******************/

enum any:HOOK_CHAINS {
  HookChain:ON_SPAWN_EQUIP_POST,
  HookChain:PLAYER_KILLED_POST,
  HookChain:PLAYER_RESET_MAXSPEED_PRE,
  HookChain:PLAYER_JUMP_PRE
};

new HookChain:hookChain[HOOK_CHAINS];

new menuId, menuId_Callback;

const TASK_ADVERT = 291;

new pActiveServices[MAX_CLIENTS + 1][sizeof menuData];

new pServiceMJ_jumps[MAX_CLIENTS + 1], pServiceMJ_jumpsDone[MAX_CLIENTS + 1];

new pServiceVampire_Hud;

// OUTISDE NATIVES
native isCsdmStarted();
native GiveRPG7(index);

// PLUGIN INIT
public plugin_init() {
  register_plugin("ReCSDM Shop", "1.1", "szawesome");

  RegisterForwards();
}

// PLUGIN EXECUTE
public OnConfigsExecuted() {
  if(isCsdmStarted()) {
    EnableForwards();
    BuildMenu();
    #if defined ADVERT
    set_task_ex(ADVERT_INTERVAL, "SendAdvertMessage", TASK_ADVERT, .flags = SetTask_Repeat);
    #endif
    pServiceVampire_Hud = CreateHudSyncObj();
  } else {
    pause("ad");
  }
}

// FORWARDS
public client_putinserver(id) {
  for(new i; i < sizeof menuData; i++) {
    pActiveServices[id][i] = false;
  }
}

public client_disconnected(id) {
  for(new i; i < sizeof menuData; i++) {
    pActiveServices[id][i] = false;
  }
}

public CBasePlayer_Killed_Post(victim, killer, gibs) {
  for(new i; i < sizeof menuData; i++) {
    pActiveServices[victim][i] = false;
  }

  /*
  Вроде-как само сбрасывается после смерти
  rg_set_user_footsteps(victim, false);
  set_entvar(victim, var_maxspeed, 250.0);
  set_entvar(victim, var_gravity, 1.0);
  */

  if(pActiveServices[killer][SERVICE_VAMPIRE]) {
    if(victim == killer || !is_user_alive(killer)) {
      return HC_CONTINUE;
    }

    new Float:killerHealth = Float:get_entvar(killer, var_health);
    new Float:healthAdd = get_member(victim, m_bHeadshotKilled) ? 15.0 : 10.0;

    set_entvar(killer, var_health, floatclamp(killerHealth + healthAdd, killerHealth, 100.0));

    set_hudmessage(0, 255, 0, -1.0, 0.15, 0, 6.0, 2.0);

    ShowSyncHudMsg(killer, pServiceVampire_Hud, "Вампиризм +%0.f HP", healthAdd);
  }

  if(pActiveServices[killer][SERVICE_AUTORELOAD]) {
    if(victim == killer || !is_user_alive(killer)) {
      return HC_CONTINUE;
    }

    rg_instant_reload_weapons(killer, 0);
  }

  return HC_CONTINUE;
}

#if defined FREE_ITEM_CHANCE
public CBasePlayer_OnSpawnEquip_Post(id, bool:addDefault, bool:equipGame) {
  if(is_user_alive(id)) {
    if(chance(FREE_ITEM_CHANCE)) {
      new itemKey = random(sizeof menuData);
      GiveItem(id, itemKey);
      client_print_color(id, print_team_default, "^4Поздравляем! Ты получил ^3%s^4 с шансом ^3%d%%^4!", menuData[itemKey][MENU_NAME], FREE_ITEM_CHANCE);
    }
  }
}
#endif

public CBasePlayer_ResetMaxSpeed_Pre(id) {
  return pActiveServices[id][SERVICE_FAST_RUN] ? HC_SUPERCEDE : HC_CONTINUE;
}

public CBasePlayer_Jump_Pre(id) {
  if(pActiveServices[id][SERVICE_BHOP]) {
    new const iFlags = get_entvar(id, var_flags);

    if(iFlags & FL_WATERJUMP || get_entvar(id, var_waterlevel) >= 2 || !(iFlags & FL_ONGROUND)) {
      return HC_CONTINUE;
    }

    new Float:flVelocity[3];
    get_entvar(id, var_velocity, flVelocity);

    flVelocity[2] = 250.0;

    set_entvar(id, var_velocity, flVelocity);
    set_entvar(id, var_gaitsequence, 6);
    set_entvar(id, var_fuser2, 0.0);
  }

  if(pActiveServices[id][SERVICE_MULTIJUMP]) {
    new additionalJumps;
    if(get_user_flags(id) & ADMIN_BAN) {
      additionalJumps = 2;
    } else {
      additionalJumps = 1;
    }

    new iFlags = get_entvar(id, var_flags);

    static Float:flJumpTime[MAX_CLIENTS + 1];

    if (pServiceMJ_jumpsDone[id] && (iFlags & FL_ONGROUND)) {
      pServiceMJ_jumpsDone[id] = 0;
      flJumpTime[id] = get_gametime();

      return HC_CONTINUE;
    }

    static Float:flGameTime;

    if ((get_entvar(id, var_oldbuttons) & IN_JUMP || iFlags & FL_ONGROUND) || ((flGameTime = get_gametime()) - flJumpTime[id]) < 0.2) {
      return HC_CONTINUE;
    }

    if (pServiceMJ_jumpsDone[id] >= additionalJumps && !pServiceMJ_jumps[id]) {
      return HC_CONTINUE;
    }

    flJumpTime[id] = flGameTime;

    new Float:flVelocity[3];
    get_entvar(id, var_velocity, flVelocity);
    flVelocity[2] = 350.0;

    set_entvar(id, var_velocity, flVelocity);

    pServiceMJ_jumpsDone[id]++;

    if (pServiceMJ_jumps[id] && pServiceMJ_jumpsDone[id] > additionalJumps) {
      pServiceMJ_jumps[id]--;
    }
  }
  
  return HC_CONTINUE;
}

// CUSTOM FUNTIONS
#if defined ADVERT
public SendAdvertMessage() {
  client_print_color(0, print_team_default, ADVERT_TEXT);
}
#endif

RegisterForwards() {
  #if defined FREE_ITEM_CHANCE
    DisableHookChain(hookChain[ON_SPAWN_EQUIP_POST] = RegisterHookChain(RG_CBasePlayer_OnSpawnEquip, "CBasePlayer_OnSpawnEquip_Post", true));
  #endif
  DisableHookChain(hookChain[PLAYER_KILLED_POST] = RegisterHookChain(RG_CBasePlayer_Killed, "CBasePlayer_Killed_Post", true));
  DisableHookChain(hookChain[PLAYER_RESET_MAXSPEED_PRE] = RegisterHookChain(RG_CBasePlayer_ResetMaxSpeed, "CBasePlayer_ResetMaxSpeed_Pre", false));
  DisableHookChain(hookChain[PLAYER_JUMP_PRE] = RegisterHookChain(RG_CBasePlayer_Jump, "CBasePlayer_Jump_Pre", false));
}

EnableForwards() {
  for(new i; i < sizeof hookChain; i++) {
    if(hookChain[i]) {
      EnableHookChain(hookChain[i]);
    }
  }
}

BuildMenu() {
  for(new i = 0; i < sizeof menuCmds; i++) {
    register_clcmd(menuCmds[i], "ShowMenu");
  }

  menuId = menu_create("\r[CSDM]\y Магазин", "menuIdHandler");
  menuId_Callback = menu_makecallback("menuIdCallback");

  new menuName[64], menuKey[sizeof menuData];

  for(new i = 0; i < sizeof menuData; i++) {
    if(menuData[i][MENU_PRICE] < 1) continue;
    num_to_str(i, menuKey, charsmax(menuKey));
    formatex(menuName, charsmax(menuName), "%s \r[%d$]\w",  menuData[i][MENU_NAME], menuData[i][MENU_PRICE]);
    menu_additem(menuId, menuName, menuKey, menuData[i][MENU_FLAG], menuId_Callback);
  }

  menu_setprop(menuId, MPROP_NEXTNAME, "Вперед")
  menu_setprop(menuId, MPROP_BACKNAME, "Назад")
  menu_setprop(menuId, MPROP_EXITNAME, "Выход")
  menu_setprop(menuId, MPROP_PERPAGE, 7);
  menu_setprop(menuId, MPROP_EXIT, MEXIT_ALL);
  menu_setprop(menuId, MPROP_NUMBER_COLOR, "\w");
}

public menuIdCallback(id, menu, item) {
  if(item < 0) {
    return PLUGIN_HANDLED;
  }

  new key[sizeof menuData], name[64], access, callback;
  menu_item_getinfo(menu, item, access, key, sizeof key, name, sizeof name - 1, callback);

  new playerMoney = get_member(id, m_iAccount);
  new menuPrice = menuData[str_to_num(key)][MENU_PRICE];

  new menuNewItemName[64];

  // menu_item_setname меняет название пункта навсегда, поэтому надо возвращать по дефолту вот так:
  formatex(menuNewItemName, charsmax(menuNewItemName), "%s \r[%d$]\w",  menuData[item][MENU_NAME], menuData[item][MENU_PRICE]);
  menu_item_setname(menu, item, menuNewItemName);
  // а потом уже отображать состояние пунктов:

  if(pActiveServices[id][item]) {
    formatex(menuNewItemName, charsmax(menuNewItemName), "%s \r[\yактивировано\r]\w",  menuData[item][MENU_NAME]);
    menu_item_setname(menu, item, menuNewItemName);
    return ITEM_DISABLED;
  }

  if(playerMoney < menuPrice) {
    return ITEM_DISABLED;
  }
  
  return ITEM_IGNORE;
}

public menuIdHandler(id, menu, item) {
  if(!is_user_alive(id)) {
    return PLUGIN_HANDLED;
  }

  if(item == MENU_EXIT || item < 0) {
    return PLUGIN_HANDLED;
  }

  new key[sizeof menuData], name[64], access, callback;
  menu_item_getinfo(menu, item, access, key, sizeof key, name, sizeof name - 1, callback);

  rg_add_account(id, -menuData[item][MENU_PRICE], AS_ADD);

  GiveItem(id, item);

  client_print_color(id, print_team_default, "^4Ты купил ^3%s^4!", menuData[item][MENU_NAME]);

  return PLUGIN_HANDLED;
}

public ShowMenu(id) {
  if(!is_user_alive(id)) {
    return PLUGIN_HANDLED;
  }
  return menu_display(id, menuId, 0);
}

GiveItem(id, key) {
  if(!is_user_alive(id)) {
    return PLUGIN_HANDLED;
  }

  if(key < 0) {
    return PLUGIN_HANDLED;
  }

  switch(key) {
    case 0: {
      // Тихий шаг
      rg_set_user_footsteps(id, true);
    }
    case 1: {
      // Банни-хоп
    }
    case 2: {
      // Быстрый бег
      set_entvar(id, var_maxspeed, 400.0);
    }
    case 3: {
      // Гравитация
      set_entvar(id, var_gravity, 0.5);
    }
    case 4: {
      // 150 HP + 150 AP
      set_entvar(id, var_health, 150.0);
      rg_set_user_armor(id, 150, ARMOR_VESTHELM);
    }
    case 5: {
      // Двойной прыжок
    }
    case 6: {
      // Полупрозрачность
      set_user_rendering(id, kRenderFxNone, 0, 0, 0, kRenderTransAlpha, 50);
    }
    case 7: {
      // Вампиризм
    }
    case 8: {
      // Автоперезаряд
    }
    case 9: {
      // RPG-7
      GiveRPG7(id);
    }
    default: {
      return PLUGIN_HANDLED;
    }
  }

  pActiveServices[id][key] = true;

  return PLUGIN_HANDLED;
}