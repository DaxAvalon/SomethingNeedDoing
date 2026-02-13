--[[
================================================================================
RecipeData Module
================================================================================
Resolves recipe output item data from multiple sources with intelligent fallback.

Purpose:
  - Retrieve item names, links, icons, and IDs for recipes
  - Handle missing/pending data gracefully with async loading
  - Maintain multiple fallback sources for reliability
  - Cache results to minimize WoW API calls

Data Sources (Priority Order):
  1. Explicit context data (passed by caller)
  2. WoW API direct calls (GetItemInfo, GetItemIcon)
  3. RecipeIndex cached data (from database)
  4. ItemCache warm loading (async)
  5. TradeSkillUI API (C_TradeSkillUI.GetRecipeSchematic)

Normalization:
  - Filters out generic strings like "Item 12345"
  - Removes recipe table/userdata references
  - Handles nil values gracefully
  - Returns pending status for async-loading items

Key Functions:
  - GetRecipeOutputItemName() - Get item name with cache/API fallback
  - GetRecipeOutputItemLink() - Get clickable item link (cached)
  - GetRecipeOutputItemID() - Get item ID from recipe
  - GetRecipeOutputItemIcon() - Get item icon texture
  - ResolveRecipeDisplayData() - Comprehensive data resolution
  - ResolveReadableItemDisplay() - Simplified wrapper for UI display

Dependencies:
  - Requires: ItemCache.lua (WarmItemCache, GetCachedItemInfo), DB.lua (recipeIndex), Utils.lua (Now, NormalizeRecipeSpellID)
  - Used by: DirectoryUI.lua, RequestUI.lua, RecipeSearch.lua

Author: SND Team
Last Modified: 2026-02-13
================================================================================
]]--

local addonName = ...
local SND = _G[addonName]

-- ============================================================================
-- Helper Functions
-- ============================================================================

--[[
  normalizeItemIDValue - Validate and normalize item ID

  Purpose:
    Ensures item IDs are valid positive integers.

  Parameters:
    @param value (any) - Value to normalize (usually number or string)

  Returns:
    @return (number|nil) - Normalized item ID or nil if invalid
]]--
local function normalizeItemIDValue(value)
  local n = tonumber(value)
  if not n then
    return nil
  end
  n = math.floor(n)
  if n <= 0 then
    return nil
  end
  return n
end

--[[
  normalizeDisplayText - Clean and validate display text

  Purpose:
    Filters out generic/invalid text that shouldn't be displayed to users.
    Removes debugging strings like "Item 12345", "table: 0x...", etc.

  Invalid Patterns:
    - Pure numbers
    - "item:12345" format
    - "Item 12345" format
    - "Recipe 12345" format
    - Table/userdata references
    - Empty or whitespace-only strings

  Parameters:
    @param text (string) - Text to normalize

  Returns:
    @return (string|nil) - Normalized text or nil if invalid
]]--
local function normalizeDisplayText(text)
  if type(text) ~= "string" then
    return nil
  end

  -- Trim whitespace
  local trimmed = text:gsub("^%s+", ""):gsub("%s+$", "")
  if trimmed == "" then
    return nil
  end

  -- Filter out invalid patterns
  if trimmed:match("^%d+$") then
    return nil
  end
  if trimmed:match("^item:%d+$") then
    return nil
  end
  if trimmed:match("^Item%s+%d+$") then
    return nil
  end
  if trimmed:match("^Recipe%s+%d+$") then
    return nil
  end
  if trimmed:match("^Recipe%s+table:%s*0?x?[%x]+$") then
    return nil
  end
  if trimmed:match("^Recipe%s+userdata:%s*0?x?[%x]+$") then
    return nil
  end
  if trimmed:match("^table:%s*0?x?[%x]+$") then
    return nil
  end
  if trimmed:match("^userdata:%s*0?x?[%x]+$") then
    return nil
  end

  return trimmed
end

-- ============================================================================
-- Recipe Output Data Functions
-- ============================================================================

