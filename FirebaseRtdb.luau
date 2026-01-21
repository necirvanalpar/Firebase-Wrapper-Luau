--!strict
-- Firebase Realtime Database wrapper for Roblox Luau

--[[
MIT License

Copyright (c) 2026 Necrivan Alpar

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
]]

local HttpService = game:GetService("HttpService")

local Firebase = {}
Firebase.__index = Firebase

export type Config = {
	BaseUrl: string,     -- like https://xxx.firebaseio.com
	AuthToken: string?,  -- optional
	Timeout: number?,    -- optional (seconds)
	Debug: boolean?,     -- optional
}

export type Query = {
	orderBy: any?,        -- string like '"age"' or '"$key"'
	limitToFirst: number?,
	limitToLast: number?,
	startAt: any?,
	endAt: any?,
	equalTo: any?,
	shallow: boolean?,
	print: string?,       -- "silent" sometimes
}

-- Simple helper: clean base url
local function trimSlashEnd(url: string): string
	if url:sub(-1) == "/" then
		return url:sub(1, -2)
	end
	return url
end

-- Simple helper: remove first slash
local function trimSlashStart(s: string): string
	if s:sub(1, 1) == "/" then
		return s:sub(2)
	end
	return s
end

-- Make JSON safe for query (Firebase wants JSON style)
local function toFirebaseQueryValue(v: any): string
	-- Firebase query params use JSON encoding
	-- Example: orderBy="age" must be orderBy="\"age\"" (a JSON string)
	-- Example: equalTo=5 must be "5" (a JSON number)
	return HttpService:JSONEncode(v)
end

local function buildQueryString(q: Query?): string
	if not q then
		return ""
	end

	local parts = {}

	-- orderBy MUST be a JSON string like "\"age\"" or "\"$key\""
	if q.orderBy ~= nil then
		table.insert(parts, "orderBy=" .. HttpService:UrlEncode(toFirebaseQueryValue(q.orderBy)))
	end
	if q.limitToFirst ~= nil then
		table.insert(parts, "limitToFirst=" .. HttpService:UrlEncode(toFirebaseQueryValue(q.limitToFirst)))
	end
	if q.limitToLast ~= nil then
		table.insert(parts, "limitToLast=" .. HttpService:UrlEncode(toFirebaseQueryValue(q.limitToLast)))
	end
	if q.startAt ~= nil then
		table.insert(parts, "startAt=" .. HttpService:UrlEncode(toFirebaseQueryValue(q.startAt)))
	end
	if q.endAt ~= nil then
		table.insert(parts, "endAt=" .. HttpService:UrlEncode(toFirebaseQueryValue(q.endAt)))
	end
	if q.equalTo ~= nil then
		table.insert(parts, "equalTo=" .. HttpService:UrlEncode(toFirebaseQueryValue(q.equalTo)))
	end
	if q.shallow ~= nil then
		-- shallow is true/false (Firebase accepts shallow=true)
		table.insert(parts, "shallow=" .. HttpService:UrlEncode(tostring(q.shallow)))
	end
	if q.print ~= nil then
		table.insert(parts, "print=" .. HttpService:UrlEncode(q.print))
	end

	if #parts == 0 then
		return ""
	end

	return "?" .. table.concat(parts, "&")
end

-- Make final URL
function Firebase:_url(path: string, query: Query?): string
	-- Simple URL build
	local cleanPath = trimSlashStart(path)
	local url = self._baseUrl .. "/" .. cleanPath .. ".json"

	local qs = buildQueryString(query)

	-- Add auth token
	if self._authToken and self._authToken ~= "" then
		if qs == "" then
			qs = "?auth=" .. HttpService:UrlEncode(self._authToken)
		else
			qs = qs .. "&auth=" .. HttpService:UrlEncode(self._authToken)
		end
	end

	return url .. qs
end

-- Debug print
function Firebase:_log(...)
	if self._debug then
		print("[Firebase]", ...)
	end
end

