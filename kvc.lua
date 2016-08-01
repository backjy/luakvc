

local KVCCenter = {}

 -- 初始化操作
function KVCCenter:init()
	local observers = {}
	-- 存放观察者 当观察者为nil 的时候就自动释放
	setmetatable(observers, {__mode = "k"})
	self._observers = observers
	self._arrayFlag = "_"
	-- 当有key 发生变化时会屌用_setter 函数实现 value valueChanged 的监听
	self._setter = function( t, key, value)
		local oldValue = rawget( t, key)
		rawset( t, key, value)
		local observerKey = key
		if type( key) == "number" then
			observerKey = self._arrayFlag
		end
		self:_valueChanged( t, observerKey, value, oldValue)
		self:_valueChanged( t, "*", value, oldValue)
	end
	-- 所有的key 共享一个元表
	self._weakMt = { __mode = "k"}
	-- 
	self._defaultCreator = function( keypath, subkey)
		return {}
	end
end
 
-- 私有函数
-- 检查被观察者的元表 如果元表为nil 创建一个元表
-- 在给元表的 __newindex设置为 self._setter
-- @param target 被观察者
function KVCCenter:_setMetatable( target)
	local mt = getmetatable( target)
	if mt == nil then
		mt = {}
		setmetatable( target, mt)
	end	
	if mt.__newindex ~= self._setter then
		mt.__newindex = self._setter
	end
end			

-- 添加一个观察者
-- @param target table 被观察者
-- @param key string｜number 当被观察者key 发生变化时触发
-- @param observer function｜table 观察者 观察者会被设置到key为weak的table 需要自己添加引用
-- 		如果observer 是function 产生call 的参数为 observer( key, newValue, oldValue)
-- 		如果observer 是table 则需要指定 func 参数 那么call 的参数为 func( observer, key, newValue, oldValue)
-- @param func function observer 是table 时的回调函数
function KVCCenter:addObserver( target, key, observer, func)
	if target == nil or observer == nil or key == "" then return false end
	self:_setMetatable( target)
	local observerData = self._observers[target]
	if observerData == nil then
		observerData = {}
		self._observers[target] = observerData
	end
	local keyObservers = observerData[key]
	if keyObservers == nil then
		keyObservers = {}
		setmetatable( keyObservers, self._weakMt)
		observerData[key] = keyObservers
	end
	-- 回调方式 1 代表回调一个 table 2 代表回调一个函数
	local isfunc = false
	if type(observer) == 'function' then
		isfunc = true
	elseif func == nil then
		print("KVCCenter:addObserver", observer, "nil cbFunction!")
		return false
	end	
	keyObservers[ observer] = { key = key, isfunc = isfunc, cb = func}
	return true
end

-- 私有函数
-- 当观察的key 发生变化时 会调用本函数
-- @param t table 被观察者
-- @param key string｜number 被观察的key
-- @param newValue value 新的值
-- @param oldValue value 久的值
function KVCCenter:_valueChanged( t, key, newValue, oldValue)
	local observerData = self._observers[t]
	if observerData == nil then
		return false
	end
	local keyObservers = observerData[key]
	if keyObservers ~= nil then
		for observer, data in pairs(keyObservers) do
			if data.isfunc == true then
				observer( key, newValue, oldValue)
			else
				data.cb( observer, key, newValue, oldValue)
			end
			return true
		end
	end
	return false
end

-- kvc expand dependence string split
function KVCCenter.stringSplit( strValue, sep)
	if sep == nil or sep == "" then return nil end
    local fields = {}
    local pattern = string.format("([^%s]+)", sep)
    strValue:gsub(pattern, function (c) fields[#fields + 1] = c end)
    return fields
end
function KVCCenter.splitWithBracket(strValue)
    local t = {}
    for arg in string.gmatch(strValue, "%b[]") do
        table.insert(t, string.sub(arg,2,-2))
    end
    if #t == 0 then return strValue end
    return t
end

-- 展开所有的key
function KVCCenter:_expandKeys( keypath)
	local finalKeys =  {}
	local tempKeys = self.stringSplit( keypath, ".")
	for _, key in ipairs(tempKeys) do
		local sks = self.splitWithBracket( key)
		if sks == key then
			table.insert( finalKeys, {key=key, isArr=false})
		else
			local startssk = string.find( key,"%[")
			if startssk > 1 then
				local subkey = string.sub(key, 1, startssk - 1)
				table.insert( finalKeys, {key=subkey, isArr=false})
			end
			-- 包在 中括号中的必须是数组索引 number
			for _, subkey in ipairs(sks) do
				local idxKey = tonumber(subkey)
				if idxKey == nil then error("Bracket key must be number!") end
				table.insert( finalKeys, {key=idxKey, isArr=true})
			end
		end	
	end
	return finalKeys
end

-- 用点来代替
function KVCCenter:_getObserverKey( baseKey, nkey)
	local linkChar = "."
	if baseKey == "" then linkChar = "" end
	if nkey.isArr == true then
		return baseKey..linkChar..self._arrayFlag
	end
	return baseKey..linkChar..nkey.key
end

-- 设置目标的keypath 如果其中有数组形式则无法正常使用
-- @param target table 设置的目标
-- @param keypath string key路径
-- @param value value 设置的新值
-- @param bdeepc boolen 如果迭代过程中出现nil 是否创建table
function KVCCenter:setKeyPath( target, keypath, value, bdeepc, creator)
	if target == nil or keypath == nil or keypath == "" then return false end
	local creator = creator or self._defaultCreator
	local keys = self:_expandKeys( keypath)
	local subKeySize = #keys
	local finalKey = keys[subKeySize]
	if subKeySize == 1 then
		target[ finalKey] = value
	elseif subKeySize > 1 then
		local observerKey = ""
		local subValue = target
		for idx=1, subKeySize-1 do
			local tempKey = keys[idx]
			local tempSubValue = subValue[ tempKey.key]
			local tempObserverKey = self:_getObserverKey( observerKey, tempKey)
			-- 判断是否添加不存在的key
			if tempSubValue == nil and bdeepc ~= true then
				print("error: setKeyPath", keypath, tempKey)
				return false
			elseif	tempSubValue == nil then
				tempSubValue = creator( tempObserverKey, tempKey.key)
				rawset( subValue, tempKey.key, tempSubValue)
			end
			subValue = tempSubValue
			observerKey = tempObserverKey
		end
		local finalObserverKey = self:_getObserverKey( observerKey, finalKey)
		local oldValue = rawget( subValue, finalKey.key)
		rawset( subValue, finalKey.key, value)
		-- 分发最终value发生变化的节点key
		self:_valueChanged( target, finalObserverKey, value, oldValue)
		-- 再分发一次 被设置的key 的父节点value 发送变化 最后一个参数为其value发生变化的key
		self:_valueChanged( target, observerKey..".*", subValue, finalKey.key)
		return true
	end
	return false
end

-- 获取目标的key path
-- @param target table 读取目标
-- @param keypath key 路径
function KVCCenter:getKeyPath( target, keypath)
	if target == nil or keypath == nil or keypath == "" then return nil end
	local keys = self:_expandKeys( keypath)
	local subValue = target
	for idx, key in ipairs(keys) do
		subValue = subValue[key.key]
		if subValue == nil then return nil end
	end
	return subValue
end


--  默认初始化
KVCCenter:init()
return KVCCenter
