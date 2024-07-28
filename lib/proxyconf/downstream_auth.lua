local md5 = require("md5")

-- Config gets filled by elixir
Config = {}

local function validate_hash(value, hashes)
  if type(value) == "string" then
    local hash = md5.sumhexa(value)
    print("hash", hash)
    local client = hashes[hash]
    if client ~= nil and client.allow then
      return client
    end
    return nil
  end
end

local function get_query_parameter(query_string, parameter_name)
  for key, val in query_string:gmatch("([^&=?]-)=([^&=?]+)") do
    key = key:gsub("=+.*$", "")
    key = key:gsub("%s", "_") -- remove spaces in parameter name
    if key == parameter_name then
      val = val:gsub("^=+", "")
      return val
    end
  end
  return nil
end

local function to_key(api_id, auth_type, auth_field_name)
  return api_id .. ":" .. auth_type .. ":" .. auth_field_name
end

-- Note: Cache the result of the schema compilation as this is quite expensive
function envoy_on_request(request_handle)
  local metadata = request_handle:metadata()
  local api_id = metadata:get("api_id")
  local auth_type = metadata:get("auth_type")
  local auth_field_name = metadata:get("auth_field_name")

  if api_id == nil or auth_type == nil or auth_field_name == nil then
    request_handle:streamInfo():dynamicMetadata():set("proxyconf.downstream_auth", "status", "noauth")
    print("No Downstream Auth Config found")
    return
  end

  local hashes = Config[to_key(api_id, auth_type, auth_field_name)]
  if hashes then
    local client = nil
    if auth_type == "header" then
      local header = request_handle:headers():get(auth_field_name)
      client = validate_hash(header, hashes)
    elseif auth_type == "query" then
      local path = request_handle:headers():get(":path")
      local query_param = get_query_parameter(path, auth_field_name)
      client = validate_hash(query_param, hashes)
    end
    if client ~= nil then
      request_handle:streamInfo():dynamicMetadata():set("proxyconf.downstream_auth", "client_id", client.id)
      request_handle:streamInfo():dynamicMetadata():set("proxyconf.downstream_auth", "status", "success")
      -- auth success
      return
    else
      -- auth failed
      request_handle:streamInfo():dynamicMetadata():set("proxyconf.downstream_auth", "status", "failed")
      request_handle:respond({ [":status"] = "403" }, "Forbidden")
      return
    end
  end
  -- fall through
  request_handle:streamInfo():dynamicMetadata():set("proxyconf.downstream_auth", "status", "failed")
  request_handle:respond({ [":status"] = "401" }, "Unauthorized")
end

function envoy_on_response(response_handle) end
