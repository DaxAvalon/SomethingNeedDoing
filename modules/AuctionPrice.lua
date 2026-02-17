local addonName = ...
local SND = _G[addonName]

-- Returns true if the Auctionator addon API is available
function SND:IsAuctionatorAvailable()
  if type(Atr_GetAuctionBuyout) == "function" then
    return true
  end
  if Auctionator and Auctionator.API and Auctionator.API.v1 then
    return true
  end
  return false
end

-- Returns true if the TSM API is available
function SND:IsTSMAvailable()
  return type(TSM_API) == "table" and type(TSM_API.GetCustomPriceValue) == "function"
end

-- Returns true if any supported price source is available (respects config)
function SND:IsAuctionPriceAvailable()
  local source = self.db and self.db.config and self.db.config.priceSource or "auto"

  if source == "none" then return false end
  if source == "auctionator" then return self:IsAuctionatorAvailable() end
  if source == "tsm" then return self:IsTSMAvailable() end

  -- auto: either one
  return self:IsAuctionatorAvailable() or self:IsTSMAvailable()
end

-- Get price from Auctionator (classic API first, then modern)
function SND:GetAuctionatorPrice(itemID)
  if type(Atr_GetAuctionBuyout) == "function" then
    local _, itemLink = GetItemInfo(itemID)
    if itemLink then
      local price = Atr_GetAuctionBuyout(itemLink)
      if price and price > 0 then
        return price
      end
    end
  end

  if Auctionator and Auctionator.API and Auctionator.API.v1 then
    local fn = Auctionator.API.v1.GetAuctionPriceByItemID
    if fn then
      local ok, price = pcall(fn, "SomethingNeedDoing", itemID)
      if ok and price and price > 0 then
        return price
      end
    end
  end

  return nil
end

-- Get price from TSM using DBMarket valuation
function SND:GetTSMPrice(itemID)
  if not self:IsTSMAvailable() then return nil end
  local itemString = "i:" .. itemID
  local price = TSM_API.GetCustomPriceValue("DBMarket", itemString)
  if price and price > 0 then
    return price
  end
  return nil
end

-- Get the auction house price for an item in copper (routes through config)
-- Returns nil if no price data is available
function SND:GetItemAuctionPrice(itemID)
  if not itemID then return nil end

  local source = self.db and self.db.config and self.db.config.priceSource or "auto"

  if source == "none" then return nil end
  if source == "auctionator" then return self:GetAuctionatorPrice(itemID) end
  if source == "tsm" then return self:GetTSMPrice(itemID) end

  -- auto: try Auctionator first, then TSM
  local price = self:GetAuctionatorPrice(itemID)
  if price then return price end
  return self:GetTSMPrice(itemID)
end

-- Calculate total material cost for a recipe
-- Returns { totalCost = number, itemCosts = {[itemID] = { unitPrice, totalPrice }}, incomplete = bool }
function SND:GetRecipeMaterialCost(recipeSpellID, qty)
  qty = qty or 1
  local reagents = self:GetRecipeReagents(recipeSpellID)
  if not reagents or not next(reagents) then
    return nil
  end

  local totalCost = 0
  local itemCosts = {}
  local incomplete = false

  for itemID, perCraftCount in pairs(reagents) do
    local unitPrice = self:GetItemAuctionPrice(itemID)
    local required = perCraftCount * qty
    if unitPrice then
      local total = unitPrice * required
      itemCosts[itemID] = { unitPrice = unitPrice, totalPrice = total }
      totalCost = totalCost + total
    else
      itemCosts[itemID] = { unitPrice = nil, totalPrice = nil }
      incomplete = true
    end
  end

  return {
    totalCost = totalCost,
    itemCosts = itemCosts,
    incomplete = incomplete,
  }
end

-- Get profit estimate for crafting a recipe
-- Returns { materialCost, outputValue, profit, incomplete } or nil
function SND:GetRecipeProfitEstimate(recipeSpellID, qty)
  qty = qty or 1
  local costData = self:GetRecipeMaterialCost(recipeSpellID, qty)
  if not costData then
    return nil
  end

  local outputItemID = self:GetRecipeOutputItemID(recipeSpellID)
  local outputValue = nil
  if outputItemID then
    local unitPrice = self:GetItemAuctionPrice(outputItemID)
    if unitPrice then
      outputValue = unitPrice * qty
    end
  end

  local profit = nil
  if outputValue and not costData.incomplete then
    profit = outputValue - costData.totalCost
  end

  return {
    materialCost = costData.totalCost,
    outputValue = outputValue,
    profit = profit,
    incomplete = costData.incomplete,
  }
end

-- Format a copper value as a colored gold/silver/copper string
-- Example: 12345 copper -> "1g 23s 45c"
function SND:FormatPrice(copper)
  if not copper or copper == 0 then
    return "0c"
  end

  copper = math.floor(copper + 0.5)
  local negative = copper < 0
  if negative then copper = -copper end

  local gold = math.floor(copper / 10000)
  local silver = math.floor((copper % 10000) / 100)
  local cop = copper % 100

  local parts = {}
  if gold > 0 then
    table.insert(parts, string.format("|cffFFD700%d|rg", gold))
  end
  if silver > 0 or gold > 0 then
    table.insert(parts, string.format("|cffC0C0C0%d|rs", silver))
  end
  if cop > 0 or (#parts == 0) then
    table.insert(parts, string.format("|cffB87333%d|rc", cop))
  end

  local result = table.concat(parts, " ")
  if negative then
    result = "-" .. result
  end
  return result
end
