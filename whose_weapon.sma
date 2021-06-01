#include <amxmodx>
#include <reapi>

const UNQUEID = 32;

enum _:cwUid{
  _goldenDeagle = 2387,
  _goldenAwp,
  _goldenAk47,
  _goldenM4A1,
  _adminAk47,
  _adminM4A1,
  _rpg7 = 77777
};

public plugin_init() {
  register_plugin("Whose the weapon", "1.0", "szawesome");
  RegisterHookChain(RG_CBasePlayer_AddPlayerItem, "CBasePlayer_AddPlayerItem", .post = true);
}

public CBasePlayer_AddPlayerItem(pPlayer, pItem) {
  if (!GetHookChainReturn(ATYPE_INTEGER))
    return;

  new dontKnowWhat = get_entvar(pItem, var_iuser1);

  if(dontKnowWhat < UNQUEID) {
    set_entvar(pItem, var_iuser1, get_user_userid(pPlayer) + UNQUEID);
    return;
  }

  static szItemName[32];

  switch(get_entvar(pItem, var_impulse)) {
    case _goldenDeagle: szItemName = "Золотой Deagle";
    case _goldenAwp: szItemName = "Золотой AWP";
    case _goldenAk47: szItemName = "Золотой AK-47";
    case _goldenM4A1: szItemName = "Золотую M4A1";
    case _adminAk47: szItemName = "Императрица AK-47";
    case _adminM4A1: szItemName = "Чантико M4";
    case _rpg7: szItemName = "RPG-7";
    default: return;
  }

  static piId;
  piId = dontKnowWhat - UNQUEID;

  if(get_user_userid(pPlayer)==piId) {
    static szPreName[16];
    switch(get_entvar(pItem, var_impulse)) {
      case _goldenM4A1: szPreName = "свою";
      case _adminM4A1: szPreName = "свою";
      case _rpg7: szPreName = "своё";
      default: szPreName = "свой";
    }
    client_print_color(pPlayer, pPlayer, "Ты подобрал %s ^3%s", szPreName, szItemName);
    return;
  }

  for (new i = 1; i <= MAX_CLIENTS; i++) {
    if(get_user_userid(i)==piId && is_user_connected(i)) {
      client_print_color(pPlayer, i, "Ты подобрал ^3%s^1 игрока^3 %n", szItemName, i);
      return;
    }
  }
}