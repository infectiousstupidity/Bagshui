-- Bagshui Bags Inventory Class Instance
-- Exposes: Bagshui.components.Bags [via Inventory:New()]

Bagshui:AddComponent(function()
  -- Create class instance.
  local Bags = Bagshui.prototypes.Inventory:New(BS_INVENTORY_TYPE.BAGS)

  -- Hook handling.

  -- The original WoW API function needs to be called for Close* and Toggle* if the
  -- original container frame is open. If this isn't done, clicking the close button
  -- on the original frame will only affect Bagshui and leave the  original frame
  -- stuck on the screen forever.

  --- Open bag hooks (OpenAllBags, OpenBackpack, OpenBag(bagNum)).
  ---@param hookFunctionName string Name of the original WoW API function.
  ---@param bagNumParam number Container ID.
  function Bags:OpenBag(hookFunctionName, bagNumParam)
    self:OpenCloseToggle(BS_INVENTORY_UI_VISIBILITY_ACTION.OPEN, hookFunctionName, bagNumParam)
  end

  --- Close bag hooks (CloseBackpack, CloseBag(bagNum)).
  ---@param hookFunctionName string Name of the original WoW API function.
  ---@param bagNumParam number Container ID.
  function Bags:CloseBag(hookFunctionName, bagNumParam)
    self:OpenCloseToggle(
      BS_INVENTORY_UI_VISIBILITY_ACTION.CLOSE,
      hookFunctionName,
      bagNumParam,
      self:OriginalContainerFrameVisible(bagNumParam)
    )
  end

  --- Toggle bag hooks (ToggleBackpack, ToggleBag(bagNum)).
  ---@param hookFunctionName string Name of the original WoW API function.
  ---@param bagNumParam number Container ID.
  function Bags:ToggleBag(hookFunctionName, bagNumParam)
    self:OpenCloseToggle(
      BS_INVENTORY_UI_VISIBILITY_ACTION.TOGGLE,
      hookFunctionName,
      bagNumParam,
      self:OriginalContainerFrameVisible(bagNumParam)
    )
  end

  --- Register additional events and properties to make bag slot buttons "just work" with Blizzard code.
  ---@param bagSlotButton table Bag slot button instance.
  function Bags:BagSlotButton_Init(bagSlotButton)
    bagSlotButton:RegisterEvent("BAG_UPDATE")
    bagSlotButton.isBag = 1 -- We're not relying too much on PaperDollItemSlotButton, but let's set this just to be safe.

    local oldOnClick = bagSlotButton:GetScript("OnClick")
    --- If there was an item in the cursor when the slot was clicked, catch it and prevent the original
    --- from being called, since since PaperDollItemSlotButton will interpret that as trying to *equip*
    --- the item in that slot, instead of trying to put it in the bag. Note that due to the behavior of
    --- `PutItemInBag()`, this will *not* intercept bags, but that's handled in the bag slot button's OnClick.
    bagSlotButton:SetScript("OnClick", function(bagButton, mouseButton)
      local this = bagButton
      if
        -- Pass through to the default Bagshui OnClick for bags
        -- so native bag swapping can be invoked.
        (_G.CursorHasItem() and BsItemInfo:IsContainer(Bagshui.cursorItem))
        -- Otherwise, allow PutItemInBag() to catch cursor items and move them.
        or not _G.PutItemInBag(this.bagshuiData.inventorySlotId)
      then
        oldOnClick(this, mouseButton)
      end
    end)
  end

  --- Override Inventory:UpdateBagBar() and Inventory:UiFrame_OnHide() so we can correctly set the
  --- highlight state of the Blizzard action bar bag slot buttons when our window opens/closes/updates.
  function Bags:UpdateBagBar()
    self._super.UpdateBagBar(self)
    -- Don't update action bar bag slot buttons until the next update tick.
    -- This avoids having the Blizzard UI code immediately turn off the checked state.
    Bagshui:QueueClassCallback(self, self.UpdateActionBarBagSlotButtonState)
  end

  --- Ensure the Blizzard action bar bag buttons are un-highlighted when the Bags window is closed.
  function Bags:UiFrame_OnHide()
    self._super.UiFrame_OnHide(self)
    -- It's safe to instantly un-highlight the action bar bag buttons when the window is closed.
    self:UpdateActionBarBagSlotButtonState()
  end

  Bags._actionBarButtonWasChecked = {}
  --- Set Blizzard action bar bag slot buttons to "checked" (highlighted) when our
  --- window is open and unchecked when it's closed.
  function Bags:UpdateActionBarBagSlotButtonState()
    local shouldBeChecked = self:Visible()
    local actionBarButtonName, actionBarButton

    for _, bagNum in pairs(self.containerIds) do
      local hookEnabled = self:GetHookEnabled("Bag", bagNum)
      -- Only highlight bags in the action bar that we're hooking.
      if
        (hookEnabled or self._actionBarButtonWasChecked[bagNum])
        and type(self.currentCharacterInventory[bagNum]) == "table"
      then
        if bagNum == 0 then
          actionBarButtonName = "MainMenuBarBackpackButton"
        else
          actionBarButtonName = string.format("CharacterBag%dSlot", bagNum + self.bagSlotNameNumberOffset)
        end
        actionBarButton = _G[actionBarButtonName]
        -- Avoid messing with the highlight state when the original container frame is open.
        if actionBarButton and not self:OriginalContainerFrameVisible(bagNum) then
          actionBarButton:SetChecked(
            shouldBeChecked
              and hookEnabled
              -- Only highlight buttons where there are bags.
              and (table.getn(self.currentCharacterInventory[bagNum]) > 0)
          )
          self._actionBarButtonWasChecked[bagNum] = hookEnabled
        end
      end
    end
  end

  --- Helper to determine when when one of the Blizzard bag frames is open.
  ---@param bagNum any
  ---@return boolean frameVisible
  function Bags:OriginalContainerFrameVisible(bagNum)
    if not bagNum then
      return false
    end
    return self.ui:IsFrameVisible("ContainerFrame" .. tostring(bagNum))
  end

  --- Execute `self:Open()/Close()` and the superclass version only if there isn't a reason to block it.
  ---@param action "Open"|"Close"
  ---@param triggerEvent string? Event that requested the action.
  ---@return boolean? # false if event was blocked.
  function Bags:SmartOpenClose(action, triggerEvent)
    -- Block based on settings.
    if
      type(triggerEvent) == "string"
      and (
        (string.find(triggerEvent, "^AUCTION_HOUSE_") and self.settings.toggleBagsWithAuctionHouse == false)
        or (string.find(triggerEvent, "^BANKFRAME_") and self.settings.toggleBagsWithBankFrame == false)
        or (string.find(triggerEvent, "^MAIL_") and self.settings.toggleBagsWithMailFrame == false)
        or (string.find(triggerEvent, "^TRADE_") and self.settings.toggleBagsWithTradeFrame == false)
      )
    then
      return
    end

    -- Proceed with action.
    self._super[action](self, triggerEvent)
  end

  --- Add intelligence to Open().
  function Bags:Open(triggerEvent)
    self:SmartOpenClose("Open", triggerEvent)
  end

  --- Add intelligence to Close().
  function Bags:Close(triggerEvent)
    self:SmartOpenClose("Close", triggerEvent)
    self.lastOpenEventTrigger = nil
  end

  -- Marked-for-sale items are a one-shot, per-character vendor queue.
  -- itemString contains WoW's unique item ID when one is available, allowing
  -- individual gear pieces to stay marked even if they move to another bag slot.
  local MARKED_FOR_SALE_DATA_KEY = "markedForSale"

  local function getUniqueItemId(itemString)
    local uniqueId = string.match(tostring(itemString or ""), "^item:%d+:%d+:%d+:(%d+)$")
    return tonumber(uniqueId) or 0
  end

  local function getLiveItemString(bagNum, slotNum)
    if type(bagNum) ~= "number" or type(slotNum) ~= "number" then
      return nil
    end
    local itemLink = _G.GetContainerItemLink(bagNum, slotNum)
    if not itemLink then
      return nil
    end
    return BsItemInfo:ParseItemLink(itemLink)
  end

  --- Return the current character's persistent marked-for-sale list.
  ---@return table markedForSale
  function Bags:GetMarkedForSaleList()
    if type(Bagshui.currentCharacterData[MARKED_FOR_SALE_DATA_KEY]) ~= "table" then
      Bagshui.currentCharacterData[MARKED_FOR_SALE_DATA_KEY] = {}
    end
    return Bagshui.currentCharacterData[MARKED_FOR_SALE_DATA_KEY]
  end

  --- Find the queue entry corresponding to a Bagshui item.
  --- Items with a real unique ID follow moves; non-unique stackable items only
  --- match the exact bag/slot originally marked so another copy is never sold.
  ---@param item table Bagshui item.
  ---@return number? index
  ---@return table? entry
  function Bags:FindMarkedForSaleEntry(item)
    if type(item) ~= "table" or not item.itemString or item.itemString == "" then
      return nil
    end

    local itemUniqueId = getUniqueItemId(item.itemString)
    local markedForSale = self:GetMarkedForSaleList()
    for index, entry in ipairs(markedForSale) do
      if entry.itemString == item.itemString then
        local entryUniqueId = tonumber(entry.uniqueId) or getUniqueItemId(entry.itemString)
        if
          (entryUniqueId ~= 0 and itemUniqueId == entryUniqueId)
          or (
            entryUniqueId == 0
            and entry.bagNum == item.bagNum
            and entry.slotNum == item.slotNum
          )
        then
          return index, entry
        end
      end
    end
    return nil
  end

  --- Whether a Bagshui item is currently marked for one-shot vendor sale.
  ---@param item table Bagshui item.
  ---@return boolean
  function Bags:IsItemMarkedForSale(item)
    return self:FindMarkedForSaleEntry(item) ~= nil
  end

  --- Resolve a saved mark to the item's current live bag/slot.
  --- Unique items are allowed to move; non-unique items must remain in their
  --- original slot to avoid accidentally matching a different stack/copy.
  ---@param entry table Marked-for-sale entry.
  ---@return number? bagNum
  ---@return number? slotNum
  ---@return string? itemString
  function Bags:ResolveMarkedForSaleEntry(entry)
    if type(entry) ~= "table" or type(entry.itemString) ~= "string" then
      return nil
    end

    local itemString = getLiveItemString(entry.bagNum, entry.slotNum)
    if itemString == entry.itemString then
      return entry.bagNum, entry.slotNum, itemString
    end

    local uniqueId = tonumber(entry.uniqueId) or getUniqueItemId(entry.itemString)
    if uniqueId == 0 then
      return nil
    end

    for _, bagNum in ipairs(self.containerIds) do
      local numSlots = _G.GetContainerNumSlots(bagNum) or 0
      for slotNum = 1, numSlots do
        itemString = getLiveItemString(bagNum, slotNum)
        if itemString == entry.itemString then
          entry.bagNum = bagNum
          entry.slotNum = slotNum
          return bagNum, slotNum, itemString
        end
      end
    end

    return nil
  end

  --- Add/remove an item from the one-shot vendor queue.
  ---@param item table Bagshui item.
  ---@return boolean? marked True when marked, false when unmarked.
  function Bags:ToggleItemMarkedForSale(item)
    if
      type(item) ~= "table"
      or item.emptySlot == 1
      or not item.itemString
      or item.itemString == ""
      or not self.online
    then
      return nil
    end

    local markedForSale = self:GetMarkedForSaleList()
    local index = self:FindMarkedForSaleEntry(item)
    local marked

    if index then
      table.remove(markedForSale, index)
      marked = false
    else
      table.insert(markedForSale, {
        itemString = item.itemString,
        uniqueId = getUniqueItemId(item.itemString),
        bagNum = item.bagNum,
        slotNum = item.slotNum,
        name = item.name,
      })
      marked = true
    end

    self.windowUpdateNeeded = true
    if self:Visible() then
      self:ForceUpdateWindow()
    end

    return marked
  end

  --- Remove marks whose items are no longer present after a vendor pass.
  --- A failed sale remains marked because the live item still resolves.
  function Bags:CleanupMarkedForSaleAfterVendor()
    local markedForSale = self:GetMarkedForSaleList()
    local changed = false

    for index = table.getn(markedForSale), 1, -1 do
      if not self:ResolveMarkedForSaleEntry(markedForSale[index]) then
        table.remove(markedForSale, index)
        changed = true
      end
    end

    if changed and self:Visible() then
      self.windowUpdateNeeded = true
      self:ForceUpdateWindow()
    end
  end

  --- Sell all currently resolvable items that were explicitly marked by the player.
  --- Unsellable or locked items stay marked; successful sales are removed only
  --- after the item disappears from the live bag slot.
  function Bags:SellMarkedItems()
    if not self.online then
      return
    end

    local markedForSale = self:GetMarkedForSaleList()
    if table.getn(markedForSale) == 0 then
      return
    end

    local attemptedSale = false
    for _, entry in ipairs(markedForSale) do
      local bagNum, slotNum, itemString = self:ResolveMarkedForSaleEntry(entry)
      if bagNum and slotNum and itemString then
        local _, _, locked = _G.GetContainerItemInfo(bagNum, slotNum)
        local _, _, _, _, _, _, _, _, _, _, sellPrice = _G.GetItemInfo(itemString)

        if not locked and type(sellPrice) == "number" and sellPrice > 0 then
          _G.UseContainerItem(bagNum, slotNum)
          attemptedSale = true
        end
      end
    end

    -- Container updates arrive asynchronously. Verify after a short delay so
    -- marks are only removed once the corresponding item is actually gone.
    if attemptedSale then
      Bagshui:QueueClassCallback(self, self.CleanupMarkedForSaleAfterVendor, 0.2)
    else
      self:CleanupMarkedForSaleAfterVendor()
    end
  end

end)
