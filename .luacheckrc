std = "lua51"
max_line_length = false

exclude_files = {
  "libs/",
  "dist/",
}

globals = {
  "SomethingNeedDoing",
  "SomethingNeedDoingDB",
}

read_globals = {
  -- Lua globals added by WoW
  "wipe",
  "date",
  "time",
  "strsplit",
  "strtrim",
  "tinsert",
  "tremove",
  "format",

  -- WoW API
  "CreateFrame",
  "GetAddOnMetadata",
  "GetGuildInfo",
  "GetGuildRosterInfo",
  "GetNumGuildMembers",
  "GetItemInfo",
  "GetItemIcon",
  "GetProfessions",
  "GetProfessionInfo",
  "GetRealmName",
  "GetServerTime",
  "GetSpellLink",
  "IsInGuild",
  "UnitFactionGroup",
  "UnitIsGuildLeader",
  "UnitName",
  "ChatFrame_OpenChat",
  "ChatFrame_SendTell",

  -- C_ namespaces
  "C_AddOns",
  "C_GuildInfo",
  "C_Timer",
  "C_TradeSkillUI",

  -- UI globals
  "UIParent",
  "GameTooltip",
  "DEFAULT_CHAT_FRAME",
  "BackdropTemplateMixin",
  "ITEM_QUALITY_COLORS",

  -- Templates (used as inherits in CreateFrame)
  "BackdropTemplate",

  -- Libraries
  "LibStub",

  -- Addon loader
  "_G",
}

-- Ignore unused self in methods (common in Ace3 callbacks)
self = false
