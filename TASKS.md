# Bagshui remediation tasks

This document breaks the highest-priority findings from [`FINDINGS.md`](./FINDINGS.md) into implementation tasks grouped into coherent, single-agent work clusters.

## Project constraints

Every implementation agent must follow these constraints:

- Target **World of Warcraft WotLK 3.3.5a**, `## Interface: 30300`.
- Use Lua 5.1-compatible syntax and APIs.
- Do not introduce `C_*`, `C_Timer`, `GetItemInfoInstant`, `Mixin`, or other modern APIs.
- Preserve existing Vanilla/SuperWoW compatibility where practical; branch explicitly when APIs differ.
- Keep changes inside the task's listed files unless a necessary dependency is discovered and documented.
- Do not opportunistically refactor unrelated code.
- Update comments that describe obsolete Vanilla callback behavior.
- Verification must include a source review and the listed manual scenarios. If no automated WoW test harness exists, document manual test results instead of inventing tests.
- Assign one implementation agent to an entire cluster. That agent owns the cluster's tasks in the listed order and should preserve the task boundaries as review and commit checkpoints.
- Do not split one cluster across concurrent implementation agents; the grouped tasks intentionally share code paths and context.
- Separate clusters may be implemented in parallel only when their file scopes do not overlap. Use separate worktrees for parallel agents.
- Commit each completed task separately when commits are requested, even when one agent implements the full cluster.

## Single-agent work clusters

### C01 — WotLK callback and tooltip compatibility

**Tasks, in order:** `T01` → `T02` → `T06`

**Why these belong together:** These tasks correct FrameXML/event callback boundaries and require the same WotLK-versus-Vanilla compatibility decisions. Keeping them with one agent avoids inconsistent callback forwarding and fallback conventions.

### C02 — Share export/import integrity

**Tasks, in order:** `T03` → `T04` → `T05`

**Why these belong together:** All three tasks affect the Share dialog or its import/export pipeline. One agent can verify UI lifecycle, dependency remapping, serialization, and malformed-input handling as one end-to-end round trip.

### C03 — Inventory cache and invalidation pipeline

**Tasks, in order:** `T08` → `T09`

**Why these belong together:** Dirty-container scanning produces the change information consumed by categorization, sorting, and layout invalidation. The same agent should define and carry that information through the pipeline.

### C04 — Scrollable-list correctness and baseline performance

**Tasks, in order:** `T07` → `T11` → `T12` → `T13`

**Why these belong together:** These changes share the scrollable-list population, filtering, row lifecycle, and hover behavior. Completing them together establishes the logical-list and row-pool behavior that virtualization will build on.

**Coordination note:** `T12` should avoid editing `Components/Bagshui.Tooltips.lua` unless centralization genuinely requires it. If it does, integrate `C01` first and do not run `C01` and `C04` as concurrent writers.

### C05 — Catalog construction indexing

**Tasks, in order:** `T10`

**Why this is separate:** Catalog deduplication is self-contained, has no implementation dependency on the other subsystems, and is a suitably bounded single-agent assignment.

### C06 — Scrollable-list virtualization

**Tasks, in order:** `T14`

**Why this is separate:** Virtualization is an extra-large architectural change with broad caller impact. It needs a dedicated agent and its own planning/review cycle rather than being appended to an already large implementation assignment.

## Recommended execution order

1. **First wave:** `C01`, `C02`, `C03`, `C04`, and `C05` may run in separate worktrees, subject to the `C01`/`C04` tooltip-file coordination note above.
2. **Second wave:** Integrate and verify `C04`, then implement `C06` against that result.
3. Within every cluster, complete tasks in the listed order and verify each task before starting the next one.

Cross-cluster dependencies:

- `C06` depends on `C04` (`T14` builds on `T11`, `T12`, and `T13`).
- `C03` has an internal dependency: `T09` should follow `T08`.
- `C01`, `C02`, and `C05` have no required dependency on another cluster.

---

## T01 — Fix the central WotLK event bridge

**Cluster:** `C01` — WotLK callback and tooltip compatibility  
**Priority:** Must fix first  
**Size:** Small  
**Primary files:**

- `Bagshui.lua`
- `WotlkGlobals.lua` only if its comments need clarification

