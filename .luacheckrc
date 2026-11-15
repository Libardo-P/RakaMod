std = "lua51"
max_line_length = false
codes = true
-- Unused arguments are normal in WoW script/event callbacks.
ignore = { "212" }
exclude_files = { "Libs/**" }

-- WoW API surface used by the addon is declared as read globals by name.
-- Anything not listed here (typos, leaked globals) is reported.
globals = {
  "RakaMod", "RakaModDB", "SlashCmdList", "UISpecialFrames",
  "SLASH_RAKAMOD1", "SLASH_RAKAMOD2", "SLASH_RAKAMOD3",
}

read_globals = {
  "BackdropTemplateMixin", "CreateFrame", "UIParent", "C_AddOns", "C_Timer", "C_Spell",
  "GetAddOnMetadata", "GetBuildInfo", "GetTime", "GetRealmName", "GetLocale",
  "InCombatLockdown", "RequestTimePlayed", "LibStub", "CreateColor", "Mixin",
  "hooksecurefunc", "issecretvalue", "issecurevariable", "wipe", "tinsert", "tremove",
  "strsplit", "strtrim", "strjoin", "format", "date", "time", "floor", "ceil", "max", "min",
  "UnitName", "UnitClass", "UnitLevel", "UnitRace", "UnitHealth", "UnitHealthMax", "UnitGUID",
  "UnitIsAFK", "UnitIsDead", "UnitIsConnected", "UnitIsTapDenied", "UnitIsPlayer", "UnitExists",
  "UnitReaction", "UnitCanAttack", "UnitIsEnemy", "UnitIsFriend", "UnitGetTotalAbsorbs",
  "UnitAffectingCombat", "UnitIsUnit", "UnitIsGroupLeader", "UnitPower", "UnitPowerMax",
  "UnitFactionGroup", "UnitSex", "UnitIsVisible", "UnitClassBase", "UnitGroupRolesAssigned",
  "GetCurrentTitle", "GetTitleName", "GetSpecialization", "GetSpecializationInfo", "C_SpecializationInfo", "GetPrimaryTalentTree", "GetNumTalentTabs", "GetTalentTabInfo", "GetNumSpecializations", "GetActiveSpecGroup", "GetActiveTalentGroup", "GetNumTalents", "GetNumTalentGroups", "GetNumGroupMembers", "IsInRaid", "IsInGroup",
  "GetCVar", "SetCVar", "GetCursorPosition", "GetScreenWidth", "GetScreenHeight",
  "RegisterStateDriver", "UnregisterStateDriver", "RAID_CLASS_COLORS", "CLASS_ICON_TCOORDS",
  "LOCALIZED_CLASS_NAMES_MALE", "LOCALIZED_CLASS_NAMES_FEMALE", "FACTION_BAR_COLORS",
  "PowerBarColor", "TIME_PLAYED_MSG", "ChatFrame1", "DEFAULT_CHAT_FRAME", "ChatFrame_AddMessageEventFilter",
  "SendChatMessage", "DoEmote", "MoveViewLeftStart", "MoveViewLeftStop", "PlaySound", "PlaySoundFile",
  "GameMenuFrame", "ColorPickerFrame", "Settings", "InterfaceOptions_AddCategory", "InterfaceOptionsFrame_OpenToCategory",
  "GameTooltip", "MinimapCluster", "Minimap", "EllesmereUI", "EllesmereUIDB", "Ellesmere",
  "GameFontNormal", "GameFontNormalLarge", "GameFontHighlight", "GameFontHighlightSmall", "GameFontDisable",
  "STANDARD_TEXT_FONT", "UNKNOWN", "PlayerFrame", "TargetFrame", "FocusFrame", "PetFrame",
  "BNGetNumFriends", "C_BattleNet", "C_PartyInfo", "LFGDungeonReadyPopup", "PVEFrame",
  "QueueStatusButton", "CinematicFrame", "MovieFrame", "SpellBookFrame", "C_ClassTalents",
  "CollectionsJournal", "C_PetJournal", "C_MountJournal", "C_ToyBox", "C_TransmogCollection",
  "GetNumSkillLines", "GetProfessions", "GetProfessionInfo", "C_TradeSkillUI", "C_Timer",
  "ToggleDropDownMenu", "UIDropDownMenu_Initialize", "PlayerModel",
  "WorldFrame", "AnimateTexCoords", "CopyTable", "CreateFromMixins", "Enum", "tContains",
  "IsShiftKeyDown", "IsControlKeyDown", "IsAltKeyDown", "IsLoggedIn", "ReloadUI",
  "GetNumClasses", "GetClassInfo", "GetSpecialization", "GetSpecializationInfo", "GetSpecializationInfoForClassID",
  "GetServerTime", "GetGameTime", "SecondsToTime", "GetGuildInfo", "GetNormalizedRealmName",
  "C_Item", "C_CurrencyInfo", "C_QuestLog", "C_EncounterJournal", "C_PlayerInfo", "C_CVar",
  "C_Map", "C_ChatInfo", "C_FriendList", "C_Club", "C_GuildInfo", "C_LFGList", "C_PvP", "C_Housing",
  "SettingsPanel", "UnitChannelInfo", "UnitCastingInfo", "UnitIsTappedByPlayer", "UnitIsTapped", "LoadAddOn",
  "HideUIPanel", "GetTotalAchievementPoints", "EllesmereUIUnitFrames_Player", "EllesmereUIUnitFrames_Pet",
  "canaccessvalue", "UnitIsDeadOrGhost", "Screenshot", "GetBattlefieldStatus", "CloseAllWindows",
  "NUM_CHAT_WINDOWS", "NamePlateDriverFrame", "C_NamePlate", "CastingBarFrame", "PlayerCastingBarFrame", "TargetFrameSpellBar",
}

files["tests/"] = {
  -- Tests replace WoW globals with fakes and reuse short local names.
  ignore = { "121", "143", "211", "212", "241", "411", "421", "431" },
}
