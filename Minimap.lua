local addonName = ...
local SND = _G[addonName]

local LibDBIcon = LibStub("LibDBIcon-1.0", true)
local LibDataBroker = LibStub("LibDataBroker-1.1", true)

local LDB_OBJECT_NAME = "SomethingNeedDoing"

local function T(key, ...)
  if SND and SND.Tr then
    return SND:Tr(key, ...)
  end
  if select("#", ...) > 0 then
    return string.format(key, ...)
  end
  return key
end

local function ensureMinimapConfig(self)
  self.db.config = self.db.config or {}
  if self.db.config.showMinimapButton == nil then
    self.db.config.showMinimapButton = true
  end
  if self.db.config.minimapAngle == nil then
    self.db.config.minimapAngle = 220
  end
  if type(self.db.config.minimapIconDB) ~= "table" then
    self.db.config.minimapIconDB = {}
  end
  if self.db.config.minimapIconDB.minimapPos == nil then
    self.db.config.minimapIconDB.minimapPos = self.db.config.minimapAngle
  end
  if self.db.config.minimapIconDB.hide == nil then
    self.db.config.minimapIconDB.hide = not (self.db.config.showMinimapButton and true or false)
  end
end

local function syncLegacyToLibDBIcon(self)
  ensureMinimapConfig(self)
  self.minimapIconDB = self.db.config.minimapIconDB
  self.minimapIconDB.minimapPos = tonumber(self.minimapIconDB.minimapPos) or tonumber(self.db.config.minimapAngle) or 220
  self.minimapIconDB.hide = not (self.db.config.showMinimapButton and true or false)
end

local function syncLibDBIconToLegacy(self)
  ensureMinimapConfig(self)
  self.minimapIconDB = self.db.config.minimapIconDB
  self.db.config = self.db.config or {}
  if self.minimapIconDB.minimapPos ~= nil then
    self.db.config.minimapAngle = tonumber(self.minimapIconDB.minimapPos) or self.db.config.minimapAngle
  end
  if self.minimapIconDB.hide ~= nil then
    self.db.config.showMinimapButton = not self.minimapIconDB.hide
  end
end

local function ensureDataBroker(self)
  if self.ldbObject then
    return self.ldbObject
  end
  if not LibDataBroker then
    return nil
  end

  local object = LibDataBroker:NewDataObject(LDB_OBJECT_NAME, {
    type = "launcher",
    text = T("Something Need Doing"),
    icon = "Interface/Icons/INV_Misc_Gear_01",
    OnClick = function()
      self:ToggleMainWindow()
    end,
    OnTooltipShow = function(tooltip)
      if not tooltip or not tooltip.AddLine then
        return
      end
      tooltip:AddLine(T("Something Need Doing"))
      tooltip:AddLine(T("Click: Toggle main window"), 1, 1, 1)
      tooltip:AddLine(T("/snd config: Open options"), 1, 1, 1)
    end,
  })

  self.ldbObject = object
  return object
end

function SND:InitMinimapButton()
  if self._minimapInitialized then
    return
  end
  self._minimapInitialized = true

  syncLegacyToLibDBIcon(self)

  local object = ensureDataBroker(self)
  if LibDBIcon and object then
    if not LibDBIcon:IsRegistered(LDB_OBJECT_NAME) then
      LibDBIcon:Register(LDB_OBJECT_NAME, object, self.minimapIconDB)
    end
    LibDBIcon:Refresh(LDB_OBJECT_NAME, self.minimapIconDB)
    syncLibDBIconToLegacy(self)
  end

  self:UpdateMinimapButtonVisibility()
  self:UpdateMinimapButtonPosition()
end

function SND:UpdateMinimapButtonVisibility()
  if not LibDBIcon then
    return
  end
  syncLegacyToLibDBIcon(self)
  if self.db.config.showMinimapButton then
    self.minimapIconDB.hide = false
    LibDBIcon:Show(LDB_OBJECT_NAME)
  else
    self.minimapIconDB.hide = true
    LibDBIcon:Hide(LDB_OBJECT_NAME)
  end
  syncLibDBIconToLegacy(self)
end

function SND:UpdateMinimapButtonPosition()
  if not LibDBIcon then
    return
  end
  syncLegacyToLibDBIcon(self)
  LibDBIcon:Refresh(LDB_OBJECT_NAME, self.minimapIconDB)
  syncLibDBIconToLegacy(self)
end
