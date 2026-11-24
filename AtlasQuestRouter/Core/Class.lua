--[[--------------------------------------------------------------------------
  Core/Class.lua
  Tiny class + interface system for Lua 5.1 (the Lua version WoW ships).

  Why it exists:
  * Lua has no "class" keyword. Every other file uses Class.define so the
    code reads like the class diagrams in docs/diagrams.
  * Class.interface + Class.implements give us explicit contracts, which is
    how the Dependency Inversion Principle (the "D" in SOLID) is made visible:
    high level modules depend on an *interface* (e.g. IGameApi, IScoreComponent),
    never on a concrete WoW global.
----------------------------------------------------------------------------]]
local _, ns = ...

local Class = {}

--- Define a new class, optionally inheriting from `parent`.
-- @param name   string  class name (used in error messages and tostring)
-- @param parent table?  parent class (single inheritance, Liskov-safe)
function Class.define(name, parent)
    local cls = {}
    cls.__index = cls
    cls.__name = name
    cls.super = parent
    cls.__interfaces = {}
    if parent then
        setmetatable(cls, { __index = parent })
    end

    --- Constructor: Foo.new(...) calls Foo:init(...)
    function cls.new(...)
        local instance = setmetatable({}, cls)
        if instance.init then
            instance:init(...)
        end
        return instance
    end

    --- Runtime type check that walks the inheritance chain.
    function cls:isInstanceOf(other)
        local current = getmetatable(self)
        while current do
            if current == other then return true end
            current = current.super
        end
        return false
    end

    cls.__tostring = function(self) return name end
    return cls
end

--- Declare an interface: a named list of method names that implementers must provide.
function Class.interface(name, methods)
    return { __interfaceName = name, methods = methods }
end

--- Assert that `cls` (or an instance) provides every method of `iface`.
-- Called once at load time, so a missing method fails fast instead of at runtime.
function Class.implements(cls, iface)
    for _, method in ipairs(iface.methods) do
        if type(cls[method]) ~= "function" then
            error(("%s does not implement %s:%s()"):format(
                tostring(cls.__name or cls), iface.__interfaceName, method), 2)
        end
    end
    if rawget(cls, "__interfaces") then
        table.insert(cls.__interfaces, iface.__interfaceName)
    end
    return cls
end

--- Abstract method helper: put this in a base class to force overriding.
function Class.abstract(className, methodName)
    return function()
        error(("%s:%s() is abstract and must be overridden"):format(className, methodName), 2)
    end
end

ns.Class = Class
