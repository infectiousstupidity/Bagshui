# Bagshui review — highest-priority findings

This report consolidates the completed review lanes and rechecks the most important findings against the source.

Two incorrect compatibility findings produced during review were discarded:

- Bagshui’s `GetItemInfo` return assignment is correct for stock WotLK.
- `GetInventorySlotInfo("BAG0SLOT")` returns a slot ID; it does not become nil because the slot is empty.

## Executive summary

The errors most likely to affect normal play are:

1. **Critical:** the central event bridge uses removed legacy globals instead of WotLK callback arguments.
2. **High:** mail tooltip hooks use incorrect attachment signatures and return positions.
3. **High:** Share export creates the same globally named checkbox twice.
4. **High:** text search treats user input as a Lua pattern and errors on characters such as `[` or a trailing `%`.
5. **High:** profile import writes dependency-ID mappings to the wrong table, silently corrupting references.
6. **High:** multiline rules serialize into invalid Lua and hard-error during import.

The main performance problems are:

1. Full-container scans and complete recategorization after ordinary `BAG_UPDATE` events.
2. Non-virtualized scrollable lists with one or two `OnUpdate` scripts per entry.
3. O(N²) reusable-frame lookup and catalog deduplication.
4. Approximately 50 argument-helper calls for every rule-function invocation.
5. Hidden-tooltip loading and multiple tooltip-line passes for each occupied slot.
6. Immediate full filtering and relayout on every search keystroke.

---

## Critical

### 1. WotLK event arguments are discarded during initialization

**Files:** `Bagshui.lua:892-895`, `Bagshui.lua:1078-1083`

```lua
self.eventFrame:SetScript("OnEvent", function()
  self:OnEvent(_G.event, _G.arg1, _G.arg2, _G.arg3, _G.arg4)
end)
```

The callback ignores the WotLK `(self, event, ...)` arguments and instead expects the legacy global `event`/`argN` values.

The extracted 3.3.5 client GlueXML and installed WotLK addons consistently pass event values explicitly:

```lua
frame:SetScript("OnEvent", function(frame, event, ...)
```

On stock 3.3.5 semantics, Bagshui therefore calls `OnEvent(nil, ...)`. Most importantly, this prevents:

```lua
if event == "ADDON_LOADED" and arg1 == "Bagshui" then
  self:AddonLoaded()
  self:LoadComponents()
end
```

from running normally.

**Impact:** Bagshui can fail to initialize its SavedVariables and components. This should be the first fix.

**Fix:**

```lua
self.eventFrame:SetScript("OnEvent", function(_, event, ...)
  self:OnEvent(event, ...)
end)
```

Then audit other script and hook handlers that rely solely on `_G.this`, `_G.event`, or `_G.argN`, especially `Components/Inventory.Ui.BagButton.lua:425-436`.

---

## High severity — runtime errors and data corruption

### 2. Mail tooltip hooks use the wrong WotLK signatures

**File:** `Components/Bagshui.Tooltips.lua:586-589`, `622-626`

```lua
SetInboxItem = function(self, id, attachIndex)
  local name, texture = _G.GetInboxItem(id)
```

`GetInboxItem` requires both the mailbox message index and attachment index. Its texture is also not the second return value.

Likewise:

```lua
SetSendMailItem = function(self)
  local name, texture = _G.GetSendMailItem()
  ...
  return self.bagshuiData.hooked.SetSendMailItem(self)
end
```

drops the outgoing attachment index entirely.

**Impact:** Hovering mailbox attachments can produce argument errors, fail to identify the item, or call the original tooltip function with missing arguments.

**Fix direction:**

- Pass `id, attachIndex` to `GetInboxItem`.
- Capture the texture from the proper return position.
- Accept and forward the attachment index in `SetSendMailItem`.
- Preserve every original argument when forwarding hooked methods.

### 3. Share export creates the same named frame twice

**File:** `Components/Share.lua:238-250`, `277-288`

The export dialog calls this twice:

