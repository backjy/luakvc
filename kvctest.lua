
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
-- 本例测试为 观察testArray 下面有任何key的value发生改变(不包括多路径key) 就会回调observerFunction
kvc:addObserver( testArray, '*',  observerFunction)
testArray[1] = {}

-- 数组下标测试 
-- 本测试为观察testArray 数组下标任何一个value 的test 键值发生改变
kvc:addObserver( testArray, '_.test',  observerFunction)
kvc:setKeyPath( testArray, "[1].test", "test array key")
kvc:setKeyPath( testArray, "[2].test", "test2", true)

-- 
-- 本测试为观察testArray 下的testkey 下的数组下的任何值发生改变时 通知观察者
kvc:addObserver( testArray, 'testkey._.*',  observerFunction)
kvc:setKeyPath( testArray, "testkey[1][1]", {"test2"}, true)