--[[
  GetRecipeOutputItemName - Get the output item name for a recipe

  Purpose:
    Retrieves the item name produced by a recipe, with multi-source fallback
    and async loading support.

  Fallback Chain:
    1. RecipeIndex cached name (fastest)
    2. ItemCache (if item is cached)
    3. Direct GetItemInfo() call
    4. Queue for async loading via WarmItemCache()

  Parameters:
    @param recipeSpellID (number) - Recipe spell ID

  Returns:
    @return (string|nil) - Item name or nil if pending/unavailable

  Side Effects:
    - May queue item for async loading
    - Updates self.db.recipeIndex when data becomes available
    - Sets itemDataStatus in recipe entry
]]--
function SND:GetRecipeOutputItemName(recipeSpellID)
  recipeSpellID = self:NormalizeRecipeSpellID(recipeSpellID)
  if not recipeSpellID then
    return nil
  end

  -- Check recipeIndex for cached name (fastest path)
  local entry = self.db.recipeIndex[recipeSpellID]
  if entry and entry.itemName then
    return entry.itemName
  end

  -- Get item ID
  local itemID = self:GetRecipeOutputItemID(recipeSpellID)
  if not itemID then
    return nil
  end

  -- Try to get from item cache
  local cachedInfo = self:GetCachedItemInfo(itemID)
  if cachedInfo then
    if cachedInfo.name then
      -- Cache hit - store in recipeIndex for future use
      if entry then
        entry.itemName = cachedInfo.name
        entry.itemDataStatus = "cached"
      end
      return cachedInfo.name
    elseif cachedInfo.isPending then
      -- Item is currently loading asynchronously
      return nil
    end
  end

  -- Try direct API call (may succeed if item was recently loaded)
  local name = GetItemInfo(itemID)
  if name then
    -- Success - cache it in recipeIndex
    if entry then
      entry.itemName = name
      entry.itemDataStatus = "cached"
    end
    return name
  end

  -- Failed - queue for warming (async loading)
  self:WarmItemCache({itemID}, recipeSpellID, function()
    -- Update recipeIndex when item data becomes available
    local retryName = GetItemInfo(itemID)
    if retryName and entry then
      entry.itemName = retryName
      entry.itemDataStatus = "cached"
      entry.lastUpdated = self:Now()
    end
  end)

  -- Mark as pending so UI knows it's loading
  if entry then
    entry.itemDataStatus = "pending"
  end

  return nil
end

--[[
  GetRecipeOutputItemLink - Get the clickable item link for a recipe

  Purpose:
    Retrieves the clickable item link (for chat/tooltips) for a recipe's output item.
    Results are cached in memory for performance.

  Parameters:
    @param recipeSpellID (number) - Recipe spell ID

  Returns:
    @return (string|nil) - Item link or nil if unavailable

  Side Effects:
    - Caches result in self.outputLinkCache
]]--
function SND:GetRecipeOutputItemLink(recipeSpellID)
  recipeSpellID = self:NormalizeRecipeSpellID(recipeSpellID)
  if not recipeSpellID then
    return nil
  end

  -- Check link cache (in-memory only, not persisted)
  self.outputLinkCache = self.outputLinkCache or {}
  if self.outputLinkCache[recipeSpellID] then
    return self.outputLinkCache[recipeSpellID]
  end

  -- Get item ID and fetch link
  local itemID = self:GetRecipeOutputItemID(recipeSpellID)
  if not itemID then
    return nil
  end

  local _, link = GetItemInfo(itemID)
  self.outputLinkCache[recipeSpellID] = link
  return link
end

--[[
  GetRecipeOutputItemID - Get the output item ID for a recipe

  Purpose:
    Retrieves the item ID produced by a recipe, with fallback to WoW's TradeSkillUI API.

  Fallback Chain:
    1. RecipeIndex cached itemID (fastest)
    2. C_TradeSkillUI.GetRecipeSchematic() call (if available)

  Parameters:
    @param recipeSpellID (number) - Recipe spell ID

  Returns:
    @return (number|nil) - Item ID or nil if unavailable

  Side Effects:
    - Updates self.db.recipeIndex with outputItemID if found via API
]]--
function SND:GetRecipeOutputItemID(recipeSpellID)
  recipeSpellID = self:NormalizeRecipeSpellID(recipeSpellID)
  if not recipeSpellID then
    return nil
  end

  -- Check recipeIndex for cached item ID
  local entry = self.db.recipeIndex[recipeSpellID]
  if entry and entry.outputItemID then
    return entry.outputItemID
  end

  -- Fallback to TradeSkillUI API (if available in this WoW version)
  if not C_TradeSkillUI or not C_TradeSkillUI.GetRecipeSchematic then
    return entry and entry.outputItemID or nil
  end

  local schematic = C_TradeSkillUI.GetRecipeSchematic(recipeSpellID, false)
  if not schematic or not schematic.outputItemID then
    return nil
  end

  -- Cache the result in recipeIndex
  if entry then
    entry.outputItemID = schematic.outputItemID
    entry.lastUpdated = self:Now()
  end

  return schematic.outputItemID
end

--[[
  GetRecipeOutputItemIcon - Get the item icon texture for a recipe

  Purpose:
    Retrieves the icon texture path for a recipe's output item, with async loading support.

  Fallback Chain:
    1. RecipeIndex cached icon (fastest)
    2. ItemCache (if item is cached)
    3. Direct GetItemIcon() call
    4. Queue for async loading via WarmItemCache()

  Parameters:
    @param recipeSpellID (number) - Recipe spell ID

  Returns:
    @return (string|nil) - Icon texture path or nil if pending/unavailable

  Side Effects:
    - May queue item for async loading
    - Updates self.db.recipeIndex when data becomes available
]]--
function SND:GetRecipeOutputItemIcon(recipeSpellID)
  recipeSpellID = self:NormalizeRecipeSpellID(recipeSpellID)
  if not recipeSpellID then
    return nil
  end

  -- Check recipeIndex for cached icon
  local entry = self.db.recipeIndex[recipeSpellID]
  if entry and entry.itemIcon then
    return entry.itemIcon
  end

  -- Get item ID
  local itemID = self:GetRecipeOutputItemID(recipeSpellID)
  if not itemID then
    return nil
  end

  -- Try to get from item cache
  local cachedInfo = self:GetCachedItemInfo(itemID)
  if cachedInfo and cachedInfo.icon then
    if entry then
      entry.itemIcon = cachedInfo.icon
      entry.itemDataStatus = "cached"
    end
    return cachedInfo.icon
  end

  -- Try direct API call
  local icon = GetItemIcon(itemID)
  if icon then
    if entry then
      entry.itemIcon = icon
      entry.itemDataStatus = "cached"
    end
    return icon
  end

  -- Failed - queue for warming (async loading)
  self:WarmItemCache({itemID}, recipeSpellID, function()
    local retryIcon = GetItemIcon(itemID)
    if retryIcon and entry then
      entry.itemIcon = retryIcon
      entry.itemDataStatus = "cached"
      entry.lastUpdated = self:Now()
    end
  end)

  if entry then
    entry.itemDataStatus = "pending"
  end

  return nil
end

-- ============================================================================
-- Comprehensive Data Resolution
-- ============================================================================

--[[
  ResolveRecipeDisplayData - Comprehensive recipe display data resolution

  Purpose:
    Resolves all display data for a recipe from multiple sources with intelligent
    fallback. This is the primary function for getting complete recipe display info.

  Data Sources (Priority Order):
    1. Explicit context (passed by caller)
    2. Function calls (GetRecipeOutput* methods)
    3. Database recipeIndex
    4. WoW API direct calls

  Parameters:
    @param recipeSpellID (number) - Recipe spell ID
    @param prefill (table|nil) - Optional context data:
      - itemID (number) - Explicit item ID
      - itemLink (string) - Explicit item link
      - itemText (string) - Explicit item text

  Returns:
    @return (table) - Resolved data:
      - recipeSpellID (number) - Normalized recipe ID
      - itemID (number|nil) - Output item ID
      - itemLink (string|nil) - Clickable item link
      - itemText (string) - Display text (link > name > fallback)
      - icon (string|nil) - Icon texture path
      - itemDataStatus (string) - Status: "cached", "pending", "unknown"

  Algorithm:
    1. Normalize recipe spell ID
    2. Extract explicit context values
    3. Fetch data from various sources
    4. Apply priority fallbacks for each field
    5. Generate fallback text if nothing available
    6. Return comprehensive data table
]]--
function SND:ResolveRecipeDisplayData(recipeSpellID, prefill)
  local normalizedRecipeSpellID = self:NormalizeRecipeSpellID(recipeSpellID)
  local context = type(prefill) == "table" and prefill or {}
  local recipe = normalizedRecipeSpellID and self.db and self.db.recipeIndex and self.db.recipeIndex[normalizedRecipeSpellID] or nil

  -- Extract and normalize explicit context values
  local explicitItemID = normalizeItemIDValue(context.itemID)
  local explicitItemLink = normalizeDisplayText(context.itemLink)
  local explicitItemText = normalizeDisplayText(context.itemText)

  -- Try to get link/text from explicit item ID
  local explicitItemIDLink = explicitItemID and select(2, GetItemInfo(explicitItemID)) or nil
  explicitItemIDLink = normalizeDisplayText(explicitItemIDLink)
  local explicitItemIDText = explicitItemID and normalizeDisplayText(GetItemInfo(explicitItemID)) or nil

  -- Get data from recipe output functions
  local recipeOutputItemID = normalizedRecipeSpellID and normalizeItemIDValue(self:GetRecipeOutputItemID(normalizedRecipeSpellID)) or nil
  local recipeOutputItemLink = normalizedRecipeSpellID and normalizeDisplayText(self:GetRecipeOutputItemLink(normalizedRecipeSpellID)) or nil
  local recipeOutputItemText = normalizedRecipeSpellID and normalizeDisplayText(self:GetRecipeOutputItemName(normalizedRecipeSpellID)) or nil

  -- Get data from database recipeIndex
  local dbOutputItemID = normalizeItemIDValue(recipe and recipe.outputItemID)
  local dbOutputItemLink = normalizeDisplayText(recipe and recipe.outputItemLink)
  local dbOutputItemText = normalizeDisplayText(recipe and (recipe.outputItemName or recipe.outputName))

  -- Apply priority fallbacks
  local itemID = explicitItemID or recipeOutputItemID or dbOutputItemID
  local itemLink = explicitItemLink or explicitItemIDLink or recipeOutputItemLink or dbOutputItemLink
  local itemText = explicitItemText

  -- Try to resolve link from item ID if not already found
  if not itemLink and itemID then
    local _, resolvedLink = GetItemInfo(itemID)
    itemLink = normalizeDisplayText(resolvedLink)
  end

  -- Prefer link over text for display
  if itemLink then
    itemText = itemLink
  end

  -- Fallback chain for itemText
  if not itemText then
    itemText = explicitItemIDText
  end
  if not itemText then
    itemText = recipeOutputItemText
  end
  if not itemText then
    itemText = dbOutputItemText
  end
  if not itemText and itemID then
    itemText = normalizeDisplayText(GetItemInfo(itemID))
  end
  if not itemText and normalizedRecipeSpellID then
    itemText = "Recipe #" .. tostring(normalizedRecipeSpellID)
  end
  if not itemText then
    itemText = "-"
  end

  -- Get icon
  local icon = nil
  if itemID then
    icon = GetItemIcon(itemID)
  end
  if not icon and normalizedRecipeSpellID then
    icon = self:GetRecipeOutputItemIcon(normalizedRecipeSpellID)
  end

  -- Get item data status
  local entry = self.db.recipeIndex[normalizedRecipeSpellID]
  local itemDataStatus = entry and entry.itemDataStatus or "unknown"

  return {
    recipeSpellID = normalizedRecipeSpellID,
    itemID = itemID,
    itemLink = itemLink,
    itemText = itemText,
    icon = icon,
    itemDataStatus = itemDataStatus,  -- "cached", "pending", "unknown"
  }
end

--[[
  ResolveReadableItemDisplay - Simplified wrapper for UI display

  Purpose:
    Convenience function that returns just the link and text for displaying
    in UI elements.

  Parameters:
    @param recipeSpellID (number) - Recipe spell ID
    @param context (table|nil) - Optional context data (see ResolveRecipeDisplayData)

  Returns:
    @return (string|nil, string) - Item link (if available) and display text

  Example:
    local link, text = self:ResolveReadableItemDisplay(recipeSpellID)
    frame.label:SetText(text)
]]--
function SND:ResolveReadableItemDisplay(recipeSpellID, context)
  local resolved = self:ResolveRecipeDisplayData(recipeSpellID, context)
  if not resolved then
    return nil, "-"
  end
  return resolved.itemLink, resolved.itemText
end
