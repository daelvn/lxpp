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
local pairs, ipairs, print, tostring, table, string = pairs, ipairs, print, tostring, table, string

-- Take first argument as a file
local args = table.pack(...)

local argn, argl = args.n, function()
  args.n = nil
  local _argList = {}
  for k,a in pairs(args) do
    _argList[k] = a
  end
  return _argList
end
argl = argl()

if #argl < 1 then error("File was not passed") end
local lxppFileName = argl[1]

-- Debug mode
local _DEBUG = true

local function consoleLog(str)
  if _DEBUG then print(str) end
end

-- Storage that patterns can access
local lxppData = {}

-- Types of set variables
local variableTypes = {}
lxppData.variableTypes = variableTypes

-- Modes
local lxppModes = {
  ["lxpp.switch.open"] = false,
  ["lxpp.class.open"] = false,
  ["lxpp.try.open"] = false,
  ["lxpp.using.open"] = false,
}
lxppData.modes = lxppModes

-- Replace patterns (non-complex keywords)
local replacePatterns = {
  -- foreach
  {
    name      = "keyword.control.foreach.lxpp",
    condition = "foreach [a-zA-Z_][a-zA-Z0-9._]* in [a-zA-Z_][a-zA-Z0-9._]* do",
    capture   = {
                  ["1"] = "(each)",
                  ["2"] = "in ([a-zA-Z_][a-zA-Z0-9._]*)"
                },
    replace   = {
                  ["1"] = " _, ",
                  ["2"] = "in pairs( %1 )"
                }
  },
  -- namespace
  {
    name      = "storage.modifier.namespace.lxpp",
    condition = "namespace [a-zA-Z_][a-zA-Z0-9._]*",
    capture   = {
                  ["1"] = "namespace ([a-zA-Z_][a-zA-Z0-9._]*)",
                },
    replace   = {
                  ["1"] = "local %1 = {}",
                }
  },
  -- new
  {
    name      = "keyword.control.new.lxpp",
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
    name      = "keyword.operator.set.lxpp",
    condition = "[a-zA-Z_][a-zA-Z0-9._]* %?=",
    capture   = {
                  ["1"] = "([a-zA-Z_][a-zA-Z0-9._]*) %?=",
                },
    replace   = {
                  ["1"] = "%1 = %1 or",
                }
  },
  -- += / -= / *= / /=
  {
    name      = "keyword.operator.combined.lxpp",
    condition = "[a-zA-Z_][a-zA-Z0-9._]* [%+%-%*/]=",
    capture   = {
                  ["1"] = "([a-zA-Z_][a-zA-Z0-9._]*) ([%+%-%*/])=",
                },
    replace   = {
                  ["1"] = "%1 = %1 %2",
                }
  },
  -- private
  {
    name      = "storage.modifier.private.lxpp",
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
    name      = "keyword.control.switch.lxpp",
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
    name      = "keyword.control.switch.default.lxpp",
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
    name      = "keyword.control.switch.end.lxpp",
    condition = "end",
    modeCond  = "lxpp.switch.open",
    capture   = {
                  ["1"] = "end",
                },
    replace   = {
                  ["1"] = "} )",
                },
    rmMode    = "lxpp.switch.open"
  },
  -- try
  {
    name      = "keyword.control.try.lxpp",
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
    name      = "keyword.control.except.lxpp",
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
    name      = "keyword.control.try.end.lxpp",
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
    name      = "keyword.control.typecheck.lxpp",
    condition = "&[a-zA-Z_][a-zA-Z0-9_.]*",
    capture   = {
                  ["1"] = "&([a-zA-Z_][a-zA-Z0-9_.]*)",
                },
    replace   = {
                  ["1"] = "type(%1) == \"//variableTypes[%1]//\" and %1 or error(\"`%1` is not type `//variableTypes[%1]//`\")",
                }
  },
  -- using
  {
    name      = "keyword.control.using.lxpp",
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
    name      = "keyword.control.using.end.lxpp",
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
    name      = "keyword.control.with.if.lxpp",
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
    name      = "keyword.control.with.while.lxpp",
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
    name      = "keyword.control.with.lxpp",
    condition = "with [a-zA-Z_][a-zA-Z0-9_.]*",
    capture   = {
                  ["1"] = "with (.-) do",
                },
    replace   = {
                  ["1"] = "do local %1",
                }
  },
  -- class (Only metatable and return)
  {
    name      = "keyword.control.class.lxpp",
    condition = "class [a-zA-Z_][a-zA-Z0-9_.]*",
    addMode   = "lxpp.class.open"
  },
  {
    name      = "keyword.control.class.end.lxpp",
    condition = "end",
    modeCond  = "lxpp.class.open",
    capture   = {
                  ["1"] = "end",
                },
    replace   = {
                  ["1"] = "setmetatable(_object, self)\nself.__index = self\nreturn _object\nend",
                }
  }
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
      line = line:gsub(line:match ( m ), "local %1 %2 %3")
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
            lines[lc] = lines[lc]:gsub(m, "local %1 = {}\nfunction %1:new(_object)\n_object = _object or {}")
            noClass = false
          elseif types[i] == "extends" then
            lines[lc] = lines[lc]:gsub(m, "local %1 = {}\nfunction %1:new(_object)\n_object = _object or new %2")
            noClass = false
          elseif types[i] == "implements" then
            lines[lc] = lines[lc]:gsub(m, "local %1 = lxpp.implements( %2 )\nfunction %1:new(_object)\n_object = _object or {}")
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
            lines[lc] = lines[lc]:gsub(m, "_object.%1 %2 %3")
          elseif (blockTypes[i] == "method") or (blockTypes[i] == "private-method") then
            -- Generic method replacement, adapted for both private and local
            if blockTypes[i] == "method" then
              lines[lc] = lines[lc]:gsub(m, "self.%1 = function ")
            else
              lines[lc] = lines[lc]:gsub(m, "local %1 = function ")
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
                lines[lc]:gsub(mm, "%1")
              end
            end
          end
        end
      end
    end
    lc = lc + 1
  end
  return lines
end

-- Interface parsing
local function defineInterface (lines)
  -- Matches for the elements inside the interfaces
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
  local noInt = true
  while lc <= #lines do
    -- Iterate lines
    if noInt then
      -- Not inside an interface
      if lines[lc]:match( "interface ([a-zA-Z_][a-zA-Z0-9_.]*)" ) then
        lines[lc] = lines[lc]:gsub("interface ([a-zA-Z_][a-zA-Z0-9_.]*)", "local %1 = {")
        noInt = false
      end
    else
      -- Inside an interface, parse other elements
      for i, m in ipairs(blockMatches) do
        if lines[lc]:match( m ) then
          if blockTypes[i] == "property" then
            -- Simple property parsing
            lines[lc] = lines[lc]:gsub(m, "%1 %2 %3")
          elseif blockTypes == "private-property" then
            lines[lc] = lines[lc]:gsub(m, "_%1 %2 %3")
          elseif (blockTypes[i] == "method") or (blockTypes[i] == "private-method") then
            -- Generic method replacement, adapted for both private and local
            if blockTypes[i] == "method" then
              lines[lc] = lines[lc]:gsub(m, "%1 = function ")
            else
              lines[lc] = lines[lc]:gsub(m, "_%1 = function ")
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
                lines[lc] = lines[lc]:gsub(mm, "%1")
              end
            end
          end
        end
      end
    end
    lc = lc + 1
  end
  return lines
end

local function defineFunction (line)
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
  for i, m in ipairs(typeMatches) do
    for match, varName in line:gmatch( m ) do
      -- Add to the typecheck list
      variableTypes[varName] = types[i]
      -- Remove type signature
      line = line:gsub(m, "%1")
    end
    -- Rename define
    line = line:gsub("define ", "local function ")
  end
  return line
end

local function patternAccess (index)
  if index:match("([a-zA-Z_][a-zA-Z0-9_.]*)(%b%[%])") then
    local glob, name, id = index:match("([a-zA-Z_][a-zA-Z0-9_.]*)(%b%[%])")
    local insideId = id:match("[a-zA-Z_][a-zA-Z0-9_.]*")
    return lxppData[insideId]
  end
end

-- Iterative string.find
function string.ifind (s, pattern, _spos)
  local positions = {}
  local i = 0
  local e = 0
  while true do
    i,e = s:find(pattern, i+1)    -- find 'next' newline
    if i == nil then break end
    table.insert(positions, {i,e})
  end
  return positions
end


local function executePattern (scope, line)
  if line:match( scope.condition ) then -- Match the condition to execute it
    -- Check if it's inside of a string
    local stringPositions = string.ifind(line, "[^\\][\"'](.-)[^\\][\"']")
    local condPositions = string.ifind(line, scope.condition)
    for _,condPositionPair in ipairs(condPositions) do
      for _,stringPositionPair in ipairs(stringPositions) do
        if condPositionPair[1] >= stringPositionPair[1] then return line end
        if condPositionPair[2] <= stringPositionPair[2] then return line end
      end
    end
    --
    consoleLog("Using scope: "..scope.name)
    consoleLog("  Line: " .. line)
    if scope.modeCond then
      consoleLog("  ----------")
      consoleLog("  Condition: "..scope.condition)
      consoleLog("  Mode condition: "..scope.modeCond)
      consoleLog("  Found flag: "..tostring(lxppModes[ scope.modeCond ]))
      if not lxppModes[ scope.modeCond ] then
        consoleLog("  Mode condition was not matched. Returning line.")
        return line
      end
      if scope.addMode then lxppModes[scope.addMode] = true end
      if scope.rmMode then lxppModes[scope.rmMode] = nil end
      consoleLog( "  Mode condition was matched. Continuing.")
    end
    for ck, cm in pairs( scope.capture ) do
      for rk, rm in pairs( scope.replace ) do
        if ck == rk then
          if cm:match("//(.-)//") then
            local glob, index = cm:match("//(.-)//")
            cm:gsub("//.-//", patternAccess(index))
          end
          if not ck:match("%!$") then
            line = line:gsub(cm, rm)
          else
            if not line:match(cm) then
              line = line .. rm
            end
          end
        end
      end
    end
  end
  -- Return the line
  return line
end

-- Order of replacing
-- Classes <- file
-- Interfaces <- file
-- Functions <- line
-- Simple patterns <- line
local lxppFileLines = {}
do -- Classes
  for line in io.lines(lxppFileName) do
    table.insert(lxppFileLines, line)
  end
  lxppFileLines = defineClass ( lxppFileLines )
  lxppFileLines = defineInterface( lxppFileLines )
end
-- Everything else
while true do
  for i,l in ipairs(lxppFileLines) do
    lxppFileLines[i] = defineFunction( lxppFileLines[i] )
    for _, pattern in ipairs(replacePatterns) do
      lxppFileLines[i] = executePattern( pattern, lxppFileLines[i] )
    end
  end
  break
end

for i,l in ipairs(lxppFileLines) do
  consoleLog (i..": "..l)
end
