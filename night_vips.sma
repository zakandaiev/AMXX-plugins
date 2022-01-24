#include <amxmodx>
#include <reapi>

#define AUTO_CFG // автоматическое создание конфига с кварами
// #define FORCE_FLAGS // раскомментируйте если есть проблемы с совместимостью с другими плагинами - принудительно выдавать флаги игрокам перед началом нового раунда

enum any:CVARS {
	TIME[12],
	TIME_START,
	TIME_END,
	FLAGS[32],
	FLAGS_BIT,
	AWARD_BOTS,
	ALERT[192],
	ALERT_OFF[192],
	ALERT_COLOR[12],
	ALERT_COLOR_R,
	ALERT_COLOR_G,
	ALERT_COLOR_B,
	ALERT_COORDS[32],
	Float:ALERT_COORDS_X,
	Float:ALERT_COORDS_Y,
	ALERT_SOUND[64],
	GAMENAME[32],
	PAUSE_PLUGINS[512]
};

enum bool:PLAYER_DATA {
	HAS_INIT_FLAGS,
	IS_AWARDED,
	IS_ALERT_SHOWED
};

enum any:GAME_DATA {
	bool:IS_NIGHT,
	GAMENAME_OLD[32],
	bool:IS_GAMENAME_CHANGED,
	bool:IS_PAUSE_PLUGINS
};

new cvar[CVARS], player[MAX_CLIENTS + 1][PLAYER_DATA], game[GAME_DATA];

public plugin_init() {
	register_plugin("Night VIPs", "1.1.1", "szawesome");

	RegisterHookChain(RG_RoundEnd, "RG_RoundEnd_Post", true);
	if(strlen(cvar[ALERT]) || strlen(cvar[ALERT_OFF])) {
		RegisterHookChain(RG_CBasePlayer_OnSpawnEquip, "CBasePlayer_OnSpawnEquip_Post", true);
	}

	game[IS_GAMENAME_CHANGED] = false;
	game[IS_PAUSE_PLUGINS] = false;
}

public plugin_precache() {
	RegisterCvars();
	ValueCvars();
	CheckForNight();

	if(strlen(cvar[ALERT_SOUND])) {
		precache_sound(cvar[ALERT_SOUND]);
	}
}

public client_putinserver(id) {
	player[id][HAS_INIT_FLAGS] = false;
	player[id][IS_AWARDED] = false;
	player[id][IS_ALERT_SHOWED] = false;

	AwardPlayer(id);
}

public RG_RoundEnd_Post(WinStatus:status, ScenarioEventEndRound:event, Float:tmDelay) {
	CheckForNight();
	pause_plugins();
	change_gamename();
	for(new player = 1; player <= MaxClients; player++) {
		if(is_user_connected(player) && !is_user_hltv(player)) {
			AwardPlayer(player);
		}
	}
}

public CBasePlayer_OnSpawnEquip_Post(id, bool:addDefault, bool:equipGame) {
	if(is_user_alive(id) && !is_user_bot(id)
			&& (
					game[IS_NIGHT] && player[id][IS_AWARDED] && !player[id][IS_ALERT_SHOWED] // ночной режим активен, нужно оповестить неоповещенных игроков
					|| !game[IS_NIGHT] && !player[id][IS_AWARDED] && player[id][IS_ALERT_SHOWED] // ночной режим закончился, нужно оповестить награжденных игроков
				)
		) {
		screen_fade(id, cvar[ALERT_COLOR_R], cvar[ALERT_COLOR_G], cvar[ALERT_COLOR_B], 100, 1);
		set_dhudmessage(cvar[ALERT_COLOR_R], cvar[ALERT_COLOR_G], cvar[ALERT_COLOR_B], cvar[ALERT_COORDS_X], cvar[ALERT_COORDS_Y], 2, _, 5.0, 0.07);
		if(game[IS_NIGHT] && player[id][IS_AWARDED] && !player[id][IS_ALERT_SHOWED]) {
			show_dhudmessage(id, cvar[ALERT]);
			player[id][IS_ALERT_SHOWED] = true;
		} else if(!game[IS_NIGHT] && !player[id][IS_AWARDED] && player[id][IS_ALERT_SHOWED]) {
			show_dhudmessage(id, cvar[ALERT_OFF]);
			player[id][IS_ALERT_SHOWED] = false;
		}
		if(strlen(cvar[ALERT_SOUND])) {
			rg_send_audio(id, cvar[ALERT_SOUND]);
		}
	}
}