```lua
dialog.uiFrame.bagshuiData.encodeCheckbox = ui:CreateCheckbox(
  "Encode",
  ...
)
```

Both calls resolve to the same global frame name, such as `BagshuiShareManagerEncode`.

**Impact:** Opening Export can produce a duplicate globally named-frame error. At minimum, the first checkbox is leaked and its reference overwritten.

**Fix:** Remove the second creation and anchor/configure the first checkbox.

### 4. Search input can raise malformed Lua-pattern errors

**File:** `Components/Ui.ScrollableList.lua:951-958`

```lua
string.find(
  string.lower(...),
  string.lower(searchText)
)
```

The fourth `plain` argument is absent, so free-form input is interpreted as a Lua pattern.

**Trigger:** Typing `[` or a trailing `%` into an ordinary text-list search.

**Impact:** Immediate Lua error from the synchronous `OnTextChanged` handler.

**Fix:**

```lua
string.find(normalizedText, normalizedSearch, 1, true)
```

Rule-expression parsing can remain enabled for item-rule searches where it is intentional.

### 5. Imported dependency mappings are stored at the wrong level

**Files:** `Components/Share.lua:420-429`, `Components/Profiles.lua:313-321`

Share initializes a mapping per object list:

```lua
self.temp.dependencyMap[objectList] = {}
```

but then writes mappings to the root:

```lua
self.temp.dependencyMap[exportedId] =
  objectList:Import(objectInfo, self.temp.dependencyMap)
```

Profiles subsequently look under:

```lua
dependencyMap[objectList][exportedId]
```

which remains empty.

**Impact:** If imported category or sort-order IDs conflict with local IDs, imported profiles can reference missing or unrelated local objects. This is silent data corruption rather than a visible import failure.

**Fix:**

```lua
self.temp.dependencyMap[objectList][exportedId] =
  objectList:Import(objectInfo, self.temp.dependencyMap)
```

Add an import test where both category and sort-order IDs conflict locally.

### 6. Multiline rules serialize into invalid Lua and import errors escape handling

**Files:** `Components/Util.lua:794-845`, `Components/Share.lua:393-408`

Strings escape only backslashes and quotes:

```lua
return '"' ..
  string.gsub(string.gsub(v, "\\", "\\\\"), '"', '\\"') ..
  '"'
```

Literal newlines, carriage returns, and other control characters are not escaped. A multiline category rule therefore becomes an invalid Lua short string.

Import then does:

```lua
local deserialize = assert(loadstring("return " .. str))
```

without containing compilation/execution in `pcall`.

**Impact:** Bagshui can export a legitimate multiline rule that hard-errors when imported back into Bagshui.

**Fix direction:**

- Use a verified Lua-safe quoting routine, or explicitly escape `\n`, `\r`, tabs, quotes, backslashes, and control bytes.
- Replace `assert(loadstring(...))` with checked compilation.
- Run the deserializer under `pcall`.
- Return the normal invalid-import error instead of propagating a Lua exception.

### 7. Outfitter readiness check is inverted

**File:** `Config/RuleFunctions.lua:604-616`, `675-678`

```lua
if not _G.Outfitter_IsInitialized and _G.Outfitter_IsInitialized() then
  return false
end
```

If the function exists, the first operand is false and readiness is never checked. If it is missing, the second operand attempts to call nil.

The code later assumes:

```lua
local outfitterOutfits = _G.gOutfitter_Settings.Outfits
```

without verifying that `gOutfitter_Settings` itself exists.

**Impact:** Outfitter rules can error during startup or early refresh, depending on the installed Outfitter revision and initialization timing.

**Fix:**

```lua
if type(_G.Outfitter_IsInitialized) ~= "function"
    or not _G.Outfitter_IsInitialized() then
  return false
end

if type(_G.gOutfitter_Settings) ~= "table" then
  return false
end
```

---

## High severity — performance

### 8. `BAG_UPDATE` discards the changed-bag identity and scans every slot

