-- Bagshui UI Class: Search Boxes

Bagshui:AddComponent(function()
  local Ui = Bagshui.prototypes.Ui

  --- Create a new search box.
  ---@param name string Unique name for the search box (will be passed to `Ui:CreateElementName()`).
  ---@param parent table Parent frame.
  ---@param width number Default: 85.
  ---@param height number Default: 18.
  ---@param onTextChanged function? OnTextChanged script.
  ---@param onEnterPressed function? OnEnterPressed script.
  ---@param onIconClick function? OnClick for search icon.
  ---@param placeholderText string? Text to display when the search box is empty.
  ---@param onTextChangedDebounceSeconds number? Delay `onTextChanged` by this many seconds and coalesce rapid changes. Clearing remains immediate.
  ---@return table searchBox
  function Ui:CreateSearchBox(
    name,
    parent,
    width,
    height,
    onTextChanged,
    onEnterPressed,
    onIconClick,
    placeholderText,
    onTextChangedDebounceSeconds
  )
    width = width or 85
    height = height or 18

    local searchBox = self:CreateEditBox(name, parent)
    searchBox.bagshuiData = {}

    searchBox:SetWidth(width)
    searchBox:SetHeight(height)

    searchBox:SetHistoryLines(10)

    -- Add behaviors.

    -- Focus gained.
    local oldOnEditFocusGained = searchBox:GetScript("OnEditFocusGained")
    searchBox:SetScript("OnEditFocusGained", function(editBox, ...)
      oldOnEditFocusGained(editBox, ...)
      Bagshui:CloseMenus()
      self:UpdateSearchBoxState(editBox)
      editBox:HighlightText()
    end)

    -- Focus lost.
    local oldOnEditFocusLost = searchBox:GetScript("OnEditFocusLost")
    searchBox:SetScript("OnEditFocusLost", function(editBox, ...)
      oldOnEditFocusLost(editBox, ...)
      editBox.bagshuiData.hasFocus = false
      self:UpdateSearchBoxState(editBox)
      editBox:HighlightText(0, 0)
    end)

    -- Text changed. The delayed callback is unique to this edit box, allowing
    -- Bagshui's event queue to coalesce typing without one search box replacing
    -- another's pending callback.
    if onTextChanged and onTextChangedDebounceSeconds then
      searchBox.bagshuiData.runOnTextChanged = function(editBox, ...)
        if not editBox.bagshuiData.onTextChangedPending or not editBox:IsShown() then
          return
        end
        editBox.bagshuiData.onTextChangedPending = false
        onTextChanged(editBox, ...)
      end
    end

    searchBox:SetScript("OnTextChanged", function(editBox, ...)
      local searchText = editBox:GetText()
      editBox.bagshuiData.searchText = (type(searchText) == "string" and string.len(searchText) > 0) and searchText
        or nil
      self:UpdateSearchBoxState(editBox)
      if onTextChanged then
        if onTextChangedDebounceSeconds and editBox.bagshuiData.searchText then
          editBox.bagshuiData.onTextChangedPending = true
          Bagshui:QueueEvent(
            editBox.bagshuiData.runOnTextChanged,
            onTextChangedDebounceSeconds,
            false,
            editBox,
            ...
          )
        else
          -- Clearing a search should restore the full list immediately and
          -- invalidate any callback that is still waiting in the event queue.
          editBox.bagshuiData.onTextChangedPending = false
          onTextChanged(editBox, ...)
        end
      end
    end)

    -- Hiding a window doesn't remove an event from Bagshui's queue. Mark its
    -- callback stale so reopening or reusing the window can't apply old text.
    searchBox:SetScript("OnHide", function(editBox)
      editBox.bagshuiData.onTextChangedPending = false
    end)

    -- Focus and history management based on keyboard input.

    searchBox:SetScript("OnEnterPressed", function(editBox, ...)
      editBox:AddHistoryLine(editBox:GetText())
      if onEnterPressed then
        onEnterPressed(editBox, ...)
      end
      editBox:ClearFocus()
    end)

    searchBox:SetScript("OnEscapePressed", function(editBox)
      if string.len(editBox:GetText() or "") > 0 then
        editBox:AddHistoryLine(editBox:GetText())
        editBox:SetText("")
      else
        editBox:ClearFocus()
      end
    end)

    searchBox:SetScript("OnTabPressed", function(editBox)
      editBox:AddHistoryLine(editBox:GetText())
      editBox:ClearFocus()
    end)

    -- Mouse events.

    searchBox:SetScript("OnEnter", function(editBox)
      editBox.bagshuiData.mouseIsOver = true
      self:UpdateSearchBoxState(editBox)
    end)

    searchBox:SetScript("OnLeave", function(editBox)
      editBox.bagshuiData.mouseIsOver = false
      self:UpdateSearchBoxState(editBox)
    end)

    -- Add search icon.
    searchBox.bagshuiData.searchIcon = self:CreateIconButton({
      name = name .. "SearchIcon",
      parentFrame = searchBox,
      tooltipGroupElement = parent,
      anchorPoint = "LEFT",
      xOffset = 2,
      width = height - 5,
      height = height - 5,
      onClick = function()
        searchBox:SetFocus()
        if onIconClick then
          onIconClick()
        end
      end,
      texture = "Search",
      tooltipTitle = L.Search,
    })

    -- Add placeholder text.
    searchBox.bagshuiData.placeholder = searchBox:CreateFontString(nil, nil, "GameFontHighlightSmall")
    -- Need enough left offset for the rectangle cursor to not obscure it.
    searchBox.bagshuiData.placeholder:SetPoint("LEFT", searchBox.bagshuiData.searchIcon, "RIGHT", 7, 0)
    searchBox.bagshuiData.placeholder:SetPoint("RIGHT", searchBox, "RIGHT", -5, 0)
    searchBox.bagshuiData.placeholder:SetJustifyH("LEFT")
    searchBox.bagshuiData.placeholder:SetVertexColor(1, 1, 1, 0.4)
    searchBox.bagshuiData.placeholder:SetText(placeholderText or "")

    -- Add clear ("x") icon.
    searchBox.bagshuiData.clearIcon = self:CreateIconButton({
      name = name .. "ClearIcon",
      parentFrame = searchBox,
      vertexColor = BS_COLOR.GRAY,
      tooltipGroupElement = parent,
      anchorPoint = "RIGHT",
      anchorToPoint = "RIGHT",
      xOffset = -2,
      width = 12,
      height = 12,
      onClick = function()
        searchBox:SetFocus()
        searchBox:SetText("")
      end,
      hoverVertexColor = BS_COLOR.YELLOW,
      textureDir = "UI",
      texture = "Clear",
      tooltipTitle = L.Clear,
    })

    -- Move the left end of the text away from the search icon.
    searchBox:SetTextInsets(18, 0, 0, 0)

    -- Set initial state.
    self:UpdateSearchBoxState(searchBox)

    return searchBox
  end

  --- Manage search box colors and icon visibility.
  ---@param searchBox table Return value from `Ui:CreateSearchBox()`.
  function Ui:UpdateSearchBoxState(searchBox)
    if type(searchBox) ~= "table" then
      return
    end

    local backdropOpacity = 0.25
    local backdropBorderColorR = BsSkin.editBoxBorderColor[1]
    local backdropBorderColorG = BsSkin.editBoxBorderColor[2]
    local backdropBorderColorB = BsSkin.editBoxBorderColor[3]
    local backdropBorderOpacity = BsSkin.editBoxBorderColor[4]

    if searchBox.bagshuiData.hasFocus then
      backdropOpacity = 0.5
      backdropBorderColorR = NORMAL_FONT_COLOR.r
      backdropBorderColorG = NORMAL_FONT_COLOR.g
      backdropBorderColorB = NORMAL_FONT_COLOR.b
      backdropBorderOpacity = 0.75
    elseif searchBox.bagshuiData.mouseIsOver then
      backdropBorderOpacity = 0.75
    end

    searchBox:SetBackdropColor(0, 0, 0, backdropOpacity)
    searchBox:SetBackdropBorderColor(
      backdropBorderColorR,
      backdropBorderColorG,
      backdropBorderColorB,
      backdropBorderOpacity
    )

    -- Show clear ("x") icon if there is text, hide if not.
    -- Do the inverse to the placeholder text.
    searchBox.bagshuiData.clearIcon[searchBox.bagshuiData.searchText and "Show" or "Hide"](
      searchBox.bagshuiData.clearIcon
    )
    searchBox.bagshuiData.placeholder[searchBox.bagshuiData.searchText and "Hide" or "Show"](
      searchBox.bagshuiData.placeholder
    )
  end
end)