RegisterCvars() {
	bind_pcvar_string(
		create_cvar(
			.name = "night_vips_time", 
			.string = "22:00 6:00",
			.flags = FCVAR_NONE,
			.description = "Время начала и конца выдачи флагов. Формат времени: с по^nУказывается с точностью до минут через двоеточие"
		),
		cvar[TIME],
		charsmax(cvar[TIME])
	);
	bind_pcvar_string(
		create_cvar(
			.name = "night_vips_flags", 
			.string = "t",
			.flags = FCVAR_NONE,
			.description = "Выдаваемые флаги. Можно сочитать, например: bt"
		),
		cvar[FLAGS],
		charsmax(cvar[FLAGS])
	);
	bind_pcvar_num(
		create_cvar(
			.name = "night_vips_bots", 
			.string = "1",
			.flags = FCVAR_NONE,
			.description = "Выдавать флаги ботам?^n1 - выдавать^n0 - не выдавать",
			.has_min = true,
			.min_val = 0.0,
			.has_max = true,
			.max_val = 1.0
		),
		cvar[AWARD_BOTS]
	);
	bind_pcvar_string(
		create_cvar(
			.name = "night_vips_alert",
			.string = "Ночная VIP активирована\nЖелаем приятной игры",
			.flags = FCVAR_NONE,
			.description = "Выводить сообщение о активации привилегии?^nОставьте пустым чтобы не выводить^n\n - перенос строки"
		),
		cvar[ALERT],
		charsmax(cvar[ALERT])
	);
	bind_pcvar_string(
		create_cvar(
			.name = "night_vips_alert_off",
			.string = "Ночная VIP закончилась\nЖелаем приятной игры",
			.flags = FCVAR_NONE,
			.description = "Выводить сообщение о деактивации привилегии?^nОставьте пустым чтобы не выводить^n\n - перенос строки"
		),
		cvar[ALERT_OFF],
		charsmax(cvar[ALERT_OFF])
	);
	bind_pcvar_string(
		create_cvar(
			.name = "night_vips_alert_color",
			.string = "255 255 0",
			.flags = FCVAR_NONE,
			.description = "Цвет сообщения и затемнения экрана. Формат: R G B"
		),
		cvar[ALERT_COLOR],
		charsmax(cvar[ALERT_COLOR])
	);
	bind_pcvar_string(
		create_cvar(
			.name = "night_vips_alert_coords",
			.string = "-1.0 -0.29",
			.flags = FCVAR_NONE,
			.description = "Координаты сообщения. Формат: X Y^nУказывается % смещения разделённый на 100^n-1.0 - по центру"
		),
		cvar[ALERT_COORDS],
		charsmax(cvar[ALERT_COORDS])
	);
	bind_pcvar_string(
		create_cvar(
			.name = "night_vips_alert_sound",
			.string = "fvox/bell.wav",
			.flags = FCVAR_NONE,
			.description = "Воспроизводить звук при активации привилегии?^nОставьте пустым чтобы не воспроизводить^nЗвук должен лежать в папке sound"
		),
		cvar[ALERT_SOUND],
		charsmax(cvar[ALERT_SOUND])
	);
	bind_pcvar_string(
		create_cvar(
			.name = "night_vips_gamename",
			.string = "[Ночная VIP]",
			.flags = FCVAR_NONE,
			.description = "Менять описание игры в списке серверов в заданноe время?^nОставьте пустым чтобы не менять"
		),
		cvar[GAMENAME],
		charsmax(cvar[GAMENAME])
	);
	bind_pcvar_string(
		create_cvar(
			.name = "night_vips_pause_plugins",
			.string = "",
			.flags = FCVAR_NONE,
			.description = "Список плагинов, которые нужно ставить на паузу^nУказывать через пробел^nПример: ^"plugin_1.amxx plugin_2.amxx^""
		),
		cvar[PAUSE_PLUGINS],
		charsmax(cvar[PAUSE_PLUGINS])
	);
	#if defined AUTO_CFG
		AutoExecConfig();
	#endif
}

ValueCvars() {
	// TIME
	new time_start[6], time_end[6];
	parse(cvar[TIME], time_start, charsmax(time_start), time_end, charsmax(time_end));
	cvar[TIME_START] = get_int_time(time_start);
	cvar[TIME_END] = get_int_time(time_end);
	// FLAGS BITS
	cvar[FLAGS_BIT] = read_flags(cvar[FLAGS]);
	// FORMAT ALERT MESSAGE
	if(strlen(cvar[ALERT])) {
		replace_all(cvar[ALERT], charsmax(cvar[ALERT]), "\n", "^n");
	}
	if(strlen(cvar[ALERT_OFF])) {
		replace_all(cvar[ALERT_OFF], charsmax(cvar[ALERT_OFF]), "\n", "^n");
	}
	// PARSE COLORS
	new red[5], green[5], blue[5];
	parse(cvar[ALERT_COLOR], red, charsmax(red), green, charsmax(green), blue, charsmax(blue));
	cvar[ALERT_COLOR_R] = str_to_num(red);
	cvar[ALERT_COLOR_G] = str_to_num(green);
	cvar[ALERT_COLOR_B] = str_to_num(blue);
	// PARSE COORDS
	new coord_x[16], coord_y[16];
	parse(cvar[ALERT_COORDS], coord_x, charsmax(coord_x), coord_y, charsmax(coord_y));
	cvar[ALERT_COORDS_X] = str_to_float(coord_x);
	cvar[ALERT_COORDS_Y] = str_to_float(coord_y);
}