**Files:** `Components/Inventory.lua:704-706`, `898-902`; `Components/Inventory.Cache.lua:175-225`

The event checks whether the changed bag belongs to this inventory:

```lua
if event == "BAG_UPDATE" and not self.myContainerIds[arg1] then
  return
end
```

but never records `arg1` as the only dirty container. It only sets:

```lua
self.cacheUpdateNeeded = true
self:QueueUpdate()
```

The cache update then loops over all containers and all their slots, invoking at least:

```lua
GetContainerItemLink(bagNum, slotNum)
GetContainerItemInfo(bagNum, slotNum)
```

for each slot.

Detected changes can subsequently trigger complete categorization and sorting.

**Impact:** Looting, splitting stacks, moving one item, or rearranging one bag scales with the entire combined inventory rather than the changed bag or slot.

**Fix direction:**

- Maintain a dirty-container set keyed by `BAG_UPDATE`’s bag ID.
- After debounce, scan only dirty containers.
- Incrementally update aggregate counts for changed containers.
- Reserve full scans for startup, forced refresh, and bag-equipment changes.

### 9. Scrollable lists materialize every row and attach per-row `OnUpdate`

**Files:** `Components/Ui.ScrollableList.lua:674-712`, `1074-1089`, `1121-1161`; `Components/Ui.ItemButton.lua:317-318`

Population obtains and configures a frame for every logical entry:

```lua
for i = entryStart, entryEnd, entryStep do
  local entryFrame = self:GetAvailableScrollableListEntryFrame(...)
  ...
  self:PopulateScrollableListEntry(...)
end
```

Every row receives an `OnUpdate` used to poll modifier keys. Item rows also contain item buttons with another `OnUpdate`.

Off-screen children are clipped by the scroll frame but remain shown, so their scripts still dispatch.

**Impact:** A 1,000-item list can keep roughly 1,000 row callbacks plus 1,000 item-button callbacks active per rendered frame, alongside thousands of frame objects.

This is **High**, rather than Critical, because it is concentrated in open large-list windows and the row handler returns quickly when not hovered.

**Fix direction:**

- Virtualize rows using a viewport-sized pool plus small overscan.
- Bind logical entries only to visible row frames.
- Replace per-row modifier polling with one controller or `MODIFIER_STATE_CHANGED`.
- Avoid item-button polling for unhovered/off-screen rows.

### 10. Reusable list-frame allocation is O(N²)

**File:** `Components/Ui.ScrollableList.lua:655-657`, `1096-1115`, `1769-1781`

Population first marks all old rows reusable. For every new row, allocation scans the reusable array from index 1:

```lua
for i = 1, table.getn(reusableFrameTable) do
  if not reusableFrameTable[i].bagshuiData.listFrame then
    return reusableFrameTable[i]
  end
end
```

Assigned frames remain in the same array, so successive allocation examines progressively more entries.

**Impact:** Reusing 1,000 rows takes approximately:

```text
1 + 2 + ... + 1000 = 500,500 checks
```

before population, text updates, item lookup, or layout work.

**Fix:** Maintain an O(1) free stack/queue or a next-free cursor during each population pass. Virtualization would also bound the pool.

### 11. Catalog deduplication is O(N²)

**File:** `Components/Catalog.lua:480-495`

```lua
for _, existingItem in ipairs(uniqueItemList) do
  if existingItem.itemString == item.itemString then
    return
  end
end
```

This runs for each item added to the unique list. Catalog rebuilds can perform this once for per-character data and again when constructing the account-wide list.

**Impact:** At 1,000 unique items, one construction requires about 499,500 string comparisons. Two stages approach one million comparisons per catalog update.

**Fix:** Maintain a hash keyed by `itemString`, optionally alongside the ordered array required by the UI.

### 12. Rule wrapper performs 50 argument insert attempts per invocation

**Files:** `Components/Rules.lua:1042-1162`, `Components/Categories.lua:426-435`

