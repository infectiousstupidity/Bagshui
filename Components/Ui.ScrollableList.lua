-- Bagshui UI Class: Scrollable Lists
-- Warning: Messy code ahead.

Bagshui:AddComponent(function()
  local Ui = Bagshui.prototypes.Ui

  -- Inter-column and ScrollFrame edge padding.
  local COLUMN_SPACING = 5

  local HEADER_SPACING = 6

  --- Create a new scrollable list.
  ---
  --- `params` table values:
  --- ```
  --- {
  --- 	---@type string Unique string that will be suffixed per-element and passed to `Ui:CreateElementName()`.
  --- 	namePrefix,
  --- 	---@type number Width of the scrollable list.
  --- 	width,
  --- 	---@type table? Parent frame.
  --- 	parent,
  --- 	---@type BS_UI_SCROLLABLE_LIST_TYPE?? Type of the list.
  --- 	listType,
  --- 	---@type boolean? Can list entries be selected?
  --- 	selectable,
  --- 	---@type boolean? Can multiple list entries be selected simultaneously using control/shift?
  --- 	multiSelect,
  --- 	---@type boolean? When `selectable` and `multiSelect` are true, show a checkbox next to each entry.
  --- 	checkboxes,
  --- 	---@type boolean? When `checkboxes` is true, headers will get checkboxes too unless this is false.
  --- 	headerCheckboxes,
  --- 	---@type boolean? List is fully read-only and cannot be changed. Gets stored in the list's `bagshuiData.readOnly` property.
  --- 	readOnly,
  --- 	---@type string? ASC/DESC
  --- 	initialSortOrder,
  --- 	---@type number?
  --- 	rowHeight,
  --- 	---@type number?
  --- 	rowSpacing,
  --- 	---@type (table|string)?
  --- 	font,
  --- 	---@type (table|string)?
  --- 	headerFont,
  --- 	---@type table[]? Array of columns to display (see below), if more than one field needs to be displayed.
  --- 	entryColumns,
  --- 	---@type boolean? `true` to disable display of column names above the list.
  --- 	hideColumnHeaders,
  --- 	---@type function(entry)? -> table|string Given a list entry value, return display information about that entry. Can return a table whose values should correspond to `entryColumns` fields, with `entryDisplayProperty` being the primary (first) value.
  --- 	entryInfoFunc,
  --- 	---@type string? When `entryInfoFunc` returns a table, this property value will be placed in the first column.
  --- 	entryDisplayProperty,
  --- 	---@type function(entryFrameName, entryFrame, ui)? Called after each entry frame is created to allow for custom modifications.
  --- 	entryFrameCreationFunc,
  --- 	---@type function(listFrame, entryFrame, entry, ui, entryFrameCallbacksExtraParam)? Called after each entry frame is populated to allow for custom modifications.
  --- 	entryFramePopulateFunc,
  --- 	---@type any? Additional parameter for `entryFramePopulateFunc()`.
  --- 	entryFrameCallbacksExtraParam,
  --- 	---@type function(entryDisplayProperty, entry, entryInfo, entryPrimaryText)? -> string When `entryInfoFunc()` returns a table, this will be called to further refine the display value.
  --- 	entryColumnTextFunc
  --- 	---@type function(sortField, listFrame)? Triggered when the sort field is changed by clicking a column header. Must call `Ui:PopulateScrollableList()` with the new list of entries, **sorted ascending**.
  --- 	onSortFieldChanged,
  --- 	---@type table? Alternate parent frame when `buttons` and the search box should be parented differently than the scrollable list itself.
  --- 	buttonAndSearchBoxParent,
  --- 	---@type table[]? Array of buttons to create (see below).
  --- 	buttons,
  --- 	---@type number? Custom x offset of first button that gets created.
  --- 	firstButtonXOffset,
  --- 	---@type boolean? Don't create a search box.
  --- 	noSearchBox,
  --- 	---@type string? Placeholder text for empty search box.
  --- 	searchPlaceholderText,
  --- 	---@type function(entries, entryFrame)? Called after the entire list is updated.
  --- 	onChangeFunc,
  --- 	---@type function(listFrame)? Callback triggered after a selection is made and the list has been updated to the new state.
  --- 	onSelectionChangedFunc,
  --- 	---@type function? Called when a list entry is double-clicked.
  --- 	onDoubleClickFunc,
  --- 	---@type function(entryFrame, modifierKeyRefresh)? Called when the mouse enters a list frame (this is already handled for item lists and will be ignored).
  --- 	entryOnEnterFunc,
  --- 	---@type function(entryFrame)? Called when the mouse leaves a list frame (this is already handled for item lists and will be ignored).
  --- 	entryOnLeaveFunc,
  --- 	---@type table? Frame that should receive drag events for item lists.
  --- 	itemDragTarget
  --- }
  --- ```
  --- `entryColumns` is an array of:
  --- ```
  --- {
  --- 	---@type string Property in the table returned from `entryInfoFunc()` to display.
  --- 	field = "name",
  --- 	---@type string Column title to display in the UI.
  --- 	title = L.CategoryManager_Name,
  --- 	---@type number Absolute width of this column. Either `width` or `widthPercent` is required, with the former prioritized over the latter.
  --- 	width = 200,
  --- 	---@type number Relative width of this column.
  --- 	widthPercent = 90,
  --- 	---@type string Only one column should have this property. This will be the initial sort order of the list.
  ---		currentSortOrder = "ASC",
  --- 	---@type string Starting sort order for this column if the user chooses to sort by it.
  ---		lastSortOrder = "ASC",
  --- 	---@type boolean Disallow changing sort order for this column.
  ---		lockSortOrder = true,
  --- }
  --- ```
  ---
  --- `buttons` is an array of `Ui:CreateIconButton()` `buttonOpts` parameter values, plus the special properties below.
  --- Note that the `*_Disable` properties can be updated at any time before calling `PopulateScrollableList()`
  --- and the changes will be taken into account.
  --- ```
  --- {
  --- 	---@type boolean? Don't create this button.
  --- 	skip,
  --- 	---@type BS_UI_SCROLLABLE_LIST_BUTTON_NAME? One of the pre-configured scrollable list button types, some of which come with built-in behaviors.
  --- 	scrollableList_ButtonName,
  --- 	---@type boolean? When true, anchor this button to the previous one in the array.
  --- 	scrollableList_AutomaticAnchor,
  --- 	---@type boolean? When true, anchor this button to the search box for the list frame.
  --- 	scrollableList_AnchorToSearchBox,
  --- 	---@type boolean? When true, anchor this button to the scroll frame itself (technically anchors to the background since that's the visual representation of the ScrollFrame).
  --- 	scrollableList_AnchorToScrollFrame,
  --- 	---@type boolean? When true, disable the button.
  --- 	scrollableList_Disable,
  --- 	---@type boolean? When true, disable the button if nothing in the list is selected.
  --- 	scrollableList_DisableIfNothingSelected,
  --- 	---@type boolean? When true, disable the button if multiple items in the list are selected.
  --- 	scrollableList_DisableIfMultipleSelected,
  --- 	---@type boolean? When true, disable the button when the first item in the list is selected.
  --- 	scrollableList_DisableIfFirstEntrySelected,
  --- 	---@type boolean? When true, disable the button only when the last item in the list is selected.
  --- 	scrollableList_DisableIfLastEntrySelected,
  --- 	---@type boolean? When true, disable the button if the list entry information has a `readOnly` property that is true.
  --- 	scrollableList_DisableIfReadOnly,
  --- 	---@type function(scrollableListEntryInfo) -> boolean? When true is returned, disable the button.
  --- 	scrollableList_DisableFunc,
  --- }
  ---```
  ---@param params table
  ---@return table scrollFrame
  ---@return table scrollChild
  ---@return table listFrame
  function Ui:CreateScrollableList(params)
    assert(type(params) == "table", "Parameter list for Ui:CreateScrollableList() must be a table")
    assert(params.namePrefix, "CreateScrollableItemList(): namePrefix is required")
    assert(params.width, "CreateScrollableItemList(): width is required")

    -- Default to text list if not specified.
    local listType = params.listType or BS_UI_SCROLLABLE_LIST_TYPE.TEXT

    -- Prepare list of available buttons (this can't be done sooner due to localization stuff).
    -- Using `Ui` instead of `self` here so it's only done once -- this is constant across all instances of the Ui class.
    if not Ui._createScrollableList_AvailableButtons then
      Ui._createScrollableList_AvailableButtons = {
        [BS_UI_SCROLLABLE_LIST_BUTTON_NAME.NEW] = {
          name = "New",
          texture = "Add",
          tooltipTitle = L.New,
        },
        [BS_UI_SCROLLABLE_LIST_BUTTON_NAME.ADD] = {
          name = "Add",
          texture = "Add",
          tooltipTitle = L.Add,
        },
        [BS_UI_SCROLLABLE_LIST_BUTTON_NAME.DELETE] = {
          name = "Delete",
          texture = "Delete",
          tooltipTitle = L.Delete,
          scrollableList_DisableIfNothingSelected = true,
          scrollableList_DisableIfReadOnly = true,
        },
        [BS_UI_SCROLLABLE_LIST_BUTTON_NAME.DOWN] = {
          name = "Down",
          texture = "Down",
          tooltipTitle = L.MoveDown,
          scrollableList_DisableIfNothingSelected = true,
          scrollableList_DisableIfLastEntrySelected = true,
        },
        [BS_UI_SCROLLABLE_LIST_BUTTON_NAME.DUPLICATE] = {
          name = "Duplicate",
          texture = "Duplicate",
          tooltipTitle = L.Duplicate,
          scrollableList_DisableIfNothingSelected = true,
          scrollableList_DisableIfMultipleSelected = true,
        },
        [BS_UI_SCROLLABLE_LIST_BUTTON_NAME.EDIT] = {
          name = "Edit",
          texture = "Edit",
          tooltipTitle = L.Edit,
          scrollableList_DisableIfNothingSelected = true,
          scrollableList_DisableIfMultipleSelected = true,
        },
        [BS_UI_SCROLLABLE_LIST_BUTTON_NAME.IMPORT] = {
          name = "Import",
          texture = "Import",
          tooltipTitle = L.Import,
        },
        [BS_UI_SCROLLABLE_LIST_BUTTON_NAME.REMOVE] = {
          name = "Remove",
          texture = "Remove",
          tooltipTitle = L.Remove,
          scrollableList_DisableIfNothingSelected = true,
        },
        [BS_UI_SCROLLABLE_LIST_BUTTON_NAME.REPLACE] = {
          name = "Replace",
          texture = "Replace",
          tooltipTitle = L.Replace,
          scrollableList_DisableIfNothingSelected = true,
          scrollableList_DisableIfMultipleSelected = true,
        },
        [BS_UI_SCROLLABLE_LIST_BUTTON_NAME.SHARE] = {
          name = "Share",
          texture = "Share",
          tooltipTitle = L.Share,
          scrollableList_DisableIfEmptyList = true,
        },
        [BS_UI_SCROLLABLE_LIST_BUTTON_NAME.UP] = {
          name = "Up",
          texture = "Up",
          tooltipTitle = L.MoveUp,
          scrollableList_DisableIfNothingSelected = true,
          scrollableList_DisableIfFirstEntrySelected = true,
        },
      }
    end

    -- Helper functions -- declared here to capture `self`.
    if not self._scrollableList_SetSelection then
      -- OnClick helper function for list selection and pulling items from the cursor.
      self._scrollableList_SetSelection = function(entryFrame)
        -- If there is an item on the cursor, add that to the list.
        local item
        if entryFrame.bagshuiData.listFrame.bagshuiData.scrollableListType == BS_UI_SCROLLABLE_LIST_TYPE.ITEM then
          item = Bagshui:GetCursorItem()
        end
        if item then
          -- The cursor held an item.
          self:ItemListAdd(entryFrame.bagshuiData.listFrame, item.id)
          _G.ClearCursor()
        else
          -- Normal behavior.
          self:CloseMenusAndClearFocuses(true, true, false)
          self:SetScrollableListSelection(entryFrame.bagshuiData.listFrame, entryFrame)
        end
      end

      -- OnMouseUp/OnReceiveDrag helper function for item lists to pull items from the cursor.
      self._scrollableItemList_ReceivedItem = function(targetFrame)
        if not targetFrame.bagshuiData then
          return
        end
        local item = Bagshui:GetCursorItem()
        local targetListFrame = targetFrame.bagshuiData.itemDragTargetListFrame
          or targetFrame.bagshuiData.listFrame
          or (targetFrame.bagshuiData.entries and targetFrame)
        if item and targetListFrame then
          self:ItemListAdd(targetListFrame, item.id)
          _G.ClearCursor()
        end
      end

      -- OnClick helper function for column headers.
      self._scrollableList_SetSortOrder = function(columnFrame)
        -- Changing the sort field is only possible if there's a callback function
        -- to re-sort the entry list. As noted in the `params` table description for
        -- `Ui:CreateScrollableList()`, this function is responsible for calling
        -- `Ui:PopulateScrollableList()` with the updated entry list, **sorted ascending**.
        if columnFrame.bagshuiData.listFrame.bagshuiData.onSortFieldChanged then
          _G.PlaySound("igMainMenuOptionCheckBoxOn")

          -- Get the sort field name and the most recent way it was sorted.
          local sortField = columnFrame.bagshuiData.columnParams.sortField or columnFrame.bagshuiData.columnParams.field
          local newSortOrder = columnFrame.bagshuiData.columnParams.lastSortOrder

          -- If the field is the current sort order field, reverse it.
          if
            columnFrame.bagshuiData.columnParams.currentSortOrder and not columnFrame.bagshuiData.columnParams.lockSortOrder
          then
            if columnFrame.bagshuiData.columnParams.currentSortOrder == "ASC" then
              newSortOrder = "DESC"
            else
              newSortOrder = "ASC"
            end
          end

          -- Update the state of all sort fields
          for _, col in ipairs(columnFrame.bagshuiData.listFrame.bagshuiData.entryColumns) do
            if (col.sortField or col.field) == sortField then
              col.currentSortOrder = newSortOrder
              col.lastSortOrder = newSortOrder
            else
              col.currentSortOrder = nil
            end
          end

          -- Store the sort order so `PopulateScrollableList()` can decide whether
          -- it's working forwards or backwards through the entry list.
          columnFrame.bagshuiData.listFrame.bagshuiData.sortOrder = newSortOrder

          -- Trigger the callback.
          columnFrame.bagshuiData.listFrame.bagshuiData.onSortFieldChanged(sortField, columnFrame.bagshuiData.listFrame)
        end
      end
    end

    -- Create the scrollable list components and store cross-references everywhere for easy access.

    local scrollFrame, scrollChild, listFrame = self:CreateScrollableContent(params.namePrefix, params.parent)
    scrollChild.bagshuiData.listFrame = listFrame
    scrollFrame.bagshuiData.listFrame = listFrame
    scrollFrame.bagshuiData.scrollableListType = listType
    scrollChild.bagshuiData.scrollableListType = listType
    listFrame.bagshuiData.scrollableListType = listType
    listFrame.bagshuiData.ui = self

    -- Initialize Bagshui properties.

    -- Array of list entry values, as provided to `Ui:PopulateScrollableList()`.
    ---@type any[]
    listFrame.bagshuiData.entries = {}

    -- Logical rows are kept separately from the small set of physical frames
    -- bound to rows currently in (or just outside) the viewport.
    listFrame.bagshuiData.logicalEntries = {}
    listFrame.bagshuiData.visibleEntries = {}
    listFrame.bagshuiData.entryFrames = {}

    -- Key-value table representing all currently selected objects in the list.
    -- Keys are object IDs and values are always `true`.
    ---@type table<any, true>
    listFrame.bagshuiData.selectedEntries = {}

    -- When only one item in the list is selected, this will be populated with
    -- its object ID (it will also have an entry in `selectedEntries`; this is
    -- provided for convenience so functions that only deal with one selected
    -- item don't need to iterate and do extra work).
    ---@type any
    listFrame.bagshuiData.selectedEntry = nil

    -- Pass parameters through for later use (see this function's definition for details).

    listFrame.bagshuiData.entryInfoFunc = params.entryInfoFunc
    listFrame.bagshuiData.entryColumnTextFunc = params.entryColumnTextFunc
    listFrame.bagshuiData.sortOrder = params.initialSortOrder or "ASC"
    listFrame.bagshuiData.onSortFieldChanged = params.onSortFieldChanged
    listFrame.bagshuiData.entryFrameCreationFunc = params.entryFrameCreationFunc
    listFrame.bagshuiData.entryColumns = params.entryColumns
    listFrame.bagshuiData.entryFramePopulateFunc = params.entryFramePopulateFunc
    listFrame.bagshuiData.entryFrameCallbacksExtraParam = params.entryFrameCallbacksExtraParam
    listFrame.bagshuiData.entryColumns = params.entryColumns
    listFrame.bagshuiData.entryDisplayProperty = (params.entryColumns and params.entryColumns[1].field)
      or params.entryDisplayProperty
      or "Name"
    listFrame.bagshuiData.rowHeight = params.rowHeight
      or (params.listType == BS_UI_SCROLLABLE_LIST_TYPE.ITEM and 24 or 16)
    listFrame.bagshuiData.rowSpacing = params.rowSpacing
      or (params.listType == BS_UI_SCROLLABLE_LIST_TYPE.ITEM and 3 or 0)
    listFrame.bagshuiData.font = params.font or "GameFontHighlight"
    listFrame.bagshuiData.headerFont = params.headerFont or "GameFontNormal"
    listFrame.bagshuiData.selectable = params.selectable or params.multiSelect
    listFrame.bagshuiData.multiSelect = params.multiSelect
    listFrame.bagshuiData.checkboxes = params.multiSelect and params.checkboxes
    listFrame.bagshuiData.headerCheckboxes = params.headerCheckboxes
    listFrame.bagshuiData.readOnly = params.readOnly
    listFrame.bagshuiData.onSelectionChangedFunc = params.onSelectionChangedFunc
    listFrame.bagshuiData.onDoubleClickFunc = params.onDoubleClickFunc
    listFrame.bagshuiData.entryOnEnterFunc = params.entryOnEnterFunc
    listFrame.bagshuiData.entryOnLeaveFunc = params.entryOnLeaveFunc
    listFrame.bagshuiData.onChangeFunc = params.onChangeFunc

    -- Add drag handling for item lists.
    if listType == BS_UI_SCROLLABLE_LIST_TYPE.ITEM and params.itemDragTarget then
      if not params.itemDragTarget.bagshuiData then
        params.itemDragTarget.bagshuiData = {}
      end

      -- Required by `self._scrollableItemList_ReceivedItem()` for the itemDragTarget.
      -- (Not needed for the other scrollable list components -- see logic in the aforementioned ReceivedItem function.)
      params.itemDragTarget.bagshuiData.itemDragTargetListFrame = listFrame

      -- Drag target + scrollable list components should respond to drag events.
      params.itemDragTarget:EnableMouse(true)
      params.itemDragTarget:SetScript("OnReceiveDrag", self._scrollableItemList_ReceivedItem)
      listFrame:SetScript("OnReceiveDrag", self._scrollableItemList_ReceivedItem)
      scrollFrame:SetScript("OnReceiveDrag", self._scrollableItemList_ReceivedItem)
      scrollChild:SetScript("OnReceiveDrag", self._scrollableItemList_ReceivedItem)

      -- In addition to drag events, everybody needs to receive MouseUp so that
      -- clicking with an item on the cursor works. Capturing the existing OnMouseUp
      -- so nothing gets broken.

      local oldItemDragTargetOnMouseUp = params.itemDragTarget:GetScript("OnMouseUp")
      params.itemDragTarget:SetScript("OnMouseUp", function(targetFrame, ...)
        self._scrollableItemList_ReceivedItem(targetFrame)
        if oldItemDragTargetOnMouseUp then
          oldItemDragTargetOnMouseUp(targetFrame, ...)
        end
      end)

      local oldListFrameOnMouseUp = listFrame:GetScript("OnMouseUp")
      listFrame:SetScript("OnMouseUp", function(targetFrame, ...)
        self._scrollableItemList_ReceivedItem(targetFrame)
        if oldListFrameOnMouseUp then
          oldListFrameOnMouseUp(targetFrame, ...)
        end
      end)

      local scrollChildOnMouseUp = scrollChild:GetScript("OnMouseUp")
      scrollChild:SetScript("OnMouseUp", function(targetFrame, ...)
        self._scrollableItemList_ReceivedItem(targetFrame)
        if scrollChildOnMouseUp then
          scrollChildOnMouseUp(targetFrame, ...)
        end
      end)

      local scrollFrameOnMouseUp = scrollFrame:GetScript("OnMouseUp")
      scrollFrame:SetScript("OnMouseUp", function(targetFrame, ...)
        self._scrollableItemList_ReceivedItem(targetFrame)
        if scrollFrameOnMouseUp then
          scrollFrameOnMouseUp(targetFrame, ...)
        end
      end)
    end

    -- Set initial width.
    self:SetWidth(scrollFrame, params.width) -- Using Ui:SetWidth for ScrollFrame as explained in the function declaration.
    listFrame:SetWidth(params.width)

    -- Add headers if there are columns.
    if params.entryColumns then
      local nextAnchorToFrame = scrollFrame.bagshuiData.background
      local nextAnchorToPoint = "TOPLEFT"

      listFrame.bagshuiData.columnHeaders = {}

      -- Populate listFrame.bagshuiData.columnHeaders with a table of { fieldName = columnFrame }.
      for i, col in ipairs(params.entryColumns) do
        assert(
          col.field,
          "Column " .. i .. " in the " .. params.namePrefix .. " scrollable list does not have a field property"
        )
        assert(
          col.width or col.widthPercent,
          "Column "
            .. i
            .. " in the "
            .. params.namePrefix
            .. " scrollable list does not have a width or widthPercent property"
        )

        local columnFrame = _G.CreateFrame("Button", params.namePrefix .. col.field .. "ColumnHeader", params.parent)
        listFrame.bagshuiData.columnHeaders[col.field] = columnFrame

        columnFrame.bagshuiData = {
          listFrame = listFrame,
          columnNum = i,
          columnParams = col,
          text = self:CreateShadowedFontString(columnFrame, nil, "GameFontNormalSmall"),
        }

        columnFrame.bagshuiData.text:SetText(col.title or col.name or col.field)

        -- headerHeight is used by `Ui:SetPoint()` to account for headers when
        -- setting the top point of the scrollFrame.
        if scrollFrame.bagshuiData.headerHeight == 0 and not params.hideColumnHeaders then
          scrollFrame.bagshuiData.headerHeight = columnFrame.bagshuiData.text:GetHeight() + 2
        end

        -- Formatting.
        columnFrame.bagshuiData.text:SetJustifyH("LEFT")
        columnFrame.bagshuiData.text:SetJustifyV("MIDDLE")
        columnFrame.bagshuiData.text:SetPoint("TOPLEFT", columnFrame, COLUMN_SPACING, 0)
        columnFrame.bagshuiData.text:SetPoint("BOTTOMRIGHT", columnFrame, -COLUMN_SPACING, 0)

        -- Calculate width and set size/position.
        local columnWidth = col.width or (scrollFrame:GetWidth() * (col.widthPercent / 100))
        params.entryColumns[i].actualWidth = columnWidth - 10
        columnFrame:SetWidth(columnWidth)
        columnFrame:SetHeight(scrollFrame.bagshuiData.headerHeight)
        columnFrame:SetPoint("BOTTOMLEFT", nextAnchorToFrame, nextAnchorToPoint, 0, 1)

        columnFrame:SetScript("OnClick", self._scrollableList_SetSortOrder)

        nextAnchorToFrame = columnFrame
        nextAnchorToPoint = "BOTTOMRIGHT"
      end

      -- Set initial column header state.
      self:UpdateScrollableListColumnHeaders(listFrame)
    end

    -- Create search box
    if not params.noSearchBox then
      local searchBox = self:CreateSearchBox(
        params.namePrefix .. "SearchBox",
        params.buttonAndSearchBoxParent or params.parent,
        nil, -- Width.
        nil, -- Height.
        function(searchBox) -- OnTextChanged.
          self:ShowScrollableListEntries(listFrame, searchBox.bagshuiData.searchText)
        end,
        nil, -- OnEnterPressed.
        nil, -- OnIconClick.
        params.searchPlaceholderText,
        0.15 -- OnTextChanged debounce (seconds).
      )
      listFrame.bagshuiData.searchBox = searchBox
    end

    -- Create buttons (add, remove, etc.).
    listFrame.bagshuiData.buttons = {}
    if type(params.buttons) == "table" then
      -- Reusable table.
      if not self._createScrollableList_ButtonParams then
        self._createScrollableList_ButtonParams = {}
      end

      local lastCreatedButton
      local buttonParams = self._createScrollableList_ButtonParams

      for _, button in ipairs(params.buttons) do
        if not button.skip then
          BsUtil.TableClear(buttonParams)
          local buttonName = button.scrollableList_ButtonName or button.name

          -- Set initial parameters if available.
          if Ui._createScrollableList_AvailableButtons[buttonName] then
            BsUtil.TableCopy(Ui._createScrollableList_AvailableButtons[buttonName], buttonParams)
          end
          for key, val in pairs(button) do
            buttonParams[key] = val
          end

          buttonParams.name = params.namePrefix .. buttonParams.name
          buttonParams.parentFrame = params.buttonAndSearchBoxParent or params.parent

          -- Adjust anchor as requested.
          if button.scrollableList_AnchorToScrollFrame then
            -- Need to anchor to background since that's the visual representation of the ScrollFrame.
            buttonParams.anchorToFrame = scrollFrame.bagshuiData.background
          elseif button.scrollableList_AnchorToSearchBox and listFrame.bagshuiData.searchBox then
            buttonParams.anchorToFrame = listFrame.bagshuiData.searchBox
          elseif button.scrollableList_AutomaticAnchor then
            buttonParams.anchorToFrame = lastCreatedButton or buttonParams.parentFrame
            buttonParams.anchorPoint = buttonParams.anchorPoint or "LEFT"
            buttonParams.anchorToPoint = buttonParams.anchorToPoint or (not lastCreatedButton and "LEFT" or "RIGHT")
          end

          -- Automatic Add and Copy button handling for Item lists.

          if listType == BS_UI_SCROLLABLE_LIST_TYPE.ITEM then
            if button.scrollableList_ButtonName == BS_UI_SCROLLABLE_LIST_BUTTON_NAME.ADD then
              buttonParams.onClick = function()
                self:ItemListPromptForNew(listFrame)
              end
            end

            if button.scrollableList_ButtonName == BS_UI_SCROLLABLE_LIST_BUTTON_NAME.SHARE then
              buttonParams.onClick = function()
                self:ItemListOpenCopyDialog(listFrame)
              end
            end
          end

          -- Remove, Up, and Down buttons always do the same thing.
          if button.scrollableList_ButtonName == BS_UI_SCROLLABLE_LIST_BUTTON_NAME.REMOVE then
            -- Temporary table for removals to avoid errors.
            -- Without this, pairs() can fail depending on the removal order.
            local scrollableList_EntriesToRemove = {}
            buttonParams.onClick = function()
              -- Build temporary list of entries to remove.
              BsUtil.TableClear(scrollableList_EntriesToRemove)
              for selectedEntry, _ in pairs(listFrame.bagshuiData.selectedEntries) do
                table.insert(scrollableList_EntriesToRemove, selectedEntry)
              end
              -- Perform removals.
              for _, selectedEntry in ipairs(scrollableList_EntriesToRemove) do
                self:ScrollableListRemove(listFrame, selectedEntry)
              end
              BsUtil.TableClear(scrollableList_EntriesToRemove)
            end
          end

          if
            button.scrollableList_ButtonName == BS_UI_SCROLLABLE_LIST_BUTTON_NAME.UP
            or button.scrollableList_ButtonName == BS_UI_SCROLLABLE_LIST_BUTTON_NAME.DOWN
          then
            local upDown = button.scrollableList_ButtonName
            buttonParams.onClick = function()
              self:ScrollableListMove(listFrame, listFrame.bagshuiData.selectedEntry, upDown)
            end
          end

          -- Pick up additional/override parameters.
          for param, value in pairs(button) do
            if param == "onClick" then
              local onClick = value
              buttonParams[param] = function()
                onClick(listFrame)
              end
            else
              buttonParams[param] = value
            end
          end

          -- Adjust X offset when this is the first button and automatic anchoring is enabled.
          if buttonParams.scrollableList_AutomaticAnchor and params.firstButtonXOffset and not lastCreatedButton then
            buttonParams.xOffset = params.firstButtonXOffset
          end

          -- Create button.
          listFrame.bagshuiData.buttons[buttonName] = self:CreateIconButton(buttonParams)
          listFrame.bagshuiData.buttons[buttonName].bagshuiData.listFrame = listFrame
          listFrame.bagshuiData.buttons[buttonName].bagshuiData.scrollableList_Disable = buttonParams.scrollableList_Disable
            or buttonParams.disable
          listFrame.bagshuiData.buttons[buttonName].bagshuiData.scrollableList_DisableFunc = buttonParams.scrollableList_DisableFunc
            or buttonParams.disableFunc
          for prop, val in pairs(buttonParams) do
            if string.find(prop, "^scrollableList_") then
              listFrame.bagshuiData.buttons[buttonName].bagshuiData[prop] = val
            end
          end

          lastCreatedButton = listFrame.bagshuiData.buttons[buttonName]
        end
      end
    end

    -- Rebind the viewport rows when scrolling or resizing. Preserve the
    -- ScrollFrame helpers installed by CreateScrollFrame().
    local oldOnVerticalScroll = scrollFrame:GetScript("OnVerticalScroll")
    scrollFrame:SetScript("OnVerticalScroll", function(frame, offset)
      if oldOnVerticalScroll then
        oldOnVerticalScroll(frame, offset)
      end
      self:RenderScrollableListViewport(listFrame)
    end)

    local oldOnSizeChanged = scrollFrame:GetScript("OnSizeChanged")
    scrollFrame:SetScript("OnSizeChanged", function(frame, ...)
      if oldOnSizeChanged then
        oldOnSizeChanged(frame, ...)
      end
      self:RenderScrollableListViewport(listFrame)
    end)

    local oldOnShow = scrollFrame:GetScript("OnShow")
    scrollFrame:SetScript("OnShow", function(frame, ...)
      if oldOnShow then
        oldOnShow(frame, ...)
      end
      self:RenderScrollableListViewport(listFrame)
    end)

    local oldOnHide = scrollFrame:GetScript("OnHide")
    scrollFrame:SetScript("OnHide", function(frame, ...)
      if oldOnHide then
        oldOnHide(frame, ...)
      end
      for _, entryFrame in ipairs(listFrame.bagshuiData.entryFrames) do
        self:UnregisterModifierKeyHoverTarget(entryFrame)
        entryFrame.bagshuiData.mouseIsOver = false
        if entryFrame.bagshuiData.itemButton then
          self:UnregisterModifierKeyHoverTarget(entryFrame.bagshuiData.itemButton)
          entryFrame.bagshuiData.itemButton.bagshuiData.mouseIsOver = false
        end
      end
    end)

    -- Same return values as CreateScrollableContent().
    return scrollFrame, scrollChild, listFrame
  end

  --- Build display/search information for one logical entry without allocating
  --- a row frame. Physical frames receive this information only when visible.
  local function BuildScrollableListLogicalEntry(listFrame, entry, sequentialFrameNum)
    local listType = listFrame.bagshuiData.scrollableListType
    local logicalEntry = {
      entry = entry,
      sequentialFrameNum = sequentialFrameNum,
      show = true,
    }

    if listType == BS_UI_SCROLLABLE_LIST_TYPE.ITEM then
      logicalEntry.entryInfo = {}
      BsItemInfo:InitializeItem(logicalEntry.entryInfo, true)
      if type(entry) == "table" then
        BsUtil.TableCopy(entry, logicalEntry.entryInfo)
      else
        BsItemInfo:Get(entry, logicalEntry.entryInfo, true, false, true)
      end
      if string.len(logicalEntry.entryInfo.name or "") == 0 then
        listFrame.bagshuiData.hasUnknownItems = true
        BsItemInfo:LoadItemIntoLocalGameCache(entry)
        logicalEntry.entryInfo.name = L.Unknown .. " (" .. tostring(entry) .. ")"
      end
      logicalEntry.primaryText = logicalEntry.entryInfo.name
    else
      logicalEntry.entryInfo = entry
      if listFrame.bagshuiData.entryInfoFunc then
        logicalEntry.entryInfo = listFrame.bagshuiData.entryInfoFunc(
          entry,
          listFrame.bagshuiData.entryFrameCallbacksExtraParam
        )
      end
      if type(logicalEntry.entryInfo) == "table" then
        logicalEntry.primaryText = logicalEntry.entryInfo[listFrame.bagshuiData.entryDisplayProperty]
        if listFrame.bagshuiData.entryColumnTextFunc then
          logicalEntry.primaryText = listFrame.bagshuiData.entryColumnTextFunc(
            listFrame.bagshuiData.entryDisplayProperty,
            entry,
            logicalEntry.entryInfo,
            logicalEntry.primaryText,
            listFrame.bagshuiData.entryFrameCallbacksExtraParam
          )
        end
        logicalEntry.isHeader = logicalEntry.entryInfo.scrollableList_Header
      else
        logicalEntry.primaryText = tostring(logicalEntry.entryInfo)
      end
      logicalEntry.normalizedSearchText = string.lower(BsUtil.RemoveUiEscapes(logicalEntry.primaryText or ""))
    end

    return logicalEntry
  end

  --- Fill or refresh a Bagshui scrollable list frame built by `CreateScrollableList()`.
  ---@param listFrame table `listFrame` return value from `Ui:CreateScrollableList()`.
  ---@param entries table? Array of list entry values.
  ---@param refresh boolean? When `entries` is nil, don't clear the list and just refresh it.
  ---@param preserveSelection boolean? Don't de-select the currently selected list entry.
  ---@param preserveSearch boolean? Don't clear search text.
  function Ui:PopulateScrollableList(listFrame, entries, refresh, preserveSelection, preserveSearch)
    assert(
      listFrame.bagshuiData.scrollableListType,
      "Ui:PopulateScrollableList(): Given listFrame is not a scrollable list"
    )

    if listFrame.bagshuiData.searchBox and not preserveSearch then
      listFrame.bagshuiData.searchBox:SetText("")
    end

    if entries then
      BsUtil.TableCopy(entries, listFrame.bagshuiData.entries)
    elseif not refresh and not listFrame.bagshuiData.refreshAfterUnknownItems then
      BsUtil.TableClear(listFrame.bagshuiData.entries)
    end

    listFrame.bagshuiData.hasUnknownItems = false
    listFrame.bagshuiData.hasHeaders = false
    BsUtil.TableClear(listFrame.bagshuiData.logicalEntries)

    local entryStart = 1
    local entryEnd = table.getn(listFrame.bagshuiData.entries)
    local entryStep = 1
    if listFrame.bagshuiData.sortOrder == "DESC" then
      entryStart = entryEnd
      entryEnd = 1
      entryStep = -1
    end

    local sequentialFrameNum = 1
    for i = entryStart, entryEnd, entryStep do
      local logicalEntry = BuildScrollableListLogicalEntry(
        listFrame,
        listFrame.bagshuiData.entries[i],
        sequentialFrameNum
      )
      logicalEntry.logicalIndex = sequentialFrameNum
      table.insert(listFrame.bagshuiData.logicalEntries, logicalEntry)
      if logicalEntry.isHeader then
        listFrame.bagshuiData.hasHeaders = true
      end
      sequentialFrameNum = sequentialFrameNum + 1
    end

    self:ShowScrollableListEntries(
      listFrame,
      (listFrame.bagshuiData.searchBox and listFrame.bagshuiData.searchBox.bagshuiData.searchText)
    )
    self:SetScrollableListSelection(listFrame, (preserveSelection and listFrame.bagshuiData.lastSelection or nil))

    if not listFrame.bagshuiData.refreshAfterUnknownItems then
      self:UpdateScrollableListColumnHeaders(listFrame)
      if listFrame.bagshuiData.onChangeFunc then
        listFrame.bagshuiData.onChangeFunc(listFrame.bagshuiData.entries, listFrame)
      end
    end

    if listFrame.bagshuiData.hasUnknownItems and not listFrame.bagshuiData.refreshAfterUnknownItems then
      listFrame.bagshuiData.hasUnknownItems = false
      listFrame.bagshuiData.refreshAfterUnknownItems = true
      Bagshui:QueueClassCallback(self, self.PopulateScrollableList, 0.5, false, listFrame, nil)
      return
    end

    listFrame.bagshuiData.refreshAfterUnknownItems = nil
  end

  --- Add content to a scrollable list entry frame.
  ---@param listFrame table `listFrame` return value from `Ui:CreateScrollableList()`.
  ---@param entryFrame table Frame from `GetAvailableScrollableListEntryFrame()`.
  ---@param entry any List entry pulled from the `entries` provided to `CreateScrollableList()`.
  function Ui:PopulateScrollableListEntry(listFrame, entryFrame, entry, logicalEntry)
    local listType = listFrame.bagshuiData.scrollableListType
    logicalEntry = logicalEntry or BuildScrollableListLogicalEntry(listFrame, entry, 1)
    local entryPrimaryText = logicalEntry.primaryText
    local entryInfo = logicalEntry.entryInfo
    local textFrames = entryFrame.bagshuiData.textFrames
    entryFrame.bagshuiData.isHeader = logicalEntry.isHeader or false
    entryFrame.bagshuiData.logicalEntry = logicalEntry
    entryFrame.bagshuiData.logicalIndex = logicalEntry.logicalIndex
    entryFrame.bagshuiData.sequentialFrameNum = logicalEntry.sequentialFrameNum

    if listType == BS_UI_SCROLLABLE_LIST_TYPE.ITEM then
      local itemInfo = entryFrame.bagshuiData.itemButton.bagshuiData.item
      BsItemInfo:InitializeItem(itemInfo, true)
      BsUtil.TableCopy(entryInfo, itemInfo)
      entryInfo = itemInfo
      self:AssignItemToItemButton(entryFrame.bagshuiData.itemButton, entryInfo)
    end

    -- Store entry information so it's accessible elsewhere.
    entryFrame.bagshuiData.scrollableListEntry = entry
    entryFrame.bagshuiData.scrollableListEntryInfo = entryInfo

    -- Set primary text.
    textFrames[1]:SetText(entryPrimaryText)

    -- Track which column frames to hide. Start at 2 since the first text frame is always visible.
    local frameHideStart = 2

    if listFrame.bagshuiData.entryColumns then
      -- This list has multiple columns.

      local nextAnchorToFrame = textFrames[1]

      for i, col in ipairs(listFrame.bagshuiData.entryColumns) do
        local columnWidth = col.actualWidth

        if i == 1 then
          -- The first frame has already been populated above and we just
          -- need to adjust the width.
          columnWidth = columnWidth - entryFrame.bagshuiData.widthOffset
        else
          -- Add another column text frame if needed.
          if not textFrames[i] then
            textFrames[i] = self:CreateShadowedFontString(entryFrame)
          end

          -- Get text and populate the frame.

          local columnText = entryInfo[col.field] ~= nil and tostring(entryInfo[col.field]) or ""
          if listFrame.bagshuiData.entryColumnTextFunc then
            columnText = listFrame.bagshuiData.entryColumnTextFunc(col.field, entry, entryInfo, columnText)
          end

          textFrames[i]:SetText(columnText)
          textFrames[i]:SetPoint("LEFT", nextAnchorToFrame, "RIGHT", 10, 0)
          textFrames[i]:SetJustifyH(col.align or "LEFT")

          nextAnchorToFrame = textFrames[i]
        end

        textFrames[i]:SetWidth(columnWidth)
        textFrames[i]:SetFontObject(listFrame.bagshuiData.font)

        frameHideStart = frameHideStart + 1
      end
    else
      -- Single column.
      textFrames[1]:SetWidth(listFrame:GetWidth() - entryFrame.bagshuiData.widthOffset)
    end

    -- Various other parts of ScrollableList need to know whether any headers exist.
    if entryFrame.bagshuiData.isHeader then
      listFrame.bagshuiData.hasHeaders = true
    end

    -- Hide unused frames.
    for i = frameHideStart, table.getn(textFrames) do
      textFrames[i]:Hide()
    end

    -- Show/hide checkboxes and apply header styling as needed.
    self:UpdateScrollableListEntryFrame(listFrame, entryFrame)

    -- Custom callback.
    if listFrame.bagshuiData.entryFramePopulateFunc then
      listFrame.bagshuiData.entryFramePopulateFunc(
        listFrame,
        entryFrame,
        entry,
        self,
        listFrame.bagshuiData.entryFrameCallbacksExtraParam
      )
    end

    -- Cache normalized text after all population callbacks have run. The row
    -- frame can be reused, so only keep the cached value when its displayed
    -- source text is unchanged.
    if listType ~= BS_UI_SCROLLABLE_LIST_TYPE.ITEM then
      local searchableText = textFrames[1]:GetText() or ""
      if entryFrame.bagshuiData.searchableText ~= searchableText then
        entryFrame.bagshuiData.searchableText = searchableText
        entryFrame.bagshuiData.normalizedSearchText = string.lower(BsUtil.RemoveUiEscapes(searchableText))
      end
    end
  end

  -- Filter the logical data set and calculate row offsets. No physical frame is
  -- created here; RenderScrollableListViewport() binds only viewport rows.
  ---@param listFrame table
  ---@param searchText string?
  function Ui:ShowScrollableListEntries(listFrame, searchText)
    local listType = listFrame.bagshuiData.scrollableListType
    local logicalEntries = listFrame.bagshuiData.logicalEntries
    local visibleEntries = listFrame.bagshuiData.visibleEntries
    BsUtil.TableClear(visibleEntries)

    local normalizedSearch
    if searchText and listType ~= BS_UI_SCROLLABLE_LIST_TYPE.ITEM then
      normalizedSearch = string.lower(searchText)
    end

    for _, logicalEntry in ipairs(logicalEntries) do
      logicalEntry.show = true
      if searchText then
        if listType == BS_UI_SCROLLABLE_LIST_TYPE.ITEM then
          logicalEntry.show = BsRules:Match(searchText, logicalEntry.entryInfo, nil, nil, true)
        else
          logicalEntry.show = string.find(
            logicalEntry.normalizedSearchText or "",
            normalizedSearch,
            1,
            true
          ) ~= nil
        end
      end
    end

    -- A header remains visible only when at least one child before the next
    -- header survived filtering.
    if listFrame.bagshuiData.hasHeaders then
      local header
      local headerHasVisibleChild = false
      for _, logicalEntry in ipairs(logicalEntries) do
        if logicalEntry.isHeader then
          if header then
            header.show = headerHasVisibleChild
          end
          header = logicalEntry
          headerHasVisibleChild = false
        elseif header and logicalEntry.show then
          headerHasVisibleChild = true
        end
      end
      if header then
        header.show = headerHasVisibleChild
      end
    end

    local rowHeight = listFrame.bagshuiData.rowHeight
    local rowSpacing = listFrame.bagshuiData.rowSpacing
    local nextTop = 5
    for _, logicalEntry in ipairs(logicalEntries) do
      if logicalEntry.show then
        if table.getn(visibleEntries) > 0 and logicalEntry.isHeader then
          nextTop = nextTop + HEADER_SPACING
        end
        logicalEntry.top = nextTop
        logicalEntry.height = rowHeight + (logicalEntry.isHeader and 1 or 0)
        table.insert(visibleEntries, logicalEntry)
        nextTop = nextTop + logicalEntry.height + rowSpacing
      else
        logicalEntry.top = nil
      end
    end

    listFrame.bagshuiData.scrollChild:SetHeight(math.max(nextTop + 5, 1))
    self:RenderScrollableListViewport(listFrame, true)
  end

  --- Clear state which must never survive a physical row being recycled.
  local function UnbindScrollableListEntryFrame(entryFrame)
    if entryFrame.bagshuiData.itemButton then
      Ui:UnregisterModifierKeyHoverTarget(entryFrame.bagshuiData.itemButton)
      entryFrame.bagshuiData.itemButton.bagshuiData.mouseIsOver = false
      Bagshui:HideTooltips(entryFrame.bagshuiData.itemButton)
    end
    Ui:UnregisterModifierKeyHoverTarget(entryFrame)
    entryFrame.bagshuiData.mouseIsOver = false
    Bagshui:HideTooltips(entryFrame)
    entryFrame.bagshuiData.logicalEntry = nil
    entryFrame.bagshuiData.logicalIndex = nil
    entryFrame.bagshuiData.scrollableListEntry = nil
    entryFrame:Hide()
  end

  --- Bind a pooled physical frame to one logical row.
  local function BindScrollableListEntryFrame(listFrame, entryFrame, logicalEntry)
    local ui = listFrame.bagshuiData.ui
    UnbindScrollableListEntryFrame(entryFrame)
    entryFrame.bagshuiData.listFrame = listFrame
    if entryFrame.bagshuiData.itemButton then
      entryFrame.bagshuiData.itemButton.bagshuiData.listFrame = listFrame
    end

    ui:PopulateScrollableListEntry(listFrame, entryFrame, logicalEntry.entry, logicalEntry)

    local onMouseDown
    if listFrame.bagshuiData.selectable then
      entryFrame:RegisterForClicks("LeftButtonUp")
      onMouseDown = ui._scrollableList_SetSelection
    else
      entryFrame:RegisterForClicks(nil)
    end
    entryFrame:SetScript("OnMouseDown", onMouseDown)
    if entryFrame.bagshuiData.itemButton then
      entryFrame.bagshuiData.itemButton:SetScript("OnMouseDown", onMouseDown)
    end
    entryFrame:SetScript("OnDoubleClick", listFrame.bagshuiData.onDoubleClickFunc)

    entryFrame:ClearAllPoints()
    entryFrame:SetParent(listFrame)
    entryFrame:SetPoint("TOPLEFT", listFrame, "TOPLEFT", 0, -logicalEntry.top)
    entryFrame:SetWidth(listFrame.bagshuiData.scrollChild:GetWidth())
    entryFrame:SetHeight(logicalEntry.height)

    ui:SetScrollableListEntrySelectionState(
      listFrame,
      entryFrame,
      listFrame.bagshuiData.selectedEntries[logicalEntry.entry] == true
    )
    if entryFrame.bagshuiData.checkbox then
      entryFrame.bagshuiData.checkbox.bagshuiData.listFrame = listFrame
      entryFrame.bagshuiData.checkbox.bagshuiData.entryFrame = entryFrame
      if logicalEntry.dependencyLocked then
        entryFrame.bagshuiData.checkbox:Disable()
      else
        entryFrame.bagshuiData.checkbox:Enable()
      end
    end

    if entryFrame.bagshuiData.itemButton then
      entryFrame.bagshuiData.itemButton:SetFrameLevel(entryFrame:GetFrameLevel() + 5)
    end
    if entryFrame.bagshuiData.checkbox and entryFrame.bagshuiData.checkbox:IsShown() then
      entryFrame.bagshuiData.checkbox:SetFrameLevel(entryFrame:GetFrameLevel() + 5)
    end
    entryFrame:Show()
  end

  --- Rebind the bounded row pool to the current viewport.
  ---@param listFrame table
  ---@param resetScroll boolean? Return to the top (used after filtering/repopulation).
  function Ui:RenderScrollableListViewport(listFrame, resetScroll)
    if not listFrame or not listFrame.bagshuiData or not listFrame.bagshuiData.visibleEntries then
      return
    end

    local scrollFrame = listFrame.bagshuiData.scrollFrame
    local visibleEntries = listFrame.bagshuiData.visibleEntries
    local entryFrames = listFrame.bagshuiData.entryFrames
    if resetScroll and (scrollFrame:GetVerticalScroll() or 0) ~= 0 then
      scrollFrame:SetVerticalScroll(0)
    end

    local scrollOffset = scrollFrame:GetVerticalScroll() or 0
    local viewportHeight = scrollFrame:GetHeight() or 0
    local overscan = 2
    local low, high = 1, table.getn(visibleEntries)
    while low <= high do
      local middle = math.floor((low + high) / 2)
      local logicalEntry = visibleEntries[middle]
      if logicalEntry.top + logicalEntry.height < scrollOffset then
        low = middle + 1
      else
        high = middle - 1
      end
    end
    local first = math.max(1, math.min(low, table.getn(visibleEntries)) - overscan)

    local last = first - 1
    local viewportBottom = scrollOffset + math.max(viewportHeight, listFrame.bagshuiData.rowHeight)
    while last < table.getn(visibleEntries) do
      local candidate = visibleEntries[last + 1]
      if last >= first and candidate.top > viewportBottom and (last - first + 1) >= overscan then
        break
      end
      last = last + 1
    end
    last = math.min(table.getn(visibleEntries), last + overscan)
    local needed = math.max(0, last - first + 1)

    while table.getn(entryFrames) < needed do
      local entryFrame = self:GetAvailableScrollableListEntryFrame(
        listFrame,
        listFrame.bagshuiData.scrollableListType,
        listFrame.bagshuiData.entryFrameCreationFunc
      )
      entryFrame.bagshuiData.listFrame = listFrame
      table.insert(entryFrames, entryFrame)
    end
    while table.getn(entryFrames) > needed do
      local entryFrame = table.remove(entryFrames)
      UnbindScrollableListEntryFrame(entryFrame)
      self:ReleaseScrollableListFrames({ entryFrame })
    end

    for frameIndex = 1, needed do
      local logicalEntry = visibleEntries[first + frameIndex - 1]
      BindScrollableListEntryFrame(listFrame, entryFrames[frameIndex], logicalEntry)
    end
  end

  --- Reusable OnEnter function for item list entry frames, used in `GetAvailableScrollableListEntryFrame()`.
  ---@param targetEntryFrame table Entry frame.
  ---@param fromChildElement boolean? This is being called as a result of the mouse entering an associated child element like and item button or checkbox (explained in the comment above `if fromChildElement then...`).
  ---@param modifierKeyRefresh boolean? Updating because there was a modifier key change.
  local function ScrollableListEntryFrame_OnEnter(targetEntryFrame, fromChildElement, modifierKeyRefresh)
    local this = targetEntryFrame

    this.bagshuiData.mouseIsOver = true

    -- Register with the shared modifier-key controller so this row's
    -- `entryOnEnterFunc` gets refreshed when Alt/Ctrl/Shift are pressed or
    -- released while the mouse is over the row (item list tooltips are
    -- handled by the item button's own registration). `modifierKeyRefresh`
    -- refreshes are triggered by the controller itself, so the row is already
    -- registered.
    if not modifierKeyRefresh then
      Ui:RegisterModifierKeyHoverTarget(this, function()
        ScrollableListEntryFrame_OnEnter(this, false, true)
      end)
    end

    if not modifierKeyRefresh then
      -- Coordinate OnEnter with the item slot button so that mousing over the
      -- list entry triggers the hover state for the item slot button.
      -- See `ItemButton_OnEnter()` for the other side.
      if fromChildElement then
        this:LockHighlight()
      elseif this.bagshuiData.checkbox then
        this.bagshuiData.checkbox:GetScript("OnEnter")(this.bagshuiData.checkbox, true)
      elseif this.bagshuiData.itemButton then
        this.bagshuiData.itemButton:GetScript("OnEnter")(this.bagshuiData.itemButton, true)
      end
    end

    if type(this.bagshuiData.listFrame.bagshuiData.entryOnEnterFunc) == "function" then
      this.bagshuiData.listFrame.bagshuiData.entryOnEnterFunc(this)
    end
  end

  --- Reusable OnLeave function for item list entry frames, used in `GetAvailableScrollableListEntryFrame()`.
  ---@param targetEntryFrame table Entry frame.
  ---@param fromChildElement boolean? This is being called as a result of the mouse leaving an associated child element like and item button or checkbox (explained in the comment above `if fromItemButton then...`).
  local function ScrollableListEntryFrame_OnLeave(targetEntryFrame, fromChildElement)
    local this = targetEntryFrame

    this.bagshuiData.mouseIsOver = false
    Ui:UnregisterModifierKeyHoverTarget(this)

    -- Coordinate OnLeave with the item slot button so that the mouse leaving the
    -- list entry removes the hover state for the item slot button.
    -- See `ItemButton_OnLeave()` for the other side.
    if fromChildElement then
      if not this.bagshuiData.selected then
        this:UnlockHighlight()
      end
    elseif this.bagshuiData.checkbox then
      this.bagshuiData.checkbox:GetScript("OnLeave")(this.bagshuiData.checkbox, true)
    elseif this.bagshuiData.itemButton then
      this.bagshuiData.itemButton:GetScript("OnLeave")(this.bagshuiData.itemButton, true)
    end

    if this.bagshuiData.listFrame and type(this.bagshuiData.listFrame.bagshuiData.entryOnLeaveFunc) == "function" then
      this.bagshuiData.listFrame.bagshuiData.entryOnLeaveFunc(this)
    end
  end

  --- Obtain an item list frame, either by reusing an available one or creating new if needed.
  ---@param listFrame table `listFrame` return value from `Ui:CreateScrollableList()`.
  ---@param listType BS_UI_SCROLLABLE_LIST_TYPE
  ---@param entryFrameCreationFunc function? Callback that can be used to modify the entry frame after creation.
  ---@return table entryFrame
  function Ui:GetAvailableScrollableListEntryFrame(listFrame, listType, entryFrameCreationFunc)
    -- This is where we'll store frames so they can be reused.
    -- The stringified pointer to the `entryFrameCreationFunc` is tagged on the end so that
    -- customized frames are stored separately.
    local listFrameTableName = listType .. (entryFrameCreationFunc and tostring(entryFrameCreationFunc) or "")

    -- Ensure frame storage table exists.
    if not self._reusableListFrames[listFrameTableName] then
      self._reusableListFrames[listFrameTableName] = {}
    end

    -- Find a reusable frame if we can.
    local reusableFrameTable = self._reusableListFrames[listFrameTableName]
    assert(reusableFrameTable, "Failed to find entry frame table " .. listFrameTableName .. " (this shouldn't happen!)")

    -- Each pool keeps a "next free" cursor: every frame before `nextFree` is
    -- currently assigned to an open list, so the scan starts there instead of
    -- at index 1. The cursor only ever moves forward while frames are being
    -- acquired and is moved back by `Ui:ReleaseScrollableListFrames()` when a
    -- frame it has already passed is released. Rebuilding a list of N rows
    -- therefore performs O(N) total scan work instead of O(N^2), while still
    -- finding the same frame -- in the same order -- that a full linear scan
    -- from index 1 would have found.
    for i = reusableFrameTable.nextFree or 1, table.getn(reusableFrameTable) do
      if not reusableFrameTable[i].bagshuiData.listFrame then
        reusableFrameTable.nextFree = i + 1
        -- Bagshui:PrintDebug("reusing " .. listFrameTableName .. i)
        return reusableFrameTable[i]
      end
    end

    -- Bagshui:PrintDebug("creating new " .. listFrameTableName)

    -- Nothing found - create a new frame.

    local entryFrameNum = table.getn(reusableFrameTable) + 1
    local entryFrameName = "Reusable" .. listType .. "Frame" .. entryFrameNum
    local entryFrame = _G.CreateFrame("Button", entryFrameName, _G.UIParent)
    entryFrame.bagshuiData = {
      scrollableListEntry = nil, -- Will be filled by `PopulateScrollableList()`.
      textFrames = {},
      -- Reverse lookup used by `Ui:ReleaseScrollableListFrames()` to update
      -- this frame's pool `nextFree` cursor. The frame's index in the pool
      -- never changes because frames are only ever appended, never removed.
      reusableFramePool = reusableFrameTable,
      reusableFramePoolIndex = entryFrameNum,
    }
    self:SetFrameBackdrop(entryFrame, "NONE")
    entryFrame:SetBackdropColor(0, 0, 0, 0)
    entryFrame:SetHitRectInsets(-1, -1, -1, -1)
    -- Header background.
    entryFrame:SetNormalTexture("Interface\\QuestFrame\\UI-QuestLogTitleHighlight")
    entryFrame:GetNormalTexture():SetBlendMode("ADD")
    entryFrame:GetNormalTexture():SetAlpha(0)
    entryFrame:GetNormalTexture():SetVertexColor(0.5, 0.5, 0)
    -- Highlight background.
    entryFrame:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    entryFrame:GetHighlightTexture():SetBlendMode("ADD")
    -- Default opacity for mouseover highlight. This also gets reset in `SetScrollableListSelection()`.
    entryFrame:GetHighlightTexture():SetAlpha(0.5)

    local text = self:CreateShadowedFontString(entryFrame)
    entryFrame.bagshuiData.textFrames[1] = text
    text:SetPoint("LEFT", entryFrame, "LEFT", COLUMN_SPACING, 0)
    -- Consumed by `Ui:GetAvailableScrollableListEntryFrame()` to figure out how wide the text frame(s) should be.
    entryFrame.bagshuiData.widthOffset = 5

    -- Coordinate OnEnter/OnLeave with child elements.
    entryFrame:SetScript("OnEnter", ScrollableListEntryFrame_OnEnter)
    entryFrame:SetScript("OnLeave", ScrollableListEntryFrame_OnLeave)

    if listType == BS_UI_SCROLLABLE_LIST_TYPE.ITEM then
      -- Item lists require more work.

      local itemButtonMargin = 5 + BsSkin.itemSlotMarginFudge

      -- Create item slot button.
      -- Intentionally using `Ui` here instead of `self` so the name is `ReusableItemListFrame<Number>ItemSlotButton`.
      local itemButton = Ui:CreateItemSlotButton(entryFrameName .. "ItemSlotButton", entryFrame)
      entryFrame.bagshuiData.itemButton = itemButton
      itemButton:SetPoint("LEFT", entryFrame, "LEFT", itemButtonMargin, 0)
      itemButton.bagshuiData.item = {} -- Will be filled by PopulateScrollableList()
      itemButton.bagshuiData.entryFrame = entryFrame
      itemButton.bagshuiData.tooltipAnchor = "ANCHOR_PRESERVE"
      itemButton.bagshuiData.tooltipAnchorPoint = "TOPRIGHT"
      itemButton.bagshuiData.tooltipAnchorToPoint = "TOPLEFT"
      itemButton.bagshuiData.tooltipXOffset = -(3 + BsSkin.tooltipExtraOffset)
      itemButton.bagshuiData.tooltipYOffset = 3
      itemButton.bagshuiData.showBagshuiInfoWithoutAlt = true
      itemButton.bagshuiData.colorBorders = true
      -- Avoid highlighting the item button on click since it's already selecting the row.
      itemButton.bagshuiData.buttonComponents.pushedTexture:SetTexture("")

      -- Move left anchor of label.
      text:SetPoint("LEFT", entryFrame.bagshuiData.itemButton, "RIGHT", itemButtonMargin - 2, 0)
      entryFrame.bagshuiData.widthOffset = entryFrame.bagshuiData.widthOffset
        + entryFrame.bagshuiData.itemButton:GetWidth()
        + itemButtonMargin

      -- Set default height and handle future size changes.
      -- Height is updated when the frame is displayed by `ShowScrollableListEntries()`.
      entryFrame:SetScript("OnSizeChanged", function(frame)
        self:SetItemButtonSize(itemButton, frame:GetHeight() - 2)
      end)
      entryFrame:SetHeight(30)
    else
      -- All other list types are much simpler.
      -- Set the default height (updated when the frame is displayed by `ShowScrollableListEntries()`).
      entryFrame:SetHeight(18)

      -- Custom events are handled in ScrollableListEntryFrame_OnEnter/OnLeave.
    end

    -- Custom callback.
    if entryFrameCreationFunc then
      entryFrameCreationFunc(entryFrameName, entryFrame, self)
    end

    -- Save to reusable frame list.
    table.insert(reusableFrameTable, entryFrame)
    -- The new frame is being assigned immediately, so every frame up to and
    -- including it is now in use.
    reusableFrameTable.nextFree = entryFrameNum + 1

    return entryFrame
  end

  --- Reusable OnEnter function for item list entry frames, applied in `Ui:UpdateScrollableListEntryFrame()`.
  ---@param this table Checkbox frame.
  ---@param fromEntryFrame boolean? This is being called as a result of the mouse entering an associated list entry frame.
  local function ScrollableListCheckbox_OnEnter(this, fromEntryFrame)
    if fromEntryFrame then
      this:LockHighlight()
    else
      this.bagshuiData.entryFrame:GetScript("OnEnter")(this.bagshuiData.entryFrame, true)
    end
  end

  --- Reusable OnLeave function for item list entry frames, applied in `Ui:UpdateScrollableListEntryFrame()`.
  ---@param this table Checkbox frame.
  ---@param fromEntryFrame boolean? This is being called as a result of the mouse leaving an associated list entry frame.
  local function ScrollableListCheckbox_OnLeave(this, fromEntryFrame)
    if fromEntryFrame then
      this:UnlockHighlight()
    else
      this.bagshuiData.entryFrame:GetScript("OnLeave")(this.bagshuiData.entryFrame, true)
    end
  end

  --- Reusable OnClick function for item list entry frames, applied in `Ui:UpdateScrollableListEntryFrame()`.
  local ScrollableListCheckbox_OnClick

  --- Add checkboxes and header styling to entries.
  ---@param listFrame table `listFrame` return value from `Ui:CreateScrollableList()`.
  ---@param entryFrame table List entry frame from `Ui:GetAvailableScrollableListEntryFrame()`.
  function Ui:UpdateScrollableListEntryFrame(listFrame, entryFrame)
    -- Special styling isn't currently supported for item lists.
    if listFrame.bagshuiData.scrollableListType == BS_UI_SCROLLABLE_LIST_TYPE.ITEM then
      return
    end

    -- Grab the default text color so we can reapply it in when frames switch
    -- between header and non-header mode.
    if not listFrame.bagshuiData.textColorR then
      listFrame.bagshuiData.textColorR, listFrame.bagshuiData.textColorG, listFrame.bagshuiData.textColorB, listFrame.bagshuiData.textColorA =
        entryFrame.bagshuiData.textFrames[1]:GetTextColor()
    end

    if type(ScrollableListCheckbox_OnClick) ~= "function" then
      -- Reusable function for checkbox OnClick.
      function ScrollableListCheckbox_OnClick(checkbox)
        self:SetScrollableListSelection(checkbox.bagshuiData.listFrame, checkbox.bagshuiData.entryFrame)
      end
    end

    if
      listFrame.bagshuiData.checkboxes
      and (
        not entryFrame.bagshuiData.isHeader
        or (entryFrame.bagshuiData.isHeader and listFrame.bagshuiData.headerCheckboxes ~= false)
      )
    then
      -- Create checkbox.
      if not entryFrame.bagshuiData.checkbox then
        entryFrame.bagshuiData.checkbox = self:CreateCheckbox(
          entryFrame:GetName() .. "Checkbox",
          entryFrame, -- Parent.
          nil, -- Template.
          nil, -- Text.
          ScrollableListCheckbox_OnClick
        )
        entryFrame.bagshuiData.checkbox.bagshuiData.listFrame = listFrame
        entryFrame.bagshuiData.checkbox.bagshuiData.entryFrame = entryFrame
        entryFrame.bagshuiData.checkbox:SetScript("OnEnter", ScrollableListCheckbox_OnEnter)
        entryFrame.bagshuiData.checkbox:SetScript("OnLeave", ScrollableListCheckbox_OnLeave)
        entryFrame.bagshuiData.checkbox:Hide()
      end

      -- Display checkbox.
      if not entryFrame.bagshuiData.checkbox:IsShown() then
        entryFrame.bagshuiData.checkbox:Show()
        entryFrame.bagshuiData.checkbox:SetHeight(entryFrame:GetHeight() + 2)
        entryFrame.bagshuiData.checkbox:SetWidth(entryFrame:GetHeight() + 2)
      end

      -- Update checkbox and text position.
      entryFrame.bagshuiData.checkbox:ClearAllPoints()

      if entryFrame.bagshuiData.isHeader then
        -- Checkboxes for headers are positioned on the right.
        -- entryFrame.bagshuiData.checkbox:SetPoint("RIGHT", entryFrame, "RIGHT", 0, 0)
        self:SetPoint(entryFrame.bagshuiData.checkbox, "RIGHT", entryFrame, "RIGHT", 0, nil)
        entryFrame.bagshuiData.textFrames[1]:SetPoint("LEFT", entryFrame, "LEFT", COLUMN_SPACING, 0)
        entryFrame.bagshuiData.textFrames[1]:SetPoint(
          "RIGHT",
          entryFrame.bagshuiData.checkbox,
          "LEFT",
          -COLUMN_SPACING,
          0
        )
      else
        entryFrame.bagshuiData.checkbox:SetPoint("LEFT", entryFrame, "LEFT", 0, 0)
        -- self:SetPoint(entryFrame.bagshuiData.checkbox, "LEFT", entryFrame, "LEFT", 0, nil)
        entryFrame.bagshuiData.textFrames[1]:SetPoint("LEFT", entryFrame.bagshuiData.checkbox, "RIGHT", 0, 0)
        entryFrame.bagshuiData.textFrames[1]:SetPoint("RIGHT", entryFrame, "RIGHT", -COLUMN_SPACING, 0)
      end
    elseif entryFrame.bagshuiData.checkbox then
      entryFrame.bagshuiData.checkbox:Hide()
      entryFrame.bagshuiData.textFrames[1]:SetPoint("LEFT", entryFrame, "LEFT", COLUMN_SPACING, 0)
      entryFrame.bagshuiData.textFrames[1]:SetPoint("RIGHT", entryFrame, "RIGHT", -COLUMN_SPACING, 0)
    end

    -- Apply header or normal styling.
    if entryFrame.bagshuiData.isHeader then
      -- Display background.
      entryFrame:GetNormalTexture():SetAlpha(0.7)

      -- Change fonts.
      if not listFrame.bagshuiData.headerFontPath then
        entryFrame.bagshuiData.textFrames[1]:SetFontObject(listFrame.bagshuiData.headerFont)
        listFrame.bagshuiData.headerFontPath, listFrame.bagshuiData.headerFontSize, listFrame.bagshuiData.headerFontStyle =
          entryFrame.bagshuiData.textFrames[1]:GetFont()
        listFrame.bagshuiData.headerFontSize = math.floor(listFrame.bagshuiData.headerFontSize) + 2
        listFrame.bagshuiData.headerTextColorR, listFrame.bagshuiData.headerTextColorG, listFrame.bagshuiData.headerTextColorB, listFrame.bagshuiData.headerTextColorA =
          entryFrame.bagshuiData.textFrames[1]:GetTextColor()
      end
      entryFrame.bagshuiData.textFrames[1]:SetFont(
        listFrame.bagshuiData.headerFontPath,
        listFrame.bagshuiData.headerFontSize,
        listFrame.bagshuiData.headerFontStyle
      )
      entryFrame.bagshuiData.textFrames[1]:SetTextColor(
        listFrame.bagshuiData.headerTextColorR,
        listFrame.bagshuiData.headerTextColorG,
        listFrame.bagshuiData.headerTextColorB,
        listFrame.bagshuiData.headerTextColorA
      )
    else
      entryFrame.bagshuiData.textFrames[1]:SetFontObject(listFrame.bagshuiData.font)
      entryFrame.bagshuiData.textFrames[1]:SetTextColor(
        listFrame.bagshuiData.textColorR,
        listFrame.bagshuiData.textColorG,
        listFrame.bagshuiData.textColorB,
        listFrame.bagshuiData.textColorA
      )
      entryFrame:GetNormalTexture():SetAlpha(0)
    end
  end

  --- Select/deselect an item in a scrollable list.
  --- Two properties detailing the current selection state are exposed on the list's
  --- `bagshuiData` table: `selectedEntries` and `selectedEntry`. See the comments
  --- in `Ui:CreateScrollableList()` for more information.
  --- This could probably use a refactor at some point -- it's gotten messy since
  --- multi-select was added and there should be a way to pass a list of multiple
  --- entries to select/deselect.
  ---@param listFrame table `listFrame` return value from `Ui:CreateScrollableList()`.
  ---@param entryToSelect any? `entryFrame` UI element (or an element within one) *or* list entry value to select *or* nil to deselect.
  ---@param selectionState boolean? Force `entryToSelect` to be selected or deselected.
  ---@param scrollTo boolean? Scroll the list to the selected element when true.
  function Ui:SetScrollableListSelection(listFrame, entryToSelect, selectionState, scrollTo)
    local logicalEntries = listFrame.bagshuiData.logicalEntries
    local selectedEntries = listFrame.bagshuiData.selectedEntries
    local entryFrameToSelect
    local logicalEntryToSelect
    local entryToSelectWasFrame = false

    if type(entryToSelect) == "table" and entryToSelect.GetParent then
      entryFrameToSelect = entryToSelect
      while entryFrameToSelect ~= _G.UIParent
        and (not entryFrameToSelect.bagshuiData or not entryFrameToSelect.bagshuiData.logicalEntry)
      do
        entryFrameToSelect = entryFrameToSelect:GetParent()
      end
      logicalEntryToSelect = entryFrameToSelect.bagshuiData and entryFrameToSelect.bagshuiData.logicalEntry
      entryToSelectWasFrame = logicalEntryToSelect ~= nil
    elseif entryToSelect ~= nil then
      for _, logicalEntry in ipairs(logicalEntries) do
        if logicalEntry.entry == entryToSelect then
          logicalEntryToSelect = logicalEntry
          break
        end
      end
    end

    if entryToSelect ~= nil and not logicalEntryToSelect then
      Bagshui:PrintError("Failed to find selection for entry " .. tostring(entryToSelect) .. " -- this shouldn't happen!")
      return
    end

    listFrame.bagshuiData.lastSelection = logicalEntryToSelect and logicalEntryToSelect.entry or nil
    listFrame.bagshuiData._setScrollableListSelection_InProgress = true

    local forceSelect = selectionState == true
    local forceDeselect = selectionState == false
    local toggleSelection = _G.IsControlKeyDown()
      or (listFrame.bagshuiData.checkboxes and not _G.IsShiftKeyDown())
    local selectState = not forceDeselect

    if entryToSelectWasFrame then
      if listFrame.bagshuiData.multiSelect and _G.IsShiftKeyDown()
        and listFrame.bagshuiData.lastUserSelectionAnchorStart
      then
        if listFrame.bagshuiData.lastUserSelectionAnchorEnd then
          self:SetScrollableListSelectionRange(
            listFrame,
            listFrame.bagshuiData.lastUserSelectionAnchorStart,
            listFrame.bagshuiData.lastUserSelectionAnchorEnd,
            false
          )
        end
        selectState = listFrame.bagshuiData.lastUserSelectionAnchorWasSelected ~= false
        self:SetScrollableListSelectionRange(
          listFrame,
          logicalEntryToSelect.sequentialFrameNum,
          listFrame.bagshuiData.lastUserSelectionAnchorStart,
          selectState
        )
        listFrame.bagshuiData.lastUserSelectionAnchorEnd = logicalEntryToSelect.sequentialFrameNum
      else
        if not (listFrame.bagshuiData.multiSelect and toggleSelection) and not forceSelect and not forceDeselect then
          BsUtil.TableClear(selectedEntries)
        end
        if listFrame.bagshuiData.multiSelect and toggleSelection and not forceSelect and not forceDeselect then
          selectState = not selectedEntries[logicalEntryToSelect.entry]
        end
        selectedEntries[logicalEntryToSelect.entry] = selectState and true or nil
        listFrame.bagshuiData.lastUserSelectionAnchorStart = logicalEntryToSelect.sequentialFrameNum
        listFrame.bagshuiData.lastUserSelectionAnchorEnd = nil
        listFrame.bagshuiData.lastUserSelectionAnchorWasSelected = selectState
      end
    else
      if not (forceSelect or forceDeselect) then
        BsUtil.TableClear(selectedEntries)
      end
      listFrame.bagshuiData.lastUserSelectionAnchorStart = nil
      listFrame.bagshuiData.lastUserSelectionAnchorEnd = nil
      if logicalEntryToSelect then
        selectedEntries[logicalEntryToSelect.entry] = (not forceDeselect) and true or nil
      end
    end

    -- Header selection applies to all of its logical children, including rows
    -- currently filtered out or outside the viewport.
    if logicalEntryToSelect and logicalEntryToSelect.isHeader
      and listFrame.bagshuiData.multiSelect and listFrame.bagshuiData.headerCheckboxes ~= false
    then
      local headerState = selectedEntries[logicalEntryToSelect.entry] == true
      for i = logicalEntryToSelect.logicalIndex + 1, table.getn(logicalEntries) do
        if logicalEntries[i].isHeader then
          break
        end
        selectedEntries[logicalEntries[i].entry] = headerState and true or nil
      end
    end

    -- Synchronize each header with all of its children.
    local header
    local childCount = 0
    local selectedChildren = 0
    local function updateHeader()
      if header and childCount > 0 then
        selectedEntries[header.entry] = (selectedChildren == childCount) and true or nil
      end
    end
    for _, logicalEntry in ipairs(logicalEntries) do
      if logicalEntry.isHeader then
        updateHeader()
        header = logicalEntry
        childCount = 0
        selectedChildren = 0
      elseif header then
        childCount = childCount + 1
        if selectedEntries[logicalEntry.entry] then
          selectedChildren = selectedChildren + 1
        end
      end
    end
    updateHeader()

    local numSelectedEntries = BsUtil.TrueTableSize(selectedEntries)
    local readOnly = false
    local firstEntry = false
    local lastEntry = false
    for i, logicalEntry in ipairs(logicalEntries) do
      if selectedEntries[logicalEntry.entry] then
        if type(logicalEntry.entryInfo) == "table" and logicalEntry.entryInfo.readOnly then
          readOnly = true
        end
        firstEntry = firstEntry or i == 1
        lastEntry = lastEntry or i == table.getn(logicalEntries)
      end
    end

    if numSelectedEntries == 1 then
      for selectedEntry in pairs(selectedEntries) do
        listFrame.bagshuiData.selectedEntry = selectedEntry
      end
    else
      listFrame.bagshuiData.selectedEntry = nil
    end

    -- Refresh only the bound physical rows.
    for _, entryFrame in ipairs(listFrame.bagshuiData.entryFrames) do
      local logicalEntry = entryFrame.bagshuiData.logicalEntry
      self:SetScrollableListEntrySelectionState(
        listFrame,
        entryFrame,
        logicalEntry and selectedEntries[logicalEntry.entry] == true
      )
      if logicalEntry and logicalEntry.dependencyLocked and entryFrame.bagshuiData.checkbox then
        entryFrame.bagshuiData.checkbox:Disable()
      end
    end

    for _, button in pairs(listFrame.bagshuiData.buttons) do
      local enableDisableFunction = "Enable"
      if
        (numSelectedEntries < 1 and button.bagshuiData.scrollableList_DisableIfNothingSelected)
        or (numSelectedEntries > 1 and button.bagshuiData.scrollableList_DisableIfMultipleSelected)
        or (firstEntry and button.bagshuiData.scrollableList_DisableIfFirstEntrySelected)
        or (lastEntry and button.bagshuiData.scrollableList_DisableIfLastEntrySelected)
        or (readOnly and button.bagshuiData.scrollableList_DisableIfReadOnly)
        or (table.getn(logicalEntries) == 0 and button.bagshuiData.scrollableList_DisableIfEmptyList)
        or (type(button.bagshuiData.scrollableList_DisableFunc) == "function"
          and button.bagshuiData.scrollableList_DisableFunc(selectedEntries))
        or button.bagshuiData.scrollableList_Disable
      then
        enableDisableFunction = "Disable"
      end
      button[enableDisableFunction](button)
    end

    listFrame.bagshuiData._setScrollableListSelection_InProgress = false
    if not listFrame.bagshuiData.onSelectionChangedFunc_Called
      and type(listFrame.bagshuiData.onSelectionChangedFunc) == "function"
    then
      listFrame.bagshuiData.onSelectionChangedFunc_Called = true
      listFrame.bagshuiData.onSelectionChangedFunc(listFrame)
      listFrame.bagshuiData.onSelectionChangedFunc_Called = false
    end

    if scrollTo and logicalEntryToSelect then
      Bagshui:QueueClassCallback(self, self.ScrollToListEntry, 0.005, false, listFrame, logicalEntryToSelect.entry)
    end
  end

  --- Helper for `Ui:SetScrollableListSelection()` to update the selection state of an entry frame.
  ---@param listFrame table `listFrame` return value from `Ui:CreateScrollableList()`.
  ---@param entryFrame table Frame within the list that should be updated.
  ---@param select boolean? `true` to select, 'false' or `nil` to deselect.
  function Ui:SetScrollableListEntrySelectionState(listFrame, entryFrame, select)
    if select then
      entryFrame.bagshuiData.selected = true
      listFrame.bagshuiData.selectedEntries[entryFrame.bagshuiData.scrollableListEntry] = true
      entryFrame:GetHighlightTexture():SetAlpha(1)
      entryFrame:LockHighlight()
    else
      entryFrame.bagshuiData.selected = false
      listFrame.bagshuiData.selectedEntries[entryFrame.bagshuiData.scrollableListEntry] = nil
      entryFrame:UnlockHighlight()
      entryFrame:GetHighlightTexture():SetAlpha(0.5)
    end

    -- Sync checkbox state.
    if entryFrame.bagshuiData.checkbox then
      if listFrame.bagshuiData._setScrollableListSelection_InProgress then
        entryFrame.bagshuiData.checkbox:Enable()
      end
      entryFrame.bagshuiData.checkbox:SetChecked(entryFrame.bagshuiData.selected)
    end
  end

  --- Helper for `Ui:SetScrollableListSelection()` to select or deselect a range of frames.
  ---@param listFrame table `listFrame` return value from `Ui:CreateScrollableList()`.
  ---@param startNum number First frame to select or deselect. Can be a higher OR lower number than `endNum`.
  ---@param endNum number Last frame to select or deselect. Can be a higher OR lower number than `startNum`.
  ---@param select boolean? `true` to select, 'false' or `nil` to deselect.
  function Ui:SetScrollableListSelectionRange(listFrame, startNum, endNum, select)
    for i = startNum, endNum, (startNum < endNum and 1 or -1) do
      local logicalEntry = listFrame.bagshuiData.logicalEntries[i]
      if logicalEntry then
        listFrame.bagshuiData.selectedEntries[logicalEntry.entry] = (select == true) or nil
      end
    end
  end

  --- Scroll the ScrollFrame so the currently selected list item is visible.
  ---@param listFrame table `listFrame` return value from `Ui:CreateScrollableList()`.
  ---@param entry any Value from the list's `bagshuiData.entries` array to scroll to, OR frame to scroll to.
  function Ui:ScrollToListEntry(listFrame, entry)
    if not listFrame.bagshuiData.selectedEntry then
      return
    end

    local logicalEntry
    if type(entry) == "table" and entry.bagshuiData then
      logicalEntry = entry.bagshuiData.logicalEntry
    else
      for _, candidate in ipairs(listFrame.bagshuiData.logicalEntries) do
        if candidate.entry == entry then
          logicalEntry = candidate
          break
        end
      end
    end
    if not logicalEntry or not logicalEntry.top then
      return
    end

    local scrollFrame = listFrame.bagshuiData.scrollFrame
    local currentScroll = scrollFrame:GetVerticalScroll() or 0
    local viewportHeight = scrollFrame:GetHeight()
    local verticalScroll = currentScroll
    if logicalEntry.top < currentScroll then
      verticalScroll = logicalEntry.top
    elseif logicalEntry.top + logicalEntry.height > currentScroll + viewportHeight then
      verticalScroll = logicalEntry.top + logicalEntry.height - viewportHeight
    end
    scrollFrame:SetVerticalScroll(math.max(0, math.min(verticalScroll, scrollFrame:GetVerticalScrollRange())))
    self:RenderScrollableListViewport(listFrame)
  end

  --- Put column header sort indicators in the correct state.
  ---@param listFrame table `listFrame` return value from `Ui:CreateScrollableList()`.
  function Ui:UpdateScrollableListColumnHeaders(listFrame)
    if not listFrame.bagshuiData.entryColumns then
      return
    end

    for i, col in ipairs(listFrame.bagshuiData.entryColumns) do
      if listFrame.bagshuiData.columnHeaders[col.field] then
        local columnFrame = listFrame.bagshuiData.columnHeaders[col.field]
        local scrollFrame = listFrame.bagshuiData.scrollFrame

        if col.currentSortOrder then
          -- This is the colum we're sorting by, so show the sort indicator.

          self:SetIconButtonTexture(
            columnFrame,
            "UI\\SortColumn" .. (col.currentSortOrder == "ASC" and "Asc" or "Desc")
          )

          -- Make sure all textures are sized and positioned correctly.
          for _, textureName in ipairs(BS_UI_BUTTON_TEXTURES) do
            local texture = columnFrame["Get" .. textureName .. "Texture"](columnFrame)
            if texture then
              texture:ClearAllPoints()
              -- Manually position just to the right of the column header.
              texture:SetPoint("LEFT", columnFrame, "LEFT", columnFrame.bagshuiData.text:GetStringWidth() + 8, 0)
              texture:SetWidth(scrollFrame.bagshuiData.headerHeight - 2)
              texture:SetHeight(scrollFrame.bagshuiData.headerHeight - 2)
            end
          end
        else
          -- Hide the sort indicator for all other columns by removing the texture.
          self:SetIconButtonTexture(columnFrame, nil)
        end
      end
    end
  end

  --- Mark all scrollable list entry frames in given array as reusable.
  --- Reusing frames is necessary because they can't be destroyed.
  --- Also moves each frame's pool `nextFree` cursor back to a released frame
  --- when that frame is earlier than the current cursor, so the next
  --- acquisition pass can find it without rescanning the pool from index 1.
  ---@param frameList table[] Array of scrollable list entry frames.
  function Ui:ReleaseScrollableListFrames(frameList)
    if type(frameList) ~= "table" then
      return
    end
    for i = 1, table.getn(frameList) do
      if frameList[i].bagshuiData and frameList[i].Hide then
        -- Released frames are hidden without firing OnLeave, so clear any
        -- hover registrations to avoid stale references in the shared
        -- modifier-key controller.
        if frameList[i].bagshuiData.itemButton then
          self:UnregisterModifierKeyHoverTarget(frameList[i].bagshuiData.itemButton)
        end
        self:UnregisterModifierKeyHoverTarget(frameList[i])

        local reusableFramePool = frameList[i].bagshuiData.reusableFramePool
        local reusableFramePoolIndex = frameList[i].bagshuiData.reusableFramePoolIndex
        if
          reusableFramePool
          and reusableFramePoolIndex
          and reusableFramePoolIndex < (reusableFramePool.nextFree or 1)
        then
          reusableFramePool.nextFree = reusableFramePoolIndex
        end
        frameList[i].bagshuiData.listFrame = nil -- This is the primary marker of reusability.
        frameList[i].bagshuiData.scrollableListEntry = nil
        frameList[i]:Hide()
        frameList[i]:ClearAllPoints()
        frameList[i]:SetParent(_G.UIParent)
      end
    end
  end

  --- Remove an entry from a scrollable list.
  ---@param listFrame table `listFrame` return value from `Ui:CreateScrollableList()`.
  ---@param entry any Value from the list's `bagshuiData.entries` array to remove.
  function Ui:ScrollableListRemove(listFrame, entry)
    if not entry or string.len(tostring(entry)) == 0 then
      return
    end

    -- Make sure we're working with a valid list.
    self:CheckScrollableListInitialized(listFrame)

    -- Find the location of the entry we're removing.
    local arrayPosition = BsUtil.TableContainsValue(listFrame.bagshuiData.entries, entry)

    -- Remove it and refresh the UI.
    table.remove(listFrame.bagshuiData.entries, arrayPosition)
    self:PopulateScrollableList(listFrame, nil, true, false)

    -- Select the previous entry in the list.
    if arrayPosition > 1 then
      arrayPosition = arrayPosition - 1
    end
    if arrayPosition > table.getn(listFrame.bagshuiData.entries) then
      arrayPosition = table.getn(listFrame.bagshuiData.entries)
    end
    self:SetScrollableListSelection(listFrame, listFrame.bagshuiData.entries[arrayPosition])
  end

  --- Move an entry in a scrollable list up or down.
  ---@param listFrame table `listFrame` return value from `Ui:CreateScrollableList()`.
  ---@param entry any Value from the list's `bagshuiData.entries` array to move.
  ---@param direction string BS_UI_SCROLLABLE_LIST_BUTTON_NAME.UP or BS_UI_SCROLLABLE_LIST_BUTTON_NAME.DOWN
  function Ui:ScrollableListMove(listFrame, entry, direction)
    if not entry or string.len(tostring(entry)) == 0 then
      return
    end
    if direction ~= BS_UI_SCROLLABLE_LIST_BUTTON_NAME.UP and direction ~= BS_UI_SCROLLABLE_LIST_BUTTON_NAME.DOWN then
      return
    end

    -- Make sure we're working with a valid list.
    self:CheckScrollableListInitialized(listFrame)

    -- Find the location of the entry we're moving.
    local arrayPosition = BsUtil.TableContainsValue(listFrame.bagshuiData.entries, entry)

    -- Make sure it's not already at the top/bottom when being moved up/down.
    if
      (direction == BS_UI_SCROLLABLE_LIST_BUTTON_NAME.UP and arrayPosition == 1)
      or (
        direction == BS_UI_SCROLLABLE_LIST_BUTTON_NAME.DOWN
        and arrayPosition == table.getn(listFrame.bagshuiData.entries)
      )
    then
      return
    end

    -- Move it, refresh the UI, and re-select it in the new position..
    local newPosition = direction == BS_UI_SCROLLABLE_LIST_BUTTON_NAME.UP and arrayPosition - 1 or arrayPosition + 1
    table.remove(listFrame.bagshuiData.entries, arrayPosition)
    table.insert(listFrame.bagshuiData.entries, newPosition, entry)
    self:PopulateScrollableList(listFrame, nil, true, false)
    self:SetScrollableListSelection(listFrame, entry, nil, true)
  end

  --- Prompt for item IDs, links, or item strings to add to a scrollable item list.
  ---@param listFrame table `listFrame` return value from `Ui:CreateScrollableList()`.
  function Ui:ItemListPromptForNew(listFrame)
    local dialogName = "itemListNew"

    if not self.dialogProperties[dialogName] then
      self:AddMultilineDialog(dialogName, {
        prompt = L.ItemList_NewPrompt,
        button1 = L.Add,
        button1DisableOnEmptyText = true,
        OnAccept = function(dialog)
          self:ItemListAdd(dialog.data.listFrame, dialog:GetText())
        end,
      })
    end

    local dialog = self:ShowDialog(dialogName, nil, nil, nil, nil, self:FindWindowFrame(listFrame:GetParent()))

    -- Pass stuff to dialog callbacks.
    if dialog then
      dialog.data.listFrame = listFrame
    end
  end

  --- Display a read-only dialog containing the IDs of items in an item-type list.
  --- There will be one ID per line followed by a Lua-style comment with the name:
  --- ```
  --- 8932    -- Alterac Swiss
  --- 13935   -- Baked Salmon
  --- ```
  ---@param listFrame table `listFrame` return value from `Ui:CreateScrollableList()`.
  function Ui:ItemListOpenCopyDialog(listFrame)
    local dialogName = "itemListCopy"

    if not self.dialogProperties[dialogName] then
      self:AddMultilineDialog(dialogName, {
        prompt = L.ItemList_CopyPrompt,
        readOnly = true,
        button1 = "",
        button2 = L.Close,
      })
    end

    local items = ""

    for _, logicalEntry in ipairs(listFrame.bagshuiData.logicalEntries) do
      local itemInfo = logicalEntry.entryInfo
      items = items
        .. tostring(itemInfo.id)
        .. string.rep(" ", math.max(1, 8 - string.len(tostring(itemInfo.id))))
        .. "-- "
        .. tostring(itemInfo.name)
        .. BS_NEWLINE
    end
    items = string.sub(items, 1, -2) -- Remove trailing newline.

    self:ShowDialog(dialogName, nil, nil, nil, items, self:FindWindowFrame(listFrame:GetParent()))
  end

  --- Add the given item to the specified scrollable item list.
  ---@param listFrame table `listFrame` return value from `Ui:CreateScrollableList()`.
  ---@param itemList string|number One or more item IDs, links, or itemStrings. Multiple should be separated by whitespace, commas, semicolons, ore newlines.
  function Ui:ItemListAdd(listFrame, itemList)
    if not itemList or not listFrame.bagshuiData or listFrame.bagshuiData.readOnly then
      return
    end

    -- Make sure we're working with a valid list.
    self:CheckScrollableListInitialized(listFrame, BS_UI_SCROLLABLE_LIST_TYPE.ITEM)

    -- Remove comments.
    itemList = string.gsub(itemList, "%-%-.-\n", BS_NEWLINE) -- Per-line.
    itemList = string.gsub(itemList, "%-%-.-$", "") -- Very last line.

    -- Break up the item list.
    local items = BsUtil.Split(itemList, "[%s,;\n]+", true)

    -- Add all items to the list.
    for _, item in ipairs(items) do
      -- Chat links pasted from databases will have a string like this:
      -- /script DEFAULT_CHAT_FRAME:AddMessage("\124cffffffff\124Hitem:8932::::::::60:::::\124h[Alterac Swiss]\124h\124r");
      -- We need to force the \124 into a pipe so it's parsed as an item.
      item = string.gsub(item, "\\124", "|")

      -- Parse out an item's ID from an item link.
      local _, _, itemNum = string.find(item, "item:(%d+)")

      -- Grab the first number in the provided string (or the item ID we found above).
      item = BsUtil.ExtractNumber(itemNum or item)

      -- Add to list.
      if item then
        BsUtil.TableInsertArrayItemUnique(listFrame.bagshuiData.entries, item)
      end
    end

    -- Refresh UI.
    self:PopulateScrollableList(listFrame, nil, true)
  end

  --- Ensure the supposed scrollable list frame passed to various functions is a valid Bagshui scrollable list frame.
  ---@param listFrame table `listFrame` return value from `Ui:CreateScrollableList()`.
  ---@param listType BS_UI_SCROLLABLE_LIST_TYPE? `listFrame` must be of this type or an error will be thrown.
  function Ui:CheckScrollableListInitialized(listFrame, listType)
    assert(type(listFrame) == "table", "Ui:CheckScrollableListInitialized():  listFrame is not a table")
    assert(listFrame.GetName, "Ui:CheckScrollableListInitialized(): listFrame is not a frame")
    local frameName = listFrame:GetName() or "<Unnamed Frame>"
    assert(listFrame.bagshuiData, frameName .. " is not a Bagshui frame")
    assert(listFrame.bagshuiData.entries, frameName .. " is not a Bagshui list frame")
    assert(listFrame.bagshuiData.scrollableListType, frameName .. " is not a Bagshui scrollable list frame")
    if listType then
      assert(
        listFrame.bagshuiData.scrollableListType == listType,
        frameName .. " is not a Bagshui scrollable " .. tostring(listType) .. " list frame"
      )
    end
  end
end)

