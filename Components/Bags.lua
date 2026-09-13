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
    -- Secure UIPanel hiding can fire this while protected child buttons are
    -- locked down. Defer UI cleanup until combat ends.
    if _G.InCombatLockdown and _G.InCombatLockdown() then
      self.combatHideCleanupDeferred = true
      self.actionBarBagStateDeferred = true
      return
    end

    self.combatHideCleanupDeferred = nil
    self._super.UiFrame_OnHide(self)
    self:UpdateActionBarBagSlotButtonState()
  end

  Bags._actionBarButtonWasChecked = {}
  --- Set Blizzard action bar bag slot buttons to "checked" (highlighted) when our
  --- window is open and unchecked when it's closed.
  function Bags:UpdateActionBarBagSlotButtonState()
    if _G.InCombatLockdown and _G.InCombatLockdown() then
      self.actionBarBagStateDeferred = true
      return
    end

    self.actionBarBagStateDeferred = nil
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
  -- Use the exact live bag slot plus the full WotLK item hyperlink. Bagshui's
  -- historical itemString parser intentionally reduces links to the old four-field
  -- format, so it must not be used to identify a specific WotLK item here.
  local MARKED_FOR_SALE_DATA_KEY = "markedForSale"

  local function getMarkedForSaleSlotKey(bagNum, slotNum)
    return tostring(bagNum) .. ":" .. tostring(slotNum)
  end

  local function getLiveItemLink(bagNum, slotNum)
    if type(bagNum) ~= "number" or type(slotNum) ~= "number" then
      return nil
    end
    return _G.GetContainerItemLink(bagNum, slotNum)
  end

  --- Return the current character's persistent marked-for-sale map.
  --- Keys are "<bagNum>:<slotNum>" and values contain the exact full item link.
  ---@return table markedForSale
  function Bags:GetMarkedForSaleList()
    local markedForSale = Bagshui.currentCharacterData[MARKED_FOR_SALE_DATA_KEY]

    if type(markedForSale) ~= "table" then
      markedForSale = {}
      Bagshui.currentCharacterData[MARKED_FOR_SALE_DATA_KEY] = markedForSale
    elseif markedForSale[1] ~= nil then
      -- Migrate away from the broken first implementation, which stored an
      -- array based on Bagshui's shortened four-field item strings.
      markedForSale = {}
      Bagshui.currentCharacterData[MARKED_FOR_SALE_DATA_KEY] = markedForSale
    end

    return markedForSale
  end

  --- Find the mark corresponding to the item's exact current bag slot.
  --- The live full item link must still match so a different item that later
  --- occupies the same slot can never inherit the old sale mark.
  ---@param item table Bagshui item.
  ---@return string? key
  ---@return table? entry
  function Bags:FindMarkedForSaleEntry(item)
    if
      type(item) ~= "table"
      or type(item.bagNum) ~= "number"
      or type(item.slotNum) ~= "number"
      or item.emptySlot == 1
    then
      return nil
    end

    local key = getMarkedForSaleSlotKey(item.bagNum, item.slotNum)
    local entry = self:GetMarkedForSaleList()[key]
    if not entry then
      return nil
    end

    local liveItemLink = getLiveItemLink(item.bagNum, item.slotNum)
    if liveItemLink and liveItemLink == entry.itemLink then
      return key, entry
    end

    return nil
  end

  --- Whether a Bagshui item is currently marked for one-shot vendor sale.
  ---@param item table Bagshui item.
  ---@return boolean
  function Bags:IsItemMarkedForSale(item)
    return self:FindMarkedForSaleEntry(item) ~= nil
  end

  --- Add/remove an item from the one-shot vendor queue.
  ---@param item table Bagshui item.
  ---@return boolean? marked True when marked, false when unmarked.
  function Bags:ToggleItemMarkedForSale(item)
    if
      type(item) ~= "table"
      or item.emptySlot == 1
      or type(item.bagNum) ~= "number"
      or type(item.slotNum) ~= "number"
      or not self.online
    then
      return nil
    end

    local liveItemLink = getLiveItemLink(item.bagNum, item.slotNum)
    if not liveItemLink then
      return nil
    end

    local markedForSale = self:GetMarkedForSaleList()
    local key = getMarkedForSaleSlotKey(item.bagNum, item.slotNum)
    local existingEntry = markedForSale[key]
    local marked

    if existingEntry and existingEntry.itemLink == liveItemLink then
      markedForSale[key] = nil
      marked = false
    else
      markedForSale[key] = {
        bagNum = item.bagNum,
        slotNum = item.slotNum,
        itemLink = liveItemLink,
        name = item.name,
      }
      marked = true
    end

    -- The sale badge is resolved dynamically in UpdateItemButtonColorsAndBadges,
    -- so a lightweight color/badge refresh is enough and updates immediately.
    if self:Visible() then
      self:UpdateItemSlotColors()
    end

    return marked
  end

  --- Remove stale marks after a vendor pass.
  --- Successful sales disappear from their bag slots; failed/unsellable items
  --- remain present and therefore remain marked.
  function Bags:CleanupMarkedForSaleAfterVendor()
    local markedForSale = self:GetMarkedForSaleList()
    local changed = false

    for key, entry in pairs(markedForSale) do
      local liveItemLink = getLiveItemLink(entry.bagNum, entry.slotNum)
      if not liveItemLink or liveItemLink ~= entry.itemLink then
        markedForSale[key] = nil
        changed = true
      end
    end

    if changed and self:Visible() then
      self:UpdateItemSlotColors()
    end
  end

  --- Sell all items explicitly marked by the player.
  --- Only the exact item still occupying the exact marked slot is eligible.
  --- Unsellable/locked items are skipped and stay marked.
  function Bags:SellMarkedItems()
    if not self.online then
      return
    end

    local markedForSale = self:GetMarkedForSaleList()
    if next(markedForSale) == nil then
      return
    end

    local attemptedSale = false
    for _, entry in pairs(markedForSale) do
      local liveItemLink = getLiveItemLink(entry.bagNum, entry.slotNum)
      if liveItemLink and liveItemLink == entry.itemLink then
        local _, _, locked = _G.GetContainerItemInfo(entry.bagNum, entry.slotNum)
        local _, _, _, _, _, _, _, _, _, _, sellPrice = _G.GetItemInfo(liveItemLink)

        if not locked and type(sellPrice) == "number" and sellPrice > 0 then
          _G.UseContainerItem(entry.bagNum, entry.slotNum)
          attemptedSale = true
        end
      end
    end

    -- Bag updates are asynchronous. Wait until the server has processed the sale
    -- before deciding which marks should be cleared.
    if attemptedSale then
      Bagshui:QueueClassCallback(self, self.CleanupMarkedForSaleAfterVendor, 0.5)
    else
      self:CleanupMarkedForSaleAfterVendor()
    end
  end

end)