Every rule-environment function declares 50 fixed arguments and tries to insert all 50 into a shared table before invoking the underlying predicate. Category expressions and predicate calls are also protected by nested `pcall` layers.

For an unmatched item traversing approximately 40–50 rule calls:

```text
1,000 items × 50 rules × 50 insertion attempts
≈ 2.5 million helper calls
```

before the actual matching work.

**Impact:** Major recategorization cost, especially combined with full-inventory refreshes.

**Fix direction:**

- Generate specialized wrappers for common arities.
- Stop after the first nil if rule syntax guarantees contiguous arguments.
- Avoid the inner `pcall` when the compiled category expression already provides error containment.
- Make argument storage nesting-safe; the current shared table is also vulnerable to recursive `MatchCategory` evaluation.

### 13. Item processing repeatedly loads and scans a hidden tooltip

**Files:** `Components/ItemInfo.lua:328-383`, `519-588`; call path `Components/Inventory.Cache.lua:240-269`

`ItemInfo:Get()` retrieves item metadata, loads the hidden tooltip, concatenates tooltip lines, and then traverses tooltip lines again to determine usability.

There is no shared cache for immutable metadata and tooltip-derived information by normalized item ID/string. Duplicate stacks therefore repeat much of the same work.

**Impact:** A 1,000-slot refresh can perform roughly 1,000 hidden-tooltip loads and multiple tooltip-line passes, including duplicate items and count-only changes.

**Fix direction:**

- Cache immutable metadata by item ID or normalized item string.
- Keep instance/location-sensitive fields separate.
- Derive tooltip text and usability in one traversal.
- Do not reload tooltip-derived data for ordinary count or lock changes unless necessary.

### 14. Search performs full filtering and relayout on every keystroke

**Files:** `Components/Ui.SearchBox.lua:48-57`, `Components/Ui.ScrollableList.lua:943-1010`

`OnTextChanged` immediately invokes the callback:

```lua
if onTextChanged then
  onTextChanged()
end
```

The list then scans all rows and rebuilds anchors/dimensions for matches. Search strings and row text are repeatedly lowercased inside the loop.

**Impact:** Noticeable typing stalls in 400–1,000-entry catalogs or managers.

**Fix direction:**

- Debounce by approximately 100–200 ms.
- Normalize the search string once.
- Cache normalized searchable text per entry.
- Filter logical indices first and update only virtualized visible rows.

---

## Medium severity

### 15. Event queue polls every rendered frame for the entire session

**Files:** `Bagshui.lua:896-899`, `Components/Bagshui.Events.lua:109-117`

```lua
self.eventFrame:SetScript("OnUpdate", function()
  self:ProcessEventQueue()
end)
```

Even with an empty queue, every frame enters `ProcessEventQueue()` and starts a `pairs()` iteration.

**Impact:** Persistent background overhead even when no Bagshui window is visible. The work per empty frame is small, so this is Medium rather than Critical.

**Fix:** Install `OnUpdate` only when the queue transitions from empty to nonempty, and remove it when the final queued event is processed.

### 16. Boolean setting validation returns the unvalidated value

**File:** `Components/Settings.lua:653-668`

```lua
local validatedValue = value
...
return value
```

The function computes `validatedValue` but returns the original.

**Impact:** Values such as `0`, `1`, `"false"`, and `"true"` remain numbers/strings. Since `0` and `"false"` are truthy in Lua, persisted settings can behave opposite to their intended boolean value.

**Fix:** Return `validatedValue` and write normalized primitive values back during default validation.

### 17. Invalid numeric SavedVariables can crash startup validation

**File:** `Components/Settings.lua:617-636`

```lua
validatedValue = tonumber(validatedValue)

if min then
  validatedValue = math.max(validatedValue, min)
end
```

Failed conversion yields nil, which is passed to `math.max` or `math.min`.

**Impact:** Corrupted, hand-edited, or incompatible SavedVariables can stop initialization instead of falling back to defaults.

