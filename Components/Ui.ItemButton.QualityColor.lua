-- Bagshui UI Class: Item Slot Quality Color Safety

Bagshui:LoadComponent(function()
  local Ui = Bagshui.prototypes.Ui
  local updateItemButtonColorsAndBadges = Ui.UpdateItemButtonColorsAndBadges

  --- Keep item-slot rendering safe when the client has no color entry for an
  --- item quality. AssignItemToItemButton() can otherwise leave qualityColor
  --- nil, and the next color refresh will fail while indexing .r/.g/.b.
  function Ui:UpdateItemButtonColorsAndBadges(button, force)
    local buttonInfo = button and button.bagshuiData
    if buttonInfo and not buttonInfo.qualityColor then
      buttonInfo.qualityColor =
        (_G.ITEM_QUALITY_COLORS and _G.ITEM_QUALITY_COLORS[1])
        or BsSkin.itemSlotBorderDefaultColor
        or { r = 1, g = 1, b = 1, a = 1 }
    end

    return updateItemButtonColorsAndBadges(self, button, force)
  end
end)