-- Do one HTTP request
function Firebase:_request(method: string, url: string, bodyTable: any?): (boolean, any)
	-- This function sends HTTP
	-- It returns (ok, dataOrError)

	local body: string? = nil
	if bodyTable ~= nil then
		body = HttpService:JSONEncode(bodyTable)
	end

	local req = {
		Url = url,
		Method = method,
		Headers = {
			["Content-Type"] = "application/json",
		},
		Body = body,
	}

	self:_log(method, url)

	local ok, res = pcall(function()
		-- Use RequestAsync for all methods
		return HttpService:RequestAsync(req)
	end)

	if not ok then
		return false, ("Http error: " .. tostring(res))
	end

	if not res.Success then
		-- Try read error body
		local errText = res.Body or ("HTTP " .. tostring(res.StatusCode))
		return false, errText
	end

	-- Some calls return empty
	if res.Body == nil or res.Body == "" then
		return true, nil
	end

	-- Parse JSON
	local ok2, data = pcall(function()
		return HttpService:JSONDecode(res.Body)
	end)

	if not ok2 then
		-- Not JSON (rare)
		return true, res.Body
	end

	return true, data
end

-- Optional: retry wrapper
function Firebase:_requestWithRetry(method: string, url: string, bodyTable: any?): (boolean, any)
	-- This function tries more times
	-- It is simple retry

	local tries = 3
	local waitTime = 0.5

	for i = 1, tries do
		local ok, data = self:_request(method, url, bodyTable)
		if ok then
			return true, data
		end

		self:_log("Try fail", i, data)

		-- If last try, stop
		if i == tries then
			return false, data
		end

		task.wait(waitTime)
		waitTime *= 2
	end

	return false, "Unknown error"
end

-- Create wrapper
function Firebase.new(cfg: Config)
	-- This makes new client
	assert(cfg and cfg.BaseUrl, "BaseUrl is needed")

	local self = setmetatable({}, Firebase)

	self._baseUrl = trimSlashEnd(cfg.BaseUrl)
	self._authToken = cfg.AuthToken
	self._debug = cfg.Debug == true
	self._timeout = cfg.Timeout or 30

	return self
end

-- GET data (read)
function Firebase:Get(path: string, query: Query?): (boolean, any)
	-- This reads data
	local url = self:_url(path, query)
	return self:_requestWithRetry("GET", url, nil)
end

-- SET data (write full)
function Firebase:Set(path: string, value: any): (boolean, any)
	-- This writes all data (PUT)
	local url = self:_url(path, nil)
	return self:_requestWithRetry("PUT", url, value)
end

-- UPDATE data (patch)
function Firebase:Update(path: string, partial: any): (boolean, any)
	-- This updates some fields (PATCH)
	local url = self:_url(path, nil)
	return self:_requestWithRetry("PATCH", url, partial)
end

-- PUSH new child (post)
function Firebase:Push(path: string, value: any): (boolean, any)
	-- This makes new key (POST)
	-- Firebase returns { name = "newKey" }
	local url = self:_url(path, nil)
	return self:_requestWithRetry("POST", url, value)
end

-- DELETE data
function Firebase:Delete(path: string): (boolean, any)
	-- This removes data
	local url = self:_url(path, nil)
	return self:_requestWithRetry("DELETE", url, nil)
end

-- Helper: query by child value
function Firebase:QueryByChild(path: string, childName: string, q: {
	equalTo: any?,
	startAt: any?,
	endAt: any?,
	limitToFirst: number?,
	limitToLast: number?,
}): (boolean, any)
	-- This reads with query
	-- orderBy must be child name
	local query: Query = {
		orderBy = childName,
		equalTo = q.equalTo,
		startAt = q.startAt,
		endAt = q.endAt,
		limitToFirst = q.limitToFirst,
		limitToLast = q.limitToLast,
	}
	return self:Get(path, query)
end

-- Helper: query by key
function Firebase:QueryByKey(path: string, q: {
	equalTo: any?,
	startAt: any?,
	endAt: any?,
	limitToFirst: number?,
	limitToLast: number?,
}): (boolean, any)
	local query: Query = {
		orderBy = "$key",
		equalTo = q.equalTo,
		startAt = q.startAt,
		endAt = q.endAt,
		limitToFirst = q.limitToFirst,
		limitToLast = q.limitToLast,
	}
	return self:Get(path, query)
end

-- Helper: query by value
function Firebase:QueryByValue(path: string, q: {
	equalTo: any?,
	startAt: any?,
	endAt: any?,
	limitToFirst: number?,
	limitToLast: number?,
}): (boolean, any)
	local query: Query = {
		orderBy = "$value",
		equalTo = q.equalTo,
		startAt = q.startAt,
		endAt = q.endAt,
		limitToFirst = q.limitToFirst,
		limitToLast = q.limitToLast,
	}
	return self:Get(path, query)
end

return Firebase