**Fix:** Test for nil after `tonumber` and return the declared default.

### 18. Equipped-item state listens for one event but checks another

**File:** `Components/Character.lua:22-33`, `192-200`

The component registers:

```lua
UNIT_INVENTORY_CHANGED = true
```

but the handler checks:

```lua
if event == "UPDATE_INVENTORY_ALERTS" then
```

**Impact:** Gear swaps do not refresh `Character.equipped` and `equippedHistory`; `Equipped()` categorization and catalog equipped totals can remain stale until reload/login.

**Fix:** Handle `UNIT_INVENTORY_CHANGED` with the existing `arg1 == "player"` check and debounce.

### 19. Copy/export and Share encoding use repeated immutable-string concatenation

**Files:** `Components/Ui.ScrollableList.lua:1892-1903`, `Components/Util.lua:794-819`, Share encoding helpers around `Components/Util.lua:995-1086`

Patterns such as:

```lua
items = items .. nextLine
str = str .. result
encoded = encoded .. ...
```

produce quadratic copying and substantial temporary garbage in Lua 5.1.

**Impact:** Large lists and “export all” payloads can freeze the UI temporarily. Imports also lack a clear input-size limit.

**Fix:** Accumulate chunks in arrays and use `table.concat`; enforce encoded and decoded size limits.

---

## Recommended fix order

### Phase 1 — stop normal-use errors

1. Fix `Bagshui.lua` event callback signatures.
2. Fix inbox/send-mail tooltip signatures.
3. Remove the duplicate Share checkbox.
4. Make text search literal.
5. Fix Share dependency mapping.
6. Make serialization newline-safe and contain deserialization errors.
7. Fix the Outfitter readiness guard.

### Phase 2 — remove major refresh spikes

1. Track dirty containers from `BAG_UPDATE`.
2. Cache immutable item metadata and reduce hidden-tooltip parsing.
3. Replace catalog linear dedup with a hash.
4. Reduce rule-wrapper argument and `pcall` overhead.
5. Prevent zone/location changes from rereading all bag slots; recategorize only when location-sensitive rules require it.

### Phase 3 — large-list performance

1. Virtualize scrollable lists.
2. Replace reusable-frame linear scans with O(1) allocation.
3. Consolidate modifier polling.
4. Debounce search and cache normalized text.
5. Make selection changes update only affected rows.

### Phase 4 — persistence correctness

1. Normalize boolean/numeric settings safely.
2. Compact persisted per-item records where possible.
3. Bound or prune long-lived equipment history.
4. Add conflict-focused Share/Profile import tests.

---

## Verified clean / notable non-findings

- No `C_*` namespace usage was found.
- No `C_Timer`, `GetItemInfoInstant`, `Mixin`, `CreateFrameWithMixins`, or modern container namespace usage was found.
- The normal WotLK `GetItemInfo` ten-return assignment in `Components/ItemInfo.lua` is correct; the compatibility child’s contrary finding was rejected.
- `GetInventorySlotInfo("BAG0SLOT")` is being used to retrieve an inventory slot ID; the child’s “empty bag causes nil arithmetic” finding was rejected.
- Catalog totals are derived from persisted per-character inventory data rather than saved as a second full catalog copy.
- No full-root `BagshuiData` deep copy was found on every `BAG_UPDATE`.
- No current `/reload` event-registration accumulation was established.

## Review coverage and infrastructure note

Five substantive reviews completed: events/hooks, rules/items, UI/scroll, data safety, and compatibility. The standalone layout lane repeatedly failed because:

- codex-lb inference returned `stream_incomplete` even for a 20-token direct ping, and its layout children timed out;
- the qwen replacement workflow was externally stopped after 46 minutes;
- a final qwen retry was rejected because the model had been temporarily excluded after prior empty/stopped runs.

The most important layout behavior—full cache scans, complete categorization/sorting triggers, per-item processing, and list frame behavior—was independently covered and source-validated through the other lanes.
