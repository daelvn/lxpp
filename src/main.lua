--[[
lxpp | Lua Extra Pre-processor
     | Pantheon Project

Filename
  main.lua
Author
  Cristian Muñiz (daelvn@gmail.com)
Version
  lxpp-0.1
License
  MIT License
Description
  lxpp is a macro pre-processor for Lua, aiming to close cleaner and easier code
]]--

-- Linter: Make local
local pairs, ipairs = pairs, ipairs

-- Take first argument as a file
local args = table.pack(...)

local argn, argl = args.n, function()
  args.n = nil
  local _argList
  for k,a in pairs(args) do
    _argList[k] = a
  end
end
argl = argl()

if #argl < 1 then error("File was not passed") end
local lxppFileName = argl[1]

-- Types of set variables
local variableTypes = {}

-- Replace patterns (non-complex keywords)
local replacePatterns = {
  -- foreach
  {
    condition = "foreach [a-zA-Z_][a-zA-Z0-9._]* in [a-zA-Z_][a-zA-Z0-9._]* do",
    capture   = {
                  ["1"] = "(each)",
                  ["2"] = "in ([a-zA-Z_][a-zA-Z0-9._]*)"
                },
    replace   = {
                  ["1"] = " _, ",
                  ["2"] = "pairs( %1 )"
                }
  },
  -- namespace
  {
    condition = "namespace [a-zA-Z_][a-zA-Z0-9._]*",
    capture   = {
                  ["1"] = "namespace",
                  ["2"] = "([a-zA-Z_][a-zA-Z0-9._]*)"
                },
    replace   = {
                  ["1"] = "local",
                  ["2"] = "%1 = {}"
                }
  },
  -- new
  {
    condition = "= new [a-zA-Z_][a-zA-Z0-9._]*",
    capture   = {
                  ["1"] = "new ([a-zA-Z_][a-zA-Z0-9._]*)",
                  ["2!"] = "(%b{})"
                },
    replace   = {
                  ["1"] = "%1:new ",
                  ["2!"] = "()"
                }
  },
  -- ?=
  {
    condition = "[a-zA-Z_][a-zA-Z0-9._]* %?=",
    capture   = {
                  ["1"] = "([a-zA-Z_][a-zA-Z0-9._]*) %?=",
                },
    replace   = {
                  ["1"] = "%1 = %1 or ",
                }
  },
  -- += / -= / *= / /=
  {
    condition = "[a-zA-Z_][a-zA-Z0-9._]* [+-*/]=",
    capture   = {
                  ["1"] = "([a-zA-Z_][a-zA-Z0-9._]*) ([+-*/])=",
                },
    replace   = {
                  ["1"] = "%1 = %1 %2 ",
                }
  },
  -- private
  {
    condition = "private",
    capture   = {
                  ["1"] = "private",
                },
    replace   = {
                  ["1"] = "local",
                }
  },
  -- switch
  {
    condition = "switch [a-zA-Z_][a-zA-Z0-9._]*",
    capture   = {
                  ["1"] = "switch ([a-zA-Z_][a-zA-Z0-9_.]*)",
                },
    replace   = {
                  ["1"] = "lxpp.switch(%1, {", -- Remember to end with } ) in `end`
                },
    addMode   = "lxpp.switch.open"
  },
  -- default
  {
    condition = "default do",
    modeCond  = "lxpp.switch.open",
    capture   = {
                  ["1"] = "default do",
                },
    replace   = {
                  ["1"] = "\"_default_\" = function() ",
                }
  },
  -- End Switch
  {
    condition = "end",
    modeCond  = "lxpp.switch.open",
    capture   = {
                  ["1"] = "end",
                },
    replace   = {
                  ["1"] = "",
                },
    rmMode    = "lxpp.switch.open"
  },
  -- try
  {
    condition = "try",
    capture   = {
                  ["1"] = "try",
                },
    replace   = {
                  ["1"] = "do local _status, _err = pcall(function()",
                },
    addMode   = "lxpp.try.open"
  },
  -- except
  {
    condition = "except",
    modeCond  = "lxpp.try.open",
    capture   = {
                  ["1"] = "except",
                },
    replace   = {
                  ["1"] = "end ) \nif not _status then pcall(function()",
                }
  },
  -- End Try
  {
    condition = "end",
    modeCond  = "lxpp.try.open",
    capture   = {
                  ["1"] = "end",
                },
    replace   = {
                  ["1"] = "end ) end",
                },
    rmMode    = "lxpp.try.open"
  },
  -- Typecheck (needs a complex capture for the variable type to be set)
  {
    condition = "&[a-zA-Z_][a-zA-Z0-9_.]*",
    capture   = {
                  ["1"] = "&([a-zA-Z_][a-zA-Z0-9_.]*)",
                },
    replace   = {
                  ["1"] = "type(%1) == \"//lxpp.variableTypes['%1']//\" and %1 or error(\"`%1` is not type `//lxpp.variableTypes['%1']//`\")",
                }
  },
  -- using
  {
    condition = "using",
    capture   = {
                  ["1"] = "using",
                  ["2"] = "do",
                },
    replace   = {
                  ["1"] = "do local",
                  ["2"] = "\nlocal _status, _err = pcall(function()"
                },
    addMode   = "lxpp.using.open"
  },
  -- End Using
  {
    condition = "end",
    modeCond  = "lxpp.using.open",
    capture   = {
                  ["1"] = "end",
                },
    replace   = {
                  ["1"] = ")\nif not _status then error(\"`using` statement failed\") end\nend",
                },
    rmMode    = "lxpp.using.open"
  },
  -- if with
  {
    condition = "if with [a-zA-Z_][a-zA-Z0-9_.]*",
    capture   = {
                  ["1"] = "if with ([a-zA-Z_][a-zA-Z0-9_.]*%s*=%s*(.-)) then",
                },
    replace   = {
                  ["1"] = "if %2 then\n  local %1",
                }
  },
  -- while with
  {
    condition = "while with [a-zA-Z_][a-zA-Z0-9_.]*",
    capture   = {
                  ["1"] = "while with ([a-zA-Z_][a-zA-Z0-9_.]*%s*=%s*(.-)) do",
                },
    replace   = {
                  ["1"] = "while %2 do\n  local %1",
                }
  },
  -- with
  {
    condition = "with [a-zA-Z_][a-zA-Z0-9_.]*",
    capture   = {
                  ["1"] = "with (.-) do",
                },
    replace   = {
                  ["1"] = "do local %1",
                }
  },
}

-- Special functions for complex keywords
-- local type name = value
local function declareVariableType (line)
  local matches = {
    "local string ([a-zA-Z_][a-zA-Z0-9_.]*)%s*([?]*=)%s*(.-)",
    "local number ([a-zA-Z_][a-zA-Z0-9_.]*)%s*([?]*=)%s*(.-)",
    "local table ([a-zA-Z_][a-zA-Z0-9_.]*)%s*([?]*=)%s*(.-)",
    "local boolean ([a-zA-Z_][a-zA-Z0-9_.]*)%s*([?]*=)%s*(.-)",
    "local any ([a-zA-Z_][a-zA-Z0-9_.]*)%s*([?]*=)%s*(.-)",
  }
  local types = {
    "string", "number", "table", "boolean", "any"
  }
  for i, m in ipairs(matches) do
    if line:match( m ) then
      local whole, id, value = line:match( m )
      variableTypes[id] = types[i]
      line = line:replace(line:match ( m ), "local %1 %2 %3")
    end
  end
  return line
end

-- Classes, Extends, Implements
local function defineClass (lines)
  -- Matches for the classes
  local matches = {
    "class ([a-zA-Z_][a-zA-Z0-9_.]*)",
    "class ([a-zA-Z_][a-zA-Z0-9_.]*) extends ([a-zA-Z_][a-zA-Z0-9_.]*)",
    "class ([a-zA-Z_][a-zA-Z0-9_.]*) implements (.+)"
  }
  local types = {
    "normal",
    "extended",
    "implemented"
  }
  -- Matches for the elements inside the classes
  local blockMatches = {
    "[^p][^r][^i][^v][^a][^t][^e][^ ]([a-zA-Z_][a-zA-Z0-9_.]*)%s*([?]*=)%s*(.+)",
    "private ([a-zA-Z_][a-zA-Z0-9_.]*)%s*([?]*=)%s*(.+)",
    "[^p][^r][^i][^v][^a][^t][^e][^ ]method ([a-zA-Z_][a-zA-Z0-9_.]*)",
    "private method ([a-zA-Z_][a-zA-Z0-9_.]*)"
  }
  local blockTypes = {
    "property",
    "private-property",
    "method",
    "private-method"
  }
  -- Loop variables
  local lc = 1
  local markers = {}
  local noClass = true
  while lc <= #lines do
    -- Iterate lines
    if noClass then
      -- Not inside a class, find for a class
      for i, m in ipairs(matches) do
        if lines[lc]:match( m ) then
          local marker = {}
          marker.type = "lxpp.class.start"
          marker.location = lc
          --
          if types[i] == "normal" then
            lines[lc] = lines[lc]:replace(m, "local %1 = {}\nfunction %1:new(_object)\n_object = _object or {}")
            noClass = false
          elseif types[i] == "extends" then
            lines[lc] = lines[lc]:replace(m, "local %1 = {}\nfunction %1:new(_object)\n_object = _object or new %2")
            noClass = false
          elseif types[i] == "implements" then
            lines[lc] = lines[lc]:replace(m, "local %1 = lxpp.implements( %2 )\nfunction %1:new(_object)\n_object = _object or {}")
            noClass = false
          end
        end
      end
    else
      -- Inside a class, parse other elements
      for i, m in ipairs(blockMatches) do
        if lines[lc]:match( m ) then
          if blockTypes[i] == "property" then
            -- Simple property parsing
            lines[lc] = lines[lc]:replace(m, "_object.%1 %2 %3")
          elseif (blockTypes[i] == "method") or (blockTypes[i] == "private-method") then
            -- Generic method replacement, adapted for both private and local
            if blockTypes[i] == "method" then
              lines[lc] = lines[lc]:replace(m, "self.%1 = function ")
            else
              lines[lc] = lines[lc]:replace(m, "local %1 = function ")
            end
            -- Matches for argument types
            local typeMatches = {
              "string ([a-zA-Z_][a-zA-Z0-9_.]*)",
              "number ([a-zA-Z_][a-zA-Z0-9_.]*)",
              "table ([a-zA-Z_][a-zA-Z0-9_.]*)",
              "boolean ([a-zA-Z_][a-zA-Z0-9_.]*)",
              "any ([a-zA-Z_][a-zA-Z0-9_.]*)"
            }
            local types = {
              "string",
              "number",
              "table",
              "boolean",
              "any"
            }
            -- Match the arguments' types
            for ii, mm in ipairs(typeMatches) do
              for match, varName in lines[lc]:gmatch( mm ) do
                -- Add to the typecheck list
                variableTypes[varName] = types[ii]
                -- Remove type signature
                lines[lc]:replace(mm, "%1")
              end
            end
          end
        end
      end
    end
  end
end