### Problem

`Bagshui:Init()` installs a no-argument `OnEvent` callback and reads `_G.event` and `_G.arg1` through `_G.arg4`. Stock WotLK provides event data through callback arguments.

### Required change

- Change the central frame handler to accept `(frame, event, ...)`.
- Forward the event name and all event arguments to `Bagshui:OnEvent`.
- Remove or correct the comment claiming that the target client passes these values through globals.
- Do not add global compatibility shims for `event` or `argN`.

Expected shape:

```lua
self.eventFrame:SetScript("OnEvent", function(_, event, ...)
  self:OnEvent(event, ...)
end)
```

### Acceptance criteria

- `ADDON_LOADED` reaches `Bagshui:OnEvent("ADDON_LOADED", "Bagshui")`.
- `AddonLoaded()` and `LoadComponents()` run exactly once for Bagshui.
- Event arguments beyond four values are not unnecessarily discarded.
- No `_G.event` or `_G.argN` remains in the central event bridge.
- Existing custom Bagshui event dispatch still works.

### Verification

- Reload the UI with Lua errors enabled.
- Confirm Bagshui initializes and opens.
- Confirm SavedVariables and components load.
- Trigger at least one `BAG_UPDATE` and verify its bag ID reaches the inventory handler.

---

## T02 — Convert remaining callback boundaries away from legacy globals

**Cluster:** `C01` — WotLK callback and tooltip compatibility  
**Priority:** Must fix  
**Size:** Medium  
**Depends on:** `T01`  
**Primary scope:**

- `Components/**`
- `Config/Skins.lua`

### Problem

Several frame scripts and hooked FrameXML handlers still use `_G.this`, `_G.event`, or `_G.argN`. Some functions provide a fallback parameter (`this = this or _G.this`), while others depend exclusively on globals.

### Required change

- Find every `_G.this`, `_G.event`, and `_G.argN` use.
- Classify each occurrence as:
  1. a frame/script callback boundary,
  2. an ordinary method called outside a callback, or
  3. compatibility code intentionally supporting Vanilla.
- At callback boundaries, accept and use explicit callback arguments.
- Preserve Vanilla compatibility with a local fallback only when necessary:

```lua
function(this, ...)
  this = this or _G.this
end
```

- Pay particular attention to `Components/Inventory.Ui.BagButton.lua:425-436` and methods callable both from scripts and ordinary code.
- Do not blindly replace globals where the called function's signature would change incompatibly.

### Acceptance criteria

- No WotLK code path depends exclusively on `_G.this`, `_G.event`, or `_G.argN`.
- Hook wrappers forward every original argument.
- Bag-slot click, drag, pickup, tooltip, dropdown, and bank open/close behavior still works.
- Any retained global fallback has a comment explaining the Vanilla compatibility requirement.

### Verification

- Test left/right clicking and dragging bag slots.
- Open and close bags and bank through UI, keybindings, and slash commands.
- Hover relevant buttons and dropdown entries.
- Test with and without pfUI if available.

---

## T03 — Remove the duplicate Share export checkbox

**Cluster:** `C02` — Share export/import integrity  
**Priority:** Must fix  
**Size:** Small  
**Primary file:** `Components/Share.lua`

### Problem

The Share export dialog calls `CreateCheckbox("Encode", ...)` twice, producing the same globally named frame and overwriting the first reference.

### Required change

- Create the Encode checkbox exactly once.
- Retain the existing callback behavior.
- Anchor and size that one checkbox using the existing explanation and button layout.
- Do not rename the checkbox unless necessary for backward-compatible UI naming.

### Acceptance criteria

- Only one `CreateCheckbox("Encode", ...)` call exists in the export-dialog customization.
- Opening the Export dialog creates no duplicate-frame error.
- Toggling Encode regenerates the export text correctly.
- Reopening the dialog reuses the established dialog/frame lifecycle without creating another duplicate global frame.

### Verification

- Open, close, and reopen Export several times.
- Toggle Encode in both states and confirm the text changes.
- Perform an encoded and human-readable export.

---

## T04 — Correct Share import dependency-ID mapping

**Cluster:** `C02` — Share export/import integrity  
**Priority:** Must fix — data integrity  
**Size:** Small  
**Primary files:**

