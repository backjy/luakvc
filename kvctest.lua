
local kvc = require("kvc")

local observerObject = {}
observerObject.kvcObserver = function ( self, key, newValue, oldValue)
	print("observerObject.kvcObserver:", key, newValue, oldValue)
end

local observerFunction = function( key, newValue, oldValue)
	print("observerFunction:", key, newValue, oldValue)
end

local testArray = {}
-- 测试第一个类型都为数组的情况
kvc:addObserver( testArray, '*',  observerFunction)
testArray[1] = {}

-- 数组下标测试 
kvc:addObserver( testArray, '_.test',  observerFunction)
kvc:setKeyPath( testArray, "[1].test", "test array key")
kvc:setKeyPath( testArray, "[2].test", "test2", true)

-- 
kvc:addObserver( testArray, 'testkey._.*',  observerFunction)
kvc:setKeyPath( testArray, "testkey[1][1]", {"test2"}, true)
