local addonName = ...
local SND = _G[addonName]

function SND:GetPlayerKey(name, realm)
  if not name or name == "" then
    return nil
  end
  if realm and realm ~= "" then
    return name .. "-" .. realm
  end
  local inferredRealm = GetRealmName()
  return name .. "-" .. inferredRealm
end

function SND:Now()
  if GetServerTime then
    return GetServerTime()
  end
  return time()
end

function SND:HashString(input)
  local str = tostring(input or "")
  local hash = 5381
  for i = 1, #str do
    hash = (hash * 33 + str:byte(i)) % 4294967296
  end
  return string.format("%08x", hash)
end

function SND:DebugPrint(message)
  -- Only show debug messages when debug mode is enabled
  if not self:IsDebugModeEnabled() then
    return
  end
  self:DebugLog(message, true)
end

function SND:IsDebugModeEnabled()
  return self.db and self.db.config and self.db.config.debugMode and true or false
end

function SND:DebugOnlyLog(message)
  if not self:IsDebugModeEnabled() then
    return
  end
  self:DebugLog(message, true)
end

function SND:TraceScanLog(message)
  if not self:IsDebugModeEnabled() then
    return
  end
  if DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage("|cff9999ffSND TRACE|r " .. tostring(message))
  end
end

function SND:DebugLog(message, chatWhenDebugMode)
  self:EnsureScanLogBuffer()
  self:TraceScanLog(string.format("Trace: DebugLog emit message=%s chat=%s", tostring(message), tostring(chatWhenDebugMode)))
  self:AppendScanLog(message)
  if chatWhenDebugMode and not (self.db and self.db.config and self.db.config.debugMode) then
    self:TraceScanLog("Trace: DebugLog chat skipped debugMode=false")
    return
  end
  if DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffSND|r " .. tostring(message))
  end
end

function SND:EnsureScanLogBuffer()
  self.scanLogBuffer = self.scanLogBuffer or {}
  self.scanLogMaxLines = self.scanLogMaxLines or 200
end

function SND:RequestScanLogRefresh()
  if self._scanLogRefreshQueued then
    self:TraceScanLog("Trace: ScanLog refresh skipped (already queued)")
    return
  end
  self._scanLogRefreshQueued = true
  self:TraceScanLog("Trace: ScanLog refresh queued")
  self:ScheduleSNDTimer(0, function()
    self._scanLogRefreshQueued = false
    self:TraceScanLog("Trace: ScanLog refresh dispatch")
    if type(self.RefreshScanLogBox) == "function" then
      self:RefreshScanLogBox()
    end
  end)
end

function SND:AppendScanLog(message)
  if not message then
    return
  end
  self:EnsureScanLogBuffer()
  local timestamp = date("%H:%M:%S")
  local line = string.format("[%s] %s", timestamp, tostring(message))
  table.insert(self.scanLogBuffer, line)
  while #self.scanLogBuffer > self.scanLogMaxLines do
    table.remove(self.scanLogBuffer, 1)
  end
  self._scanLogPendingDirty = true
  self:TraceScanLog(string.format("Trace: ScanLog append lines=%d dirty=%s", #self.scanLogBuffer, tostring(self._scanLogPendingDirty)))
  self:PushScanLogLineToUI(line)
  self:RequestScanLogRefresh()
end

function SND:PushScanLogLineToUI(line)
  if not line then
    return false
  end

  local meFrame = self.meTabFrame or (self.mainFrame and self.mainFrame.contentFrames and self.mainFrame.contentFrames[4])
  local logFrame = meFrame and meFrame.scanLogMessageFrame
  if not logFrame or not logFrame.AddMessage then
    return false
  end

  if logFrame.SetMaxLines then
    logFrame:SetMaxLines(self.scanLogMaxLines or 200)
  end
  logFrame:AddMessage(tostring(line))
  if logFrame.ScrollToBottom then
    logFrame:ScrollToBottom()
  end
  return true
end

function SND:GetScanLogText()
  if not self.scanLogBuffer then
    self:TraceScanLog("Trace: ScanLog read lines=0 chars=0")
    return ""
  end
  local text = table.concat(self.scanLogBuffer, "\n")
  self:TraceScanLog(string.format("Trace: ScanLog read lines=%d chars=%d", #self.scanLogBuffer, #text))
  return text
end

function SND:ClearScanLogBuffer()
  self:EnsureScanLogBuffer()
  wipe(self.scanLogBuffer)
  self._scanLogPendingDirty = true
  self._lastScanLogUiKey = nil
  self:TraceScanLog("Trace: ScanLog clear")
  self:RequestScanLogRefresh()
end

function SND:GetAllProfessionOptions()
  return {
    "All",
    "Alchemy",
    "Blacksmithing",
    "Leatherworking",
    "Tailoring",
    "Enchanting",
    "Jewelcrafting",
    "Engineering",
    "Cooking",
    "First Aid",
  }
end

local SKILL_LINE_ID_TO_NAME = {
  [171] = "Alchemy",
  [164] = "Blacksmithing",
  [185] = "Cooking",
  [333] = "Enchanting",
  [202] = "Engineering",
  [129] = "First Aid",
  [356] = "Fishing",
  [182] = "Herbalism",
  [755] = "Jewelcrafting",
  [165] = "Leatherworking",
  [186] = "Mining",
  [393] = "Skinning",
  [197] = "Tailoring",
}

function SND:GetProfessionNameBySkillLineID(profKey)
  if type(profKey) == "number" then
    return SKILL_LINE_ID_TO_NAME[profKey]
  end
  return nil
end

function SND:ScheduleSNDTimer(delaySeconds, fn)
  local delay = tonumber(delaySeconds) or 0
  if self.ScheduleTimer then
    return self:ScheduleTimer(fn, delay)
  end
  return C_Timer.NewTimer(delay, fn)
end

function SND:ScheduleSNDRepeatingTimer(delaySeconds, fn)
  local delay = tonumber(delaySeconds) or 0
  if self.ScheduleRepeatingTimer then
    return self:ScheduleRepeatingTimer(fn, delay)
  end
  return C_Timer.NewTicker(delay, fn)
end

function SND:CancelSNDTimer(timerHandle)
  if not timerHandle then
    return false
  end
  if self.CancelTimer then
    local ok = self:CancelTimer(timerHandle)
    if ok then
      return true
    end
  end
  if type(timerHandle) == "table" and timerHandle.Cancel then
    timerHandle:Cancel()
    return true
  end
  return false
end

function SND:Debounce(key, delaySeconds, fn)
  self._debounceTimers = self._debounceTimers or {}
  if self._debounceTimers[key] then
    self:CancelSNDTimer(self._debounceTimers[key])
  end
  self._debounceTimers[key] = self:ScheduleSNDTimer(delaySeconds, fn)
end