- `Components/Share.lua`
- `Components/Profiles.lua` for verification only unless a defensive check is needed

### Problem

Import initializes `dependencyMap[objectList]` but writes imported IDs to `dependencyMap[exportedId]`. Profiles read from `dependencyMap[objectList][exportedId]`, so conflict remapping fails.

### Required change

Store each imported mapping under its object-list table:

```lua
self.temp.dependencyMap[objectList][exportedId] =
  objectList:Import(objectInfo, self.temp.dependencyMap)
```

Add defensive handling only if `ObjectList:Import` can legitimately return nil.

### Acceptance criteria

- Category and Sort Order mappings are stored independently under their respective object-list keys.
- Importing into a configuration with conflicting local IDs rewrites Profile references to the newly assigned IDs.
- Existing unrelated local Categories and Sort Orders are not referenced accidentally.
- Imports without ID conflicts behave exactly as before.

### Verification

Use a conflict-focused round trip:

1. Export a Profile with referenced Categories and Sort Orders.
2. Create local objects occupying those exported IDs.
3. Import the export.
4. Confirm the imported Profile references the imported objects, not the pre-existing local objects.

---

## T05 — Make Share serialization and import failure-safe

**Cluster:** `C02` — Share export/import integrity  
**Priority:** Must fix  
**Size:** Medium  
**Primary files:**

- `Components/Util.lua`
- `Components/Share.lua`

### Problem

Serialized strings escape quotes and backslashes but not newlines or other control characters. Deserialization uses `assert(loadstring(...))`, allowing malformed input to escape the intended import error handling.

### Required change

- Encode strings as valid Lua 5.1 string literals, including:
  - backslashes,
  - quotes,
  - `\n`,
  - `\r`,
  - tabs,
  - other unsafe control bytes.
- Verify whether the target client's `string.format("%q", value)` behavior is suitable before using it; otherwise implement explicit escaping.
- Replace `assert(loadstring(...))` with checked compilation.
- Execute the compiled deserializer under `pcall` with the restricted environment already used by the code.
- Return nil/error information to `Share:ProcessImport` instead of throwing.
- Have `ProcessImport` display the existing invalid-format error for malformed content.
- Add a reasonable encoded-input and decoded-output size limit if this can be done without changing the export format.

### Acceptance criteria

- A multiline Category rule survives export → import unchanged.
- Quotes, backslashes, tabs, CRLF, and non-ASCII localized text round-trip correctly.
- Malformed Lua text does not produce an uncaught Lua error.
- Encoded and human-readable formats both remain importable.
- Deserialization cannot access the WoW global environment.

### Verification

Round-trip a payload containing:

- multiple lines,
- `"quoted text"`,
- backslashes,
- tabs,
- Chinese/localized text,
- an empty string.

Also paste truncated and deliberately malformed exports and verify a normal Bagshui error is shown.

---

## T06 — Correct WotLK mail tooltip hook signatures

**Cluster:** `C01` — WotLK callback and tooltip compatibility  
**Priority:** Must fix  
**Size:** Small  
**Primary file:** `Components/Bagshui.Tooltips.lua`

### Problem

The inbox hook drops the attachment index when calling `GetInboxItem`, and the send-mail hook drops its attachment index entirely. The code also assumes the texture is the second return value.

### Required change

- Verify the exact stock WotLK 3.3.5 signatures and return positions for:
  - `GameTooltip:SetInboxItem`,
  - `GetInboxItem`,
  - `GameTooltip:SetSendMailItem`,
  - `GetSendMailItem`.
- Accept and forward every original argument.
- Pass the attachment index into the corresponding information API.
- Capture the texture from the correct return position.
- Preserve Vanilla/SuperWoW behavior through an explicit capability branch if signatures differ.

### Acceptance criteria

- Hovering every attachment in a multi-attachment inbox message works.
- Hovering every outgoing mail attachment works.
- The original tooltip method receives exactly the arguments supplied by FrameXML.
- Bagshui catalog information is resolved for the correct attachment.
- No argument or nil-index Lua errors occur.

### Verification

- Test inbox mail containing multiple attachments.
- Test multiple outgoing attachments before sending.
- Test attachment slots containing duplicate names but different textures/items if possible.

---

## T07 — Make ordinary text-list search literal

**Cluster:** `C04` — Scrollable-list correctness and baseline performance  
**Priority:** Must fix  
**Size:** Small  
**Primary file:** `Components/Ui.ScrollableList.lua`

### Problem

Ordinary text-list search passes user text to `string.find` as a Lua pattern. Inputs such as `[` or trailing `%` raise malformed-pattern errors.

### Required change

- Normalize the search term once before the row loop.
- Use literal matching for non-item text lists:

```lua
string.find(normalizedText, normalizedSearch, 1, true)
```

- Keep rule-expression parsing only for item-list searches where `BsRules:Match` is intentional.
- Do not include debounce or virtualization in this task; those are separate tasks.

### Acceptance criteria

- Searches containing `[`, `]`, `%`, `.`, `*`, `+`, `-`, `?`, `(`, and `)` produce no Lua error.
- Text search remains case-insensitive.
- UI escape removal behavior remains intact.
- Item-list rule searches continue using the rule engine.

### Verification

Search a text list for each Lua pattern metacharacter and for mixed-case ordinary text.

---

## T08 — Track dirty containers and avoid full scans on each `BAG_UPDATE`

**Cluster:** `C03` — Inventory cache and invalidation pipeline  
**Priority:** Must fix for performance  
**Size:** Large  
**Primary files:**

- `Components/Inventory.lua`
- `Components/Inventory.Cache.lua`

### Problem

`BAG_UPDATE` verifies that `arg1` belongs to the inventory but discards it. The subsequent cache update scans every container and slot.

### Required change

- Add a dirty-container set keyed by container ID.
- On `BAG_UPDATE`, add `arg1` to that set before queuing the existing debounced update.
- Update only dirty containers during ordinary bag changes.
- Preserve full-cache modes for:
  - initial population,
  - explicit force refresh,
  - bag-equipment/container mapping changes,
  - unknown state requiring recovery.
- Correctly update per-container slot counts, filled counts, empty-slot tracking, partial stacks, and changed-item tracking when only part of the inventory is scanned.
- Clear dirty flags only after a successful update.
- Do not implement sort/categorization invalidation changes in this task beyond preserving current behavior; that is `T09`.

### Acceptance criteria

- Changing one bag scans only that bag in the ordinary path.
- Several `BAG_UPDATE` events inside the debounce window scan the union of dirty bags once.
- Initial load and forced refresh still scan all applicable containers.
- Equipping/replacing a bag correctly updates container mappings and slot counts.
- Bank bags remain separate from normal bags and update correctly while the bank is open.
- Cache contents match the game after loot, move, split, merge, delete, and bag replacement operations.

### Verification

Instrument or temporarily count calls to `GetContainerItemLink`/`GetContainerItemInfo`:

- One changed 16-slot bag should cause approximately 16 slot reads, not all bag slots.
- Two dirty bags before the queued update should each be scanned once.
- Remove instrumentation before finalizing the change.

---

## T09 — Narrow recategorize, sort, and layout invalidation

**Cluster:** `C03` — Inventory cache and invalidation pipeline  
**Priority:** Must fix for performance  
**Size:** Large  
**Depends on:** Preferably `T08`  
**Primary files:**

- `Components/Inventory.lua`
- `Components/Inventory.Cache.lua`
- `Components/Inventory.Layout.lua`
- `Components/Categories.lua` only if change classification helpers belong there

### Problem

A cache change can trigger complete inventory categorization, sorting, and layout even when the changed information cannot affect category membership or order—for example lock state or some count-only changes.

### Required change

- Classify cache changes by consequence, for example:
  - visual-only: lock state, readable state,
  - count/stock-only,
  - item identity/metadata changed,
  - bag structure changed,
  - rule-context changed.
- Only recategorize items whose identity or rule-relevant metadata changed.
- Only resort groups affected by sort-relevant changes.
- Only perform a full layout when group membership, ordering, dimensions, or bag structure changed.
- Preserve a safe full-refresh fallback.
- Ensure zone/location changes do not reread container slots; recategorize only if active rules depend on changed game context.

### Acceptance criteria

