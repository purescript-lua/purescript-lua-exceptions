return {
  showErrorImpl = (function(err) return err end),
  error = (function(msg) return msg end),
  errorWithCause = (function(msg)
    return function(_cause)
      -- `cause` is unobservable through this binding (no `cause` accessor), so
      -- keep the message pristine instead of folding the cause into it.
      return msg
    end
  end),
  errorWithName = (function(msg)
    return function(_name)
      -- The name is unobservable through this binding (`name` always answers
      -- the constant "Error"), so it is dropped like errorWithCause's cause.
      return msg
    end
  end),
  message = (function(err) return err end),
  name = (function(_err)
    -- JS `e.name || "Error"`; the string-Error model carries no name field.
    return "Error"
  end),
  stackImpl = (function() return function(nothing) return function() return nothing end end end),
  throwException = (function(err)
    -- Lua's `error(s)` at the default level prepends "chunk:line: " to a string
    -- message; level 0 keeps it verbatim across the pcall round-trip.
    return function() error(err, 0) end
  end),
  catchException = (function(c)
    return function(t)
      return function()
        local ok, errorOrResult = pcall(t)
        if ok then
          return errorOrResult
        else
          -- The handler has type (Error -> Effect a); run the returned Effect
          -- thunk (trailing `()`) so its side effects fire and we yield a value.
          return c(errorOrResult)()
        end
      end
    end
  end)
}
