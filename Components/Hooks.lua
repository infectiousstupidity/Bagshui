-- Bagshui Hooks Class Prototype
-- Exposes: Bagshui.prototypes.Hooks
--
-- WoW API functions can be hooked by creating an instance of the Hooks class and/or
-- calling SetHooks()/SetHook(). The functions being called for hooks are expected to take
-- the name of the WoW API function as their first parameter. They can then call
-- `<Hooks instance>:OriginalHook(<WoW API function name>)` to trigger the original
-- API function. The name of the function is passed instead of a direct function
-- reference so that if multiple API functions are hooked with the same Bagshui
-- function, the Bagshui function has a way to tell what the original function name was.

Bagshui:LoadComponent(function()
  local Hooks = {}
  Bagshui.prototypes.Hooks = Hooks

  --- Create a new instance of the Hooks class.
  ---@param hooksToRegister table<string,function>? `hooks` parameter for SetHooks().
  ---@param classObject table? Parameter for SetHook().
  ---@return table hooksClassInstance
  function Hooks:New(hooksToRegister, classObject)
    local hooks = {
      _super = Hooks,

      originalHookFunctions = {},
    }

    setmetatable(hooks, self)
    self.__index = self

    hooks:SetHooks(hooksToRegister, BS_HOOK_ACTION.REGISTER, classObject)

    return hooks
  end

  --- Bulk hook registration.
  ---@param hooks table<string,function> { wowApiFunctionName = newFunction } parameters for SetHook().
  ---@param registrationAction BS_HOOK_ACTION Parameter for SetHook().
  ---@param classObject table? Parameter for SetHook().
  function Hooks:SetHooks(hooks, registrationAction, classObject)
    if not hooks then
      return
    end
    for wowApiFunctionName, newFunction in pairs(hooks) do
      self:SetHook(wowApiFunctionName, newFunction, registrationAction, classObject)
    end
  end

  --- WoW API hook management (register / unregister / check status).
  --- Hooked functions are expected to handle all the parameters and return values as the originals,
  --- but this can't really be checked, so it's up to the developer to do the right thing.
  ---@param wowApiFunctionName string Name of the original WoW API function being hooked.
  ---@param newFunction function|string Function that will handle the hook *or* the name of a class function, if classObject is provided.
  ---@param registrationAction BS_HOOK_ACTION? Should the hook be registered, unregistered, or checked? (Registers if not provided.)
  ---@param classObject table? The class that will handle this hook. When provided, `newFunction` *must* be a string instead of a function.
  function Hooks:SetHook(wowApiFunctionName, newFunction, registrationAction, classObject)
    local originalFunction, hookFunction, classSelf
    registrationAction = registrationAction or BS_HOOK_ACTION.REGISTER

    if registrationAction == BS_HOOK_ACTION.REGISTER then
      -- Make sure the function isn't already hooked.
      if not self.originalHookFunctions[wowApiFunctionName] then
        -- Capture the original function reference.
        originalFunction = _G[wowApiFunctionName]

        -- Start by using self:OnHook, which will print a message that no hook action was taken.
        classSelf = self
        hookFunction = self.OnHook

        -- When given a function as newFunction, use that as the hook function.
        if type(newFunction) == "function" then
          classSelf = nil
          hookFunction = newFunction
        end

        -- When a class is provided, always use it as the self parameter for the hook call.
        -- Also, if newFunction was a string, grab the class function.
        if classObject then
          classSelf = classObject
          if type(newFunction) == "string" and classObject[newFunction] then
            hookFunction = classObject[newFunction]
          else
            hookFunction = nil
          end
        end

        -- Make sure the hookFunction is valid.
        if type(hookFunction) ~= "function" then
          Bagshui:PrintWarning(
            "Could not install hook function for '"
              .. wowApiFunctionName
              .. "' -- newFunction parameter is not a valid function."
          )
          return
        end

        -- Store the original function reference.
        self.originalHookFunctions[wowApiFunctionName] = originalFunction

        -- Install hook and preserve the complete original argument list.
        _G.setglobal(wowApiFunctionName, function(...)
          if classSelf then
            return hookFunction(classSelf, wowApiFunctionName, ...)
          end
          return hookFunction(wowApiFunctionName, ...)
        end)
      else
        Bagshui:PrintDebug("Hook function for '" .. wowApiFunctionName .. "' is already installed")
      end
    elseif registrationAction == BS_HOOK_ACTION.UNREGISTER then
      originalFunction = self.originalHookFunctions[wowApiFunctionName]

      if originalFunction ~= _G[wowApiFunctionName] then
        _G.setglobal(wowApiFunctionName, originalFunction)
        self.originalHookFunctions[wowApiFunctionName] = nil

        Bagshui:PrintDebug("Hook function for '" .. wowApiFunctionName .. "' removed.")
      else
        Bagshui:PrintDebug("Hook function for '" .. wowApiFunctionName .. "' was not installed")
      end
    elseif registrationAction == BS_HOOK_ACTION.CHECK then
      Bagshui:Print("Hooks:")
      if
        self.originalHookFunctions[wowApiFunctionName]
        and _G[wowApiFunctionName] ~= self.originalHookFunctions[wowApiFunctionName]
      then
        Bagshui:Print("> " .. wowApiFunctionName .. ": hooked")
      else
        Bagshui:Print("> " .. wowApiFunctionName .. ": NOT hooked")
      end
    end
  end

  --- Call the original hook function if it exists.
  ---@param wowApiFunctionName string Name of the original WoW API function to call.
  ---@param ... any Original function arguments.
  ---@return any? # Return value from the original WoW API function.
  function Hooks:OriginalHook(wowApiFunctionName, ...)
    if wowApiFunctionName == nil then
      return
    end
    if self.originalHookFunctions[wowApiFunctionName] then
      return self.originalHookFunctions[wowApiFunctionName](...)
    end
  end

  -- Hook handling (skeleton) / warning message.
  -- This won't get called unless a hook isn't properly set up.
  ---@param wowApiFunctionName string Name of the original WoW API function to call.
  ---@param ... any Original function arguments.
  function Hooks:OnHook(wowApiFunctionName, ...)
    Bagshui:PrintWarning(
      "Hook function "
        .. tostring(wowApiFunctionName)
        .. " triggered. Calling original API function (this probably shouldn't happen)."
    )
    self:OriginalHook(wowApiFunctionName, ...)
  end
end)