- Lock/unlock changes update button state without full recategorization.
- Count-only changes do not trigger a full sort unless the active sort order or grouping depends on count/stack state.
- A replaced item is recategorized and positioned correctly.
- Group/category/profile changes still force the required complete rebuild.
- Zone changes do not call container item APIs unless another inventory event requires it.

### Verification

Instrument the calls to cache scan, categorization, sorting, and layout while testing:

- looting a new item,
- changing only stack count,
- locking/unlocking an item,
- moving an item between slots,
- crossing a zone/subzone boundary,
- editing a category or sort order.

Remove instrumentation before finalizing.

---

## T10 — Replace catalog linear deduplication with a keyed index

**Cluster:** `C05` — Catalog construction indexing  
**Priority:** Should fix for performance  
**Size:** Medium  
**Primary file:** `Components/Catalog.lua`

### Problem

`Catalog:AddToItemTable` scans the complete unique-item array for each insertion, creating O(N²) behavior.

### Required change

- Maintain a membership/index table keyed by `itemString` during catalog construction.
- Preserve the ordered array used by catalog consumers and sorting.
- Ensure copied offline-character item records retain the existing copy behavior.
- Reset/reuse the membership map safely on rebuild.
- Do not change external catalog table contracts unless all consumers are updated in the same task.

### Acceptance criteria

- Deduplication is O(1) average-time per item.
- The final ordered item array contains one entry per `itemString`.
- Current- and offline-character totals remain correct.
- Catalog sort/display behavior is unchanged.
- Temporary index tables do not persist unnecessarily in SavedVariables.

### Verification

Compare catalog contents and totals before and after the change using:

- duplicate stacks,
- the same item on multiple characters,
- items with different suffixes/itemStrings,
- money and empty-slot sentinel entries where applicable.

---

## T11 — Make reusable list-frame allocation O(1)

**Cluster:** `C04` — Scrollable-list correctness and baseline performance  
**Priority:** Should fix for performance  
**Size:** Medium  
**Primary file:** `Components/Ui.ScrollableList.lua`

### Problem

Each allocation scans the reusable-frame array from index 1, causing approximately N(N+1)/2 checks when rebuilding N rows.

### Required change

Implement one of:

- a free-frame stack/queue maintained during release, or
- a next-free cursor scoped to the population pass.

Requirements:

- Preserve separate pools for list type and custom creation function.
- Never return a frame still assigned to another open list.
- Preserve existing frame reset/reparent behavior.
- Do not implement viewport virtualization in this task.

### Acceptance criteria

- Rebuilding N rows performs O(N) total frame acquisition work.
- Simultaneously open lists do not steal each other's assigned frames.
- Custom entry-frame pools remain isolated.
- Frames are reused rather than continually created after reaching the prior high-water mark.

### Verification

Instrument frame-pool probes while repeatedly opening and refreshing:

- one large list,
- two simultaneous lists of the same type,
- lists with different custom entry creation functions.

Remove instrumentation before finalizing.

---

## T12 — Consolidate per-row and per-item modifier polling

**Cluster:** `C04` — Scrollable-list correctness and baseline performance  
**Priority:** Should fix for performance  
**Size:** Medium  
**Primary files:**

- `Components/Ui.ScrollableList.lua`
- `Components/Ui.ItemButton.lua`
- `Components/Inventory.Ui.ItemButton.lua` if it shares the polling behavior
- `Components/Bagshui.Tooltips.lua` only if tooltip modifier refresh is centralized there

### Problem

Each materialized row and item button can own an `OnUpdate` handler that polls modifier-key state, even when most rows are off-screen and not hovered.

### Required change

- Identify every modifier-state `OnUpdate` in the listed components.
- Replace per-row polling with either:
  - `MODIFIER_STATE_CHANGED`, or
  - one controller-level, throttled handler active only while a relevant tooltip/hover is active.
- Update only the currently hovered row/item.
- Disable polling entirely when no relevant tooltip is visible.
- Preserve modifier-driven tooltip refresh behavior.

### Acceptance criteria

- Opening a 1,000-entry list does not install or execute one modifier poll per row.
- Alt/Ctrl/Shift tooltip behavior remains correct for the hovered entry.
- Moving between entries does not leave stale hovered references.
- Closing/hiding the list or tooltip disables the controller work.

