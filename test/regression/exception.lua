-- Regression guard for the Lua 5.1 FFI of Effect.Exception.
--
-- Pins the semantic fixes:
--   #81 catchException must RUN the handler Effect (trailing `()`), not return
--       the unexecuted thunk.
--   #82 throwException must preserve the message across throw/catch; Lua's
--       `error(s)` at the default level prepends "chunk:line: ", so it raises
--       with level 0.
--   #83 name (Error -> String) is the JS fallback constant "Error", not the
--       message (the string-Error model carries no name field).
--   #84 errorWithCause keeps the message pristine (the cause is unobservable
--       through this binding — there is no `cause` accessor — so it is dropped
--       rather than concatenated into the message).
--   #269 errorWithName was missing from the fork. Upstream takes the message
--        first and the name second (errorWithName(msg)(name)); the name is
--        dropped like errorWithCause's cause, so `name` keeps answering the
--        documented constant "Error".
--
-- `Effect a` in this backend is a zero-arg thunk that must be invoked to run.
-- Run from the repo root: `lua test/regression/exception.lua`.
local E = dofile("src/Effect/Exception.lua")

local failures = 0

local function check(name, cond, detail)
  if cond then
    print("ok   - " .. name)
  else
    failures = failures + 1
    print("FAIL - " .. name .. ": " .. tostring(detail))
  end
end

--------------------------------------------------------------------------------
-- #81 catchException runs the handler Effect and returns its value -----------

-- Handler has type (Error -> Effect a): it returns a thunk that, when run,
-- records a side effect and yields a value. catchException must invoke it.
do
  local ran = false
  local function handler(err)
    return function()
      ran = true
      return "handled:" .. E.message(err)
    end
  end
  local action = E.throwException(E.error("boom"))
  local result = E.catchException(handler)(action)()
  check("catchException returns a value, not a thunk", type(result) ~= "function", "got a " .. type(result))
  check("catchException runs the handler effect", ran == true, "handler effect never ran")
  check("catchException value is the handled result", result == "handled:boom", "got " .. tostring(result))
end

-- Success path is untouched: the action's value passes through.
do
  local result = E.catchException(function(_e) return function() return "unused" end end)(function() return 42 end)()
  check("catchException passes success through", result == 42, "got " .. tostring(result))
end

-- The library's own `try = catchException (pure <<< Left) (Right <$> action)`
-- shape: on a throw it must yield the Left table, not a function.
do
  local function leftHandler(err) return function() return {tag = "Left", value = err} end end
  local action = E.throwException(E.error("nope"))
  local r = E.catchException(leftHandler)(action)()
  check("try-shape yields Left, not a thunk", type(r) == "table" and r.tag == "Left", "got " .. type(r))
end

--------------------------------------------------------------------------------
-- #82 throwException preserves the message (no "chunk:line:" prefix) ----------

do
  local function idHandler(err) return function() return E.message(err) end end
  local recovered = E.catchException(idHandler)(E.throwException(E.error("boom")))()
  check("throwException preserves the message verbatim", recovered == "boom", "got " .. tostring(recovered))
end

--------------------------------------------------------------------------------
-- #83 name falls back to the constant "Error" --------------------------------

do check("name of a plain error is \"Error\"", E.name(E.error("boom")) == "Error", "got " .. tostring(E.name(E.error("boom")))) end

--------------------------------------------------------------------------------
-- #84 errorWithCause keeps the message pristine ------------------------------

do
  local e = E.errorWithCause("a")(E.error("b"))
  check("errorWithCause message is the supplied msg", E.message(e) == "a", "got " .. tostring(E.message(e)))
end

-- Sanity: message of a plain error is the message.
do check("message of a plain error", E.message(E.error("boom")) == "boom", "got " .. tostring(E.message(E.error("boom")))) end

--------------------------------------------------------------------------------
-- #269 errorWithName keeps the message; the name stays unobservable ----------

do
  local e = E.errorWithName("boom")("TypeError")
  check("errorWithName message is the supplied msg", E.message(e) == "boom", "got " .. tostring(E.message(e)))
  check("errorWithName name stays \"Error\"", E.name(e) == "Error", "got " .. tostring(E.name(e)))
end

--------------------------------------------------------------------------------

if failures > 0 then error(failures .. " regression check(s) failed") end
print("purescript-lua-exceptions: all FFI regression checks passed")