CheckForNight() {
	game[IS_NIGHT] = false;

	new hours, mins; time(hours, mins);
	new cur_time = hours * 60 + mins;

	if(cvar[TIME_START] <= cvar[TIME_END]) {
		if(cvar[TIME_START] <= cur_time <= cvar[TIME_END]) {
			game[IS_NIGHT] = true;
		}
	} else {
		if(cvar[TIME_START] <= cur_time <= 24 * 60 || cur_time <= cvar[TIME_END]) {
			game[IS_NIGHT] = true;
		}
	}
}

AwardPlayer(id) {
	if(!is_user_connected(id) || is_user_hltv(id)
		|| !cvar[FLAGS_BIT]
		|| (cvar[AWARD_BOTS] != 1 && is_user_bot(id))
	) {
		return false;
	}

	new pFlags = get_user_flags(id);

	if(!game[IS_NIGHT] && player[id][IS_AWARDED] && !player[id][HAS_INIT_FLAGS]) {
		remove_user_flags(id, cvar[FLAGS_BIT]);
		player[id][IS_AWARDED] = false;
		return true;
	}
	#if defined FORCE_FLAGS
	else if(!game[IS_NIGHT]) {
	#else
	else if(!game[IS_NIGHT] || player[id][IS_AWARDED]) {
	#endif
		return false;
	}

	if(pFlags & cvar[FLAGS_BIT] || pFlags & cvar[FLAGS_BIT] == cvar[FLAGS_BIT]) {
		player[id][HAS_INIT_FLAGS] = true;
		return false;
	}

	set_user_flags(id, pFlags | cvar[FLAGS_BIT]);

	player[id][IS_AWARDED] = true;

	return true;
}

stock screen_fade(id, red, green, blue, alfa, durration) {
	if(!is_user_connected(id) || is_user_bot(id)) {
		return;
	}

	if(bool:(Float:get_member(id, m_blindStartTime) + Float:get_member(id, m_blindFadeTime) >= get_gametime())) {
		return;
	}

	new dUnits = clamp((durration * (1 << 12)), 0, 0xFFFF);

	static userMessage_ScreenFade;
	if(userMessage_ScreenFade > 0 || (userMessage_ScreenFade = get_user_msgid("ScreenFade"))) {
		message_begin(MSG_ONE_UNRELIABLE, userMessage_ScreenFade, .player = id);
		write_short(dUnits);
		write_short(dUnits/2);
		write_short(0x0000);
		write_byte(red);
		write_byte(green);
		write_byte(blue);
		write_byte(alfa);
		message_end();
	}
}

stock get_int_time(string[]) {
	new left[4], right[4]; strtok(string, left, charsmax(left), right, charsmax(right), ':');
	return str_to_num(left) * 60 + str_to_num(right);
}

stock change_gamename() {
	if(!strlen(cvar[GAMENAME])) {
		return;
	}

	if(!game[IS_GAMENAME_CHANGED]) {
		get_member_game(m_GameDesc, game[GAMENAME_OLD], charsmax(game[GAMENAME_OLD]));
	}

	if(game[IS_NIGHT] && !game[IS_GAMENAME_CHANGED]) {
		set_member_game(m_GameDesc, cvar[GAMENAME]);
		game[IS_GAMENAME_CHANGED] = true;
	} else if(!game[IS_NIGHT] && game[IS_GAMENAME_CHANGED]) {
		set_member_game(m_GameDesc, game[GAMENAME_OLD]);
		game[IS_GAMENAME_CHANGED] = false;
	}
}

stock pause_plugins() {
	if(!strlen(cvar[PAUSE_PLUGINS])) {
		return;
	}

	new plugin_name[128], arg_pos, bool:updateGameState_isPausePlugins = false;
	while(arg_pos != -1) {
		arg_pos = argparse(cvar[PAUSE_PLUGINS], arg_pos, plugin_name, charsmax(plugin_name));
		if(arg_pos != -1) {
			if(is_plugin_loaded(plugin_name, true) != -1) {
				if(game[IS_NIGHT] && !game[IS_PAUSE_PLUGINS]) {
					pause("ac", plugin_name);
					updateGameState_isPausePlugins = true;
				} else if(!game[IS_NIGHT] && game[IS_PAUSE_PLUGINS]) {
					unpause("ac", plugin_name);
					updateGameState_isPausePlugins = false;
				}
			}
		}
	}

	if(updateGameState_isPausePlugins) {
		game[IS_PAUSE_PLUGINS] = true;
	} else {
		game[IS_PAUSE_PLUGINS] = false;
	}
}