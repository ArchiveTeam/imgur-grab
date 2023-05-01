dofile("table_show.lua")
dofile("urlcode.lua")
local urlparse = require("socket.url")
local http = require("socket.http")
local https = require("ssl.https")
JSON = (loadfile "JSON.lua")()

local item_dir = os.getenv("item_dir")
local warc_file_base = os.getenv("warc_file_base")
local concurrency = tonumber(os.getenv("concurrency"))
local item_type = nil
local item_name = nil
local item_value = nil

if urlparse == nil or http == nil then
  io.stdout:write("socket not corrently installed.\n")
  io.stdout:flush()
  abortgrab = true
end

local url_count = 0
local tries = 0
local downloaded = {}
local addedtolist = {}
local abortgrab = false
local killgrab = false

local discovered_outlinks = {}
local discovered_items = {}
local bad_items = {}
local ids = {}

local retry_url = false

local postpagebeta = false

math.randomseed(os.time())

for ignore in io.open("ignore-list", "r"):lines() do
  downloaded[ignore] = true
end

abort_item = function(item)
  abortgrab = true
  if not item then
    item = item_name
  end
  if not bad_items[item] then
    io.stdout:write("Aborting item " .. item .. ".\n")
    io.stdout:flush()
    bad_items[item] = true
  end
end

kill_grab = function(item)
  io.stdout:write("Aborting crawling.\n")
  killgrab = true
end

read_file = function(file)
  if file then
    local f = assert(io.open(file))
    local data = f:read("*all")
    f:close()
    return data
  else
    return ""
  end
end

processed = function(url)
  if downloaded[url] or addedtolist[url] then
    return true
  end
  return false
end

discover_item = function(target, item)
  if not target[item] then
    if string.match(item, "boxsmall") then
      discover_item(target, string.gsub(item, "boxsmall", "boxlarge"))
    end
--print('discovered', item)
    target[item] = true
    return true
  end
  return false
end

find_item = function(url)
  local value = string.match(url, "^https?://imgur%.com/([a-zA-Z0-9]+)$")
  local type_ = "i"
  if not value then
    value = string.match(url, "^https?://imgur%.com/user/([a-zA-Z0-9%-_]+)$")
    type_ = "user"
  end
  if not value then
    value = string.match(url, "^https?://imgur%.com/gallery/([a-zA-Z0-9]+)$")
    type_ = "album"
  end
  if value then
    item_type = type_
    item_value = value
    item_name_new = item_type .. ":" .. item_value
    if item_name_new ~= item_name then
      ids = {}
      ids[value] = true
      abortgrab = false
      initial_allowed = false
      tries = 0
      retry_url = false
      item_name = item_name_new
      print("Archiving item " .. item_name)
    end
  end
end

allowed = function(url, parenturl)
  if ids[url] then
    return true
  end

  if string.match(url, "^https?://p%.imgur%.com/imageview%.gif%?") then
    return false
  end

  local search_string = "[a-zA-Z0-9]+"
  if item_type == "user" then
    search_string = "[a-zA-Z0-9%-_]+"
  end
  for s in string.gmatch(url, "(" .. search_string .. ")") do
    if ids[s] or ids[string.match(s, "^(.+).$")] then
      return true
    end
  end

  local id = string.match(url, "^https?://i%.imgur%.com/([a-zA-Z0-9]+)")
  if not id then
    id = string.match(url, "^https?://imgur%.com/([a-zA-Z0-9]+)")
  end
  local type_ = "i"
  if not id then
    id = string.match(url, "^https?://i%.imgur%.com/gallery/([a-zA-Z0-9]+)")
    type_ = "gallery"
  end
  if not id then
    id = string.match(url, "^https?://i%.imgur%.com/album/([a-zA-Z0-9]+)")
    type_ = "album"
  end
  if id then
    local len = string.len(id)
    if len == 2 or len == 3 or len == 4 or len == 6 or len == 8 then
      discover_item(discovered_items, type_ .. ":" .. string.match(id, "^(.+).$"))
    end
    if len == 1 or len == 2 or len == 3 or len == 4 or len == 5 or len == 7 then
      discover_item(discovered_items, type_ .. ":" .. id)
    end
  end
  if not id then
    id = string.match(url, "^https?://i%.imgur%.com/user/([a-zA-Z0-9%-_]+)")
    type_ = "album"
    if id then
      discover_item(discovered_items, type_ .. ":" .. id)
    end
  end

  if not string.match(url, "^https?://[^/]*imgur%.com/")
    and not string.match(url, "^https?://[^/]*imgur%.io/") then
    discover_item(discovered_outlinks, url)
  end

  return false
end

wget.callbacks.download_child_p = function(urlpos, parent, depth, start_url_parsed, iri, verdict, reason)
  local url = urlpos["url"]["url"]
  local html = urlpos["link_expect_html"]

  --[[if allowed(url, parent["url"]) and not processed(url) then
    addedtolist[url] = true
    return true
  end]]

  --[[if html == 0 then
    discover_item(discovered_outlinks, url)
  end]]

  return false
end

wget.callbacks.get_urls = function(file, url, is_css, iri)
  local urls = {}
  local html = nil
  
  downloaded[url] = true

  if abortgrab then
    return {}
  end

  local function decode_codepoint(newurl)
    newurl = string.gsub(
      newurl, "\\[uU]([0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F])",
      function (s)
        return unicode_codepoint_as_utf8(tonumber(s, 16))
      end
    )
    return newurl
  end

  local function fix_case(newurl)
    if not string.match(newurl, "^https?://.") then
      return newurl
    end
    if string.match(newurl, "^https?://[^/]+$") then
      newurl = newurl .. "/"
    end
    local a, b = string.match(newurl, "^(https?://[^/]+/)(.*)$")
    return string.lower(a) .. b
  end

  local function check(newurl)
    newurl = decode_codepoint(newurl)
    newurl = fix_case(newurl)
    if item_type == "i"
      and string.match(newurl, "/gallery/") then
      return nil
    end
    if not string.match(newurl, "/download/") then
      if string.match(newurl, "%%20") then
        return nil
      end
      if string.match(newurl, "%s") then
        for s in string.gmatch(newurl, "([^%s]+)") do
          check(s)
        end
        return nil
      end
    end
    local origurl = url
    if string.len(url) == 0 then
      return nil
    end
    local url = string.match(newurl, "^([^#]+)")
    local url_ = string.match(url, "^(.-)[%.\\]*$")
    while string.find(url_, "&amp;") do
      url_ = string.gsub(url_, "&amp;", "&")
    end
    if not processed(url_)
      and not processed(url_ .. "/")
      and allowed(url_, origurl) then
      table.insert(urls, { url=url_ })
      addedtolist[url_] = true
      addedtolist[url] = true
    end
  end

  local function checknewurl(newurl)
    newurl = decode_codepoint(newurl)
    if string.match(newurl, "['\"><]") then
      return nil
    end
    if string.match(newurl, "^https?:////") then
      check(string.gsub(newurl, ":////", "://"))
    elseif string.match(newurl, "^https?://") then
      check(newurl)
    elseif string.match(newurl, "^https?:\\/\\?/") then
      check(string.gsub(newurl, "\\", ""))
    elseif string.match(newurl, "^\\/\\/") then
      checknewurl(string.gsub(newurl, "\\", ""))
    elseif string.match(newurl, "^//") then
      check(urlparse.absolute(url, newurl))
    elseif string.match(newurl, "^\\/") then
      checknewurl(string.gsub(newurl, "\\", ""))
    elseif string.match(newurl, "^/") then
      check(urlparse.absolute(url, newurl))
    elseif string.match(newurl, "^%.%./") then
      if string.match(url, "^https?://[^/]+/[^/]+/") then
        check(urlparse.absolute(url, newurl))
      else
        checknewurl(string.match(newurl, "^%.%.(/.+)$"))
      end
    elseif string.match(newurl, "^%./") then
      check(urlparse.absolute(url, newurl))
    end
  end

  local function checknewshorturl(newurl)
    newurl = decode_codepoint(newurl)
    if string.match(newurl, "^%?") then
      check(urlparse.absolute(url, newurl))
    elseif not (
      string.match(newurl, "^https?:\\?/\\?//?/?")
      or string.match(newurl, "^[/\\]")
      or string.match(newurl, "^%./")
      or string.match(newurl, "^[jJ]ava[sS]cript:")
      or string.match(newurl, "^[mM]ail[tT]o:")
      or string.match(newurl, "^vine:")
      or string.match(newurl, "^android%-app:")
      or string.match(newurl, "^ios%-app:")
      or string.match(newurl, "^data:")
      or string.match(newurl, "^irc:")
      or string.match(newurl, "^%${")
    ) then
      check(urlparse.absolute(url, newurl))
    end
  end

  if item_type == "i" then
    local a, b = string.match(url, "^(https?://i%.imgur%.com/[a-zA-Z0-9]+)([^%?]-)$")
    if a and b and string.match(a, "/([a-zA-Z0-9]+)$") == item_value then
      for _, char in pairs({"", "b", "g", "h", "l", "m", "r", "s", "t"}) do
        check(a .. char .. ".jpg")
      end
      check(a .. "_d.webp?maxwidth=128&shape=square")
      check(a .. "_d.webp?maxwidth=760&fidelity=grand")
      check(a .. "_d.png?maxwidth=200&fidelity=grand")
      check(a .. "_d.png?maxwidth=520&shape=thumb&fidelity=high")
    end
    if string.match(url, item_value .. "%.mp4$") then
      check(string.gsub(url, "%.mp4", "_lq%.mp4"))
      --check(string.gsub(url, "%.mp4", "_hq%.mp4"))
    end
  end

  local function process_data(data)
    if type(data) == "string" then
      return '\n"' .. data .. '"\n'
    elseif type(data) == "table" then
      for k, v in pairs(data) do
        return process_data(k) .. process_data(v)
      end
    else
      return "\n"
    end
  end

  if allowed(url)
    and (
      status_code < 300
      or string.match(url, "^https?://api%.imgur%.com/")
    )
    and not (string.match(url, "^https?://i%.imgur%.com/") and not string.match(url, "%.gifv"))
    and not string.match(url, "^https?://p%.imgur%.com/")
    and not string.match(url, "/download/") then
    html = read_file(file)
    local json = nil
    if string.match(url, "^https?://imgur%.com/[a-zA-Z0-9]+$") then
      local canonical_url = string.match(html, '<link%s+rel="canonical"%s+href="([^"]+)"')
      if string.match(canonical_url, "/gallery/" .. item_value) then
        io.stdout:write("This is both an i and gallery item.\n")
        io.stdout:flush()
        discover_item(discovered_items, "gallery:" .. item_value)
        html = string.gsub(html, '"https?://[^/]+/gallery/', '"')
        --local json = string.match(html, "<script>%s*window%.postDataJSON%s*=%s*'({.-})';%s*</script>")
      end
    end
    if item_type == "i" or item_type == "gallery" or item_type == "album" then
      check("https://p.imgur.com/imageview.gif?a=" .. item_value .. "&r=&g=true")
    end
    if postpagebeta then
      -- for without using the postpagebeta cookie
      local client_id = "546c25a59c58ad7"
      if string.match(url, "^https?://api%.imgur%.com/") then
        json = JSON:decode(html)
        if json["error"] or json["errors"] then
          abort()
        end
        html = html .. process_data(json)
      end
      if string.match(url, "^https?://api%.imgur%.com/post/v1/[a-z]+/[a-zA-Z0-9]+%?") then
        if not json then
          json = JSON:decode(html)
        end
        if i_json["id"] ~= item_value then
          io.stdout:write("API data for wrong ID?\n")
          io.stdout:flush()
          abort()
        end
        local type_name = string.match(url, "/post/v1/([a-z]+)/")
        if type_name == "media" then
          check("https://imgur.com/download/" .. item_value .. "/")
          check("https://imgur.com/download/" .. item_value .. "/" .. json["title"])
        elseif type_name == "posts" then
          check("https://imgur.com/a/" .. item_value .. "/zip")
        else
          io.stdout:write("API endpoint not known.\n")
          io.stdout:flush()
          abort()
        end
        for _, data in pairs(json["media"]) do
          discover_item(discovered_items, "i:" .. data["id"])
        end
        if json["account"] then
          discover_item(discovered_items, "user:" .. json["account"]["username"])
        end
      end
      if string.match(url, "^https?://imgur%.com/[a-zA-Z0-9]+$") then
        for _, include in pairs({
          "media,adconfig,account",
          "media,adconfig,account,cover"
        }) do
          include = string.gsub(include, ",", "%%2C")
          check("https://api.imgur.com/post/v1/media/" .. item_value .. "?client_id=" .. client_id .. "&include=" .. include)
        end
        check("https://imgur.com/" .. item_value .. "/embed?context=false&ref=https%3A%2F%2Fimgur.com%2F" .. item_value .. "&w=523")
        check("https://imgur.com/" .. item_value .. "/embed?ref=https%3A%2F%2Fimgur.com%2F" .. item_value .. "&w=523")
      end
      if string.match(url, "^https?://imgur%.com/gallery/[a-zA-Z0-9]+$") then
        for _, include in pairs({
          "post,user,accolades",
        }) do
          include = string.gsub(include, ",", "%%2C")
          check("https://api.imgur.com/post/v1/posts/" .. item_value .. "?client_id=" .. client_id .. "&include=" .. include)
          check("https://api.imgur.com/post/v1/posts/" .. item_value .. "/meta?client_id=" .. client_id .. "&include=" .. include)
        end
        check("https://imgur.com/a/" .. item_value .. "/embed?pub=true&ref=https%3A%2F%2Fimgur.com%2Fgallery%2F" .. item_value .. "&w=523")
        check("https://imgur.com/a/" .. item_value .. "/embed?pub=true&ref=https%3A%2F%2Fimgur.com%2Fgallery%2F" .. item_value .. "&context=false&w=523")
        -- todo comments, download
      end
    else
      if string.match(url, "^https?://imgur%.com/[a-zA-Z0-9]+$") then
        local json = string.match(html, "item%s*:%s*({.-})%s*};")
        json = JSON:decode(json)
        if json["account_url"] then
          discover_item(discovered_items, "user:" .. json["account_url"])
        end
        check("https://imgur.com/download/" .. item_value .. "/")
        check("https://imgur.com/download/" .. item_value .. "/" .. json["title"])
        check("https://imgur.com/" .. item_value .. "/embed?ref=https%3A%2F%2Fimgur.com%2F" .. item_value .. "&analytics=false&w=500")
        check("https://imgur.com/" .. item_value .. "/embed?context=false&ref=https%3A%2F%2Fimgur.com%2F" .. item_value .. "&analytics=false&w=500")
      end
    end
    html = string.gsub(html, "\\", "")
    for newurl in string.gmatch(string.gsub(html, "&quot;", '"'), '([^"]+)') do
      checknewurl(newurl)
    end
    for newurl in string.gmatch(string.gsub(html, "&#039;", "'"), "([^']+)") do
      checknewurl(newurl)
    end
    for newurl in string.gmatch(html, "[^%-]href='([^']+)'") do
      checknewshorturl(newurl)
    end
    for newurl in string.gmatch(html, '[^%-]href="([^"]+)"') do
      checknewshorturl(newurl)
    end
    for newurl in string.gmatch(html, ":%s*url%(([^%)]+)%)") do
      checknewurl(newurl)
    end
    html = string.gsub(html, "&gt;", ">")
    html = string.gsub(html, "&lt;", "<")
    for newurl in string.gmatch(html, ">%s*([^<%s]+)") do
      checknewurl(newurl)
    end
  end

  return urls
end

wget.callbacks.write_to_warc = function(url, http_stat)
  status_code = http_stat["statcode"]
  find_item(url["url"])
  if not item_name then
    error("No item name found.")
  end
  if (
      (
        http_stat["len"] == 0
        and status_code == 200
      )
      or (
        status_code ~= 200
        and status_code ~= 301
        and status_code ~= 302
      )
    )
    and not (
      status_code == 404
      and string.match(url["url"], "/download/[^/]+/.")
    ) then
    print("Not writing to WARC.")
    retry_url = true
    return false
  end
  if abortgrab then
    print("Not writing to WARC.")
    return false
  end
  retry_url = false
  tries = 0
  return true
end

wget.callbacks.httploop_result = function(url, err, http_stat)
  status_code = http_stat["statcode"]
  
  url_count = url_count + 1
  io.stdout:write(url_count .. "=" .. status_code .. " " .. url["url"] .. " \n")
  io.stdout:flush()

  if killgrab then
    return wget.actions.ABORT
  end

  find_item(url["url"])

  if status_code >= 300 and status_code <= 399 then
    local newloc = urlparse.absolute(url["url"], http_stat["newloc"])
    if processed(newloc) or not allowed(newloc, url["url"]) then
      tries = 0
      return wget.actions.EXIT
    end
  end
  
  if status_code < 400 then
    downloaded[url["url"]] = true
  end

  if abortgrab then
    abort_item()
    return wget.actions.EXIT
  end

  if status_code == 0 or retry_url then
    io.stdout:write("Server returned bad response. Sleeping.\n")
    io.stdout:flush()
    tries = tries + 1
    if tries > 6 or status_code == 404 then
      tries = 0
      abort_item()
      return wget.actions.EXIT
    end
    local sleep_time = math.random(
      math.floor(math.pow(2, tries-0.5)),
      math.floor(math.pow(2, tries))
    )
    io.stdout:write("Sleeping " .. sleep_time .. " seconds.\n")
    io.stdout:flush()
    os.execute("sleep " .. sleep_time)
    return wget.actions.CONTINUE
  end

  tries = 0

  return wget.actions.NOTHING
end

wget.callbacks.finish = function(start_time, end_time, wall_time, numurls, total_downloaded_bytes, total_download_time)
  local function submit_backfeed(items, key)
    local tries = 0
    local maxtries = 10
    while tries < maxtries do
      if killgrab then
        return false
      end
      local body, code, headers, status = http.request(
        "https://legacy-api.arpa.li/backfeed/legacy/" .. key,
        items .. "\0"
      )
      if code == 200 and body ~= nil and JSON:decode(body)["status_code"] == 200 then
        io.stdout:write(string.match(body, "^(.-)%s*$") .. "\n")
        io.stdout:flush()
        return nil
      end
      io.stdout:write("Failed to submit discovered URLs." .. tostring(code) .. tostring(body) .. "\n")
      io.stdout:flush()
      os.execute("sleep " .. math.floor(math.pow(2, tries)))
      tries = tries + 1
    end
    kill_grab()
    error()
  end

  local file = io.open(item_dir .. "/" .. warc_file_base .. "_bad-items.txt", "w")
  for url, _ in pairs(bad_items) do
    file:write(url .. "\n")
  end
  file:close()
  for key, data in pairs({
    ["imgur-q1gas93rfxdu4rah"] = discovered_items,
    ["urls-b6darc9ffjxd2b6k"] = discovered_outlinks
  }) do
    print('queuing for', string.match(key, "^(.+)%-"))
    local items = nil
    local count = 0
    for item, _ in pairs(data) do
      print("found item", item)
      if items == nil then
        items = item
      else
        items = items .. "\0" .. item
      end
      count = count + 1
      if count == 100 then
        submit_backfeed(items, key)
        items = nil
        count = 0
      end
    end
    if items ~= nil then
      submit_backfeed(items, key)
    end
  end
end

wget.callbacks.before_exit = function(exit_status, exit_status_string)
  if killgrab then
    return wget.exits.IO_FAIL
  end
  if abortgrab then
    abort_item()
  end
  return exit_status
end

