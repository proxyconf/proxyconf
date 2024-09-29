local md5 = require("md5")

-- Config gets filled by elixir
Config = {}

-- Function to decode Base64 string
local function base64_decode(input)
	local b = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
	input = string.gsub(input, "[^" .. b .. "=]", "")
	return (
		input
			:gsub(".", function(x)
				if x == "=" then
					return ""
				end
				local r, f = "", (b:find(x) - 1)
				for i = 6, 1, -1 do
					r = r .. (f % 2 ^ i - f % 2 ^ (i - 1) > 0 and "1" or "0")
				end
				return r
			end)
			:gsub("%d%d%d?%d?%d?%d?%d?%d?", function(x)
				if #x ~= 8 then
					return ""
				end
				local c = 0
				for i = 1, 8 do
					c = c + (x:sub(i, i) == "1" and 2 ^ (8 - i) or 0)
				end
				return string.char(c)
			end)
	)
end

local function validate_hash(value, hashes)
	if type(value) == "string" then
		local hash = md5.sumhexa(value)
		local entry = hashes[hash]
		if entry ~= nil and entry.client_id then
			return entry.client_id
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

	request_handle:headers():add("x-proxyconf-api-id", api_id)

	if api_id == nil or auth_type == nil or auth_field_name == nil then
		request_handle:logDebug(string.format("Downstream authentication disabled for API %s", "disabled-auth"))
		request_handle:streamInfo():dynamicMetadata():set("proxyconf.downstream_auth", "status", "noauth")
		return
	end

	local hashes = Config[to_key(api_id, auth_type, auth_field_name)]
	if hashes then
		local client_id = nil
		if auth_type == "header" then
			local header = request_handle:headers():get(auth_field_name)
			client_id = validate_hash(header, hashes)
		elseif auth_type == "query" then
			local path = request_handle:headers():get(":path")
			local query_param = get_query_parameter(path, auth_field_name)
			client_id = validate_hash(query_param, hashes)
		elseif auth_type == "basic" then
			local header = request_handle:headers():get(auth_field_name)
			local auth_scheme, encoded_credentials = header:match("^%s*(%S+)%s+(%S+)$")
			if auth_scheme == "Basic" or auth_scheme == "basic" then
				local basic_auth_credentials = base64_decode(encoded_credentials)
				client_id = validate_hash(basic_auth_credentials, hashes)
			end
		end
		if client_id ~= nil then
			request_handle:streamInfo():dynamicMetadata():set("proxyconf.downstream_auth", "client_id", client_id)
			request_handle:streamInfo():dynamicMetadata():set("proxyconf.downstream_auth", "status", "success")
			request_handle:logDebug(
				string.format(
					"Downstream authentication (%s:%s) success for API %s and client %s",
					auth_type,
					auth_field_name,
					api_id,
					client_id
				)
			)
			-- auth success
			return
		else
			-- auth failed
			request_handle:streamInfo():dynamicMetadata():set("proxyconf.downstream_auth", "status", "failed")
			-- no local response, let rbac do it
			--request_handle:respond({ [":status"] = "403" }, "Forbidden")
			request_handle:logDebug(
				string.format("Downstream authentication (%s:%s) failed for API %s", auth_type, auth_field_name, api_id)
			)
			return
		end
	end
	-- fall through
	request_handle:streamInfo():dynamicMetadata():set("proxyconf.downstream_auth", "status", "failed")
	request_handle:logDebug(
		string.format(
			"Downstream authentication (%s:%s) failed for API %s, due to no config found",
			auth_type,
			auth_field_name,
			api_id
		)
	)
end

function envoy_on_response(response_handle) end