### Verification

- Hover rows while pressing and releasing Alt, Ctrl, and Shift.
- Move rapidly across rows.
- Hide the list while modifiers are held.
- Confirm only the hovered item refreshes.

---

## T13 — Debounce and normalize list search

**Cluster:** `C04` — Scrollable-list correctness and baseline performance  
**Priority:** Should fix for performance  
**Size:** Medium  
**Depends on:** `T07`  
**Primary files:**

- `Components/Ui.SearchBox.lua`
- `Components/Ui.ScrollableList.lua`

### Problem

Every keystroke immediately scans and relays out the entire materialized list. Search text is normalized repeatedly inside the row loop.

### Required change

- Debounce search callbacks by approximately 100–200 ms using an existing Bagshui queue/timer mechanism compatible with 3.3.5.
- Coalesce rapid changes so only the latest value is processed.
- Normalize the search term once per filter operation.
- Cache normalized searchable row text until the row's source value changes.
- Preserve immediate clearing behavior if it improves usability and does not complicate the implementation.
- Do not implement row virtualization in this task.

### Acceptance criteria

- Typing a multi-character query quickly causes one or a small bounded number of filter passes, not one full pass per character.
- The final displayed result always matches the current edit-box value.
- Closing or reusing a dialog cannot apply a stale queued search to the wrong list.
- Literal punctuation behavior from `T07` remains correct.

### Verification

Instrument the filter callback count while:

- typing a ten-character query quickly,
- holding backspace,
- clearing the box,
- closing the window before the debounce expires.

Remove instrumentation before finalizing.

---

## T14 — Virtualize scrollable-list rows

**Cluster:** `C06` — Scrollable-list virtualization  
**Priority:** Should fix for large-list performance  
**Size:** Extra large — plan before implementation  
**Depends on:** Preferably `T11`, `T12`, and `T13`, or explicitly supersedes their affected implementation  
**Primary files:**

- `Components/Ui.ScrollableList.lua`
- `Components/Ui.ScrollFrame.lua`
- `Components/Ui.ItemButton.lua`
- Callers that assume one permanent frame per logical entry

### Problem

The list creates and retains one frame for every logical entry. Off-viewport rows remain materialized and can continue receiving script dispatch.

### Required change

- Separate logical entries from physical row frames.
- Maintain a physical row pool sized approximately to:

```text
ceil(viewport height / row height) + small overscan
```

- Rebind physical rows as the scroll offset changes.
- Preserve:
  - headers,
  - variable row heights if currently supported,
  - selection and multi-selection,
  - keyboard navigation,
  - tooltips,
  - item buttons,
  - searching/filtering,
  - copy/export behavior,
  - custom entry creation functions.
- Replace APIs that incorrectly treat `entryFrames` as the authoritative logical dataset.
- Maintain maps from logical entry/index/value to the currently bound physical row where necessary.
- Keep a non-virtualized fallback only if a specific variable-height/custom-row mode cannot be virtualized safely.

### Acceptance criteria

- A 1,000-entry uniform list creates only approximately viewport-size + overscan row frames.
- Scrolling does not allocate unbounded new frames.
- Selection remains attached to logical entries, not recycled physical frames.
- Headers and item rows display correctly after rapid scrolling.
- Search, sort, refresh, copy/export, and multi-select remain correct.
- Tooltip ownership cannot reference a row after that frame has been rebound.
- Frame count remains stable after repeatedly scrolling from top to bottom.

### Verification

Test at least:

- a 1,000-entry text list,
- a 1,000-entry item list,
- headers and collapsed/expanded sections,
- single and multi-selection,
- search while scrolled away from the top,
- refresh while hovering a row,
- copy/export of the complete logical list,
- two simultaneous list windows.

Record before/after frame counts and a simple CPU profile while scrolling.

---

## Completion checklist for every task

Before marking any task complete, the assigned agent should report:

- Files changed.
- Root cause addressed.
- Implementation summary.
- Any compatibility assumptions made.
- Automated/static checks run.
- Manual in-game scenarios tested or still required.
- Remaining risks or follow-up tasks.
- Confirmation that unrelated behavior was not refactored.
