-- Reads JSON into Lua tables: json.decode(text) -> value, or nil and an error message.
-- Enough for keys.json and settings.json (objects, arrays, strings, numbers, true/false/null).

local json = {}

local escapes = { ['"'] = '"', ["\\"] = "\\", ["/"] = "/", b = "\b", f = "\f", n = "\n", r = "\r", t = "\t" }

local function decode(s)
    local i = 1

    local function fail(what) error(("json: %s at character %d"):format(what, i), 0) end
    local function skip() i = s:find("[^ \t\r\n]", i) or #s + 1 end

    local value

    local function str()
        local out = {}
        i = i + 1
        while true do
            local c = s:sub(i, i)
            if c == "" then fail("unfinished string") end
            if c == '"' then i = i + 1; return table.concat(out) end
            if c == "\\" then
                local e = s:sub(i + 1, i + 1)
                if e == "u" then
                    out[#out + 1] = utf8.char(tonumber(s:sub(i + 2, i + 5), 16) or fail("bad \\u escape"))
                    i = i + 6
                else
                    out[#out + 1] = escapes[e] or fail("bad escape")
                    i = i + 2
                end
            else
                out[#out + 1] = c
                i = i + 1
            end
        end
    end

    local function list(close, item)
        i = i + 1
        skip()
        if s:sub(i, i) == close then i = i + 1; return end
        while true do
            item()
            skip()
            local c = s:sub(i, i)
            i = i + 1
            if c == close then return end
            if c ~= "," then fail("expected , or " .. close) end
        end
    end

    value = function()
        skip()
        local c = s:sub(i, i)
        if c == "{" then
            local t = {}
            list("}", function()
                skip()
                if s:sub(i, i) ~= '"' then fail("expected a key") end
                local k = str()
                skip()
                if s:sub(i, i) ~= ":" then fail("expected :") end
                i = i + 1
                t[k] = value()
            end)
            return t
        elseif c == "[" then
            local t = {}
            list("]", function() t[#t + 1] = value() end)
            return t
        elseif c == '"' then
            return str()
        end
        for word, v in pairs({ ["true"] = true, ["false"] = false, null = json.null }) do
            if s:sub(i, i + #word - 1) == word then i = i + #word; return v end
        end
        local num = s:match("^-?%d+%.?%d*[eE]?[-+]?%d*", i)
        if not num or num == "" then fail("unexpected " .. (c == "" and "end" or c)) end
        i = i + #num
        return tonumber(num)
    end

    local v = value()
    skip()
    if i <= #s then fail("text after the value") end
    return v
end

-- null inside arrays and objects (a plain nil would make a hole)
json.null = setmetatable({}, { __tostring = function() return "null" end })

function json.decode(text)
    local ok, v = pcall(decode, text)
    if ok then return v end
    return nil, v
end

-- The decoded contents of a file, or nil and why not.
function json.read(path)
    local f, err = io.open(path)
    if not f then return nil, err end
    local text = f:read("a")
    f:close()
    return json.decode(text)
end

return json
