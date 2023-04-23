--@includedir ./gui2
--@include ./class.lua
--@include ./stencil.lua

--[[
    TODO:
    have a more advanced changed system:
        if an element has changed in a minor way (changed something within the same bounds)
        make it only redraw the element itself and not the whole gui
    more elements
    mask stacking (perhabs? is expensive)
]]

local class, checktype = unpack(require("./class.lua"))
local stencil = require("./stencil.lua")

----------------------------------------

local cursor_poly_cache = {
    -- DRAGGING
    rect_45_o = {
        {x = -16, y = 0},
        {x = 0, y = -16},
        {x = 16, y = 0},
        {x = 0, y = 16}
    }, rect_45_i = {
        {x = -14, y = 0},
        {x = 0, y = -14},
        {x = 14, y = 0},
        {x = 0, y = 14}
    },
    
    rect_s_o = {
        {x = -8, y = -8},
        {x = 8, y = -8},
        {x = 8, y = 8},
        {x = -8, y = 8}
    }, rect_s_i = {
        {x = -6, y = -6},
        {x = 6, y = -6},
        {x = 6, y = 6},
        {x = -6, y = 6}
    },
    
    -- RESIZE
    arrow_l_o = {
        {x = -16, y = 0},
        {x = -8, y = -8},
        {x = -8, y = 8}
    }, arrow_l_i = {
        {x = -14, y = 0},
        {x = -9.5, y = -4.5},
        {x = -9.5, y = 4.5}
    },
    
    arrow_r_o = {
        {x = 16, y = 0},
        {x = 8, y = 8},
        {x = 8, y = -8}
    }, arrow_r_i = {
        {x = 14, y = 0},
        {x = 9.5, y = 4.5},
        {x = 9.5, y = -4.5}
    },
    
    arrow_u_o = {
        {x = 0, y = -16},
        {x = 8, y = -8},
        {x = -8, y = -8}
    }, arrow_u_i = {
        {x = 0, y = -14},
        {x = 4.5, y = -9.5},
        {x = -4.5, y = -9.5}
    },
    
    arrow_d_o = {
        {x = 0, y = 16},
        {x = -8, y = 8},
        {x = 8, y = 8}
    }, arrow_d_i = {
        {x = 0, y = 14},
        {x = -4.5, y = 9.5},
        {x = 4.5, y = 9.5}
    }
}

local cursor = { --[[32x32]]
    -- NORMAL
    [0] = function(mainColor, outlineColor)
        render.setColor(mainColor)
        render.drawRect(0, 0, 32, 32)
        render.setColor(outlineColor)
        render.drawSimpleText(0, 0, "0")
    end,
    
    -- CLICKABLE
    [1] = function(mainColor, outlineColor)
        render.setColor(mainColor)
        render.drawRect(0, 0, 32, 32)
        render.setColor(outlineColor)
        render.drawSimpleText(0, 0, "1")
    end,
    
    -- LOADING
    [2] = function(mainColor, outlineColor)
        render.setColor(mainColor)
        render.drawRect(0, 0, 32, 32)
        render.setColor(outlineColor)
        render.drawSimpleText(0, 0, "2")
    end,
    
    -- DRAGGING
    [3] = function(mainColor, outlineColor)
        render.setColor(outlineColor)
        render.drawPoly(cursor_poly_cache.rect_45_o)
        
        render.setColor(mainColor)
        render.drawPoly(cursor_poly_cache.rect_45_i)
        
        render.setColor(outlineColor)
        render.drawPoly(cursor_poly_cache.rect_s_o)
        
        render.setColor(mainColor)
        render.drawPoly(cursor_poly_cache.rect_s_i)
    end,
    
    -- RESIZE
    [4] = function(mainColor, outlineColor)
        render.setColor(outlineColor)
        render.drawRect(-8, -2, 16, 4)
        render.drawRect(-2, -8, 4, 16)
        render.drawPoly(cursor_poly_cache.arrow_l_o)
        render.drawPoly(cursor_poly_cache.arrow_r_o)
        render.drawPoly(cursor_poly_cache.arrow_u_o)
        render.drawPoly(cursor_poly_cache.arrow_d_o)
        
        render.setColor(mainColor)
        render.drawRect(-9.5, -1, 19, 2)
        render.drawRect(-1, -9.5, 2, 19)
        render.drawPoly(cursor_poly_cache.arrow_l_i)
        render.drawPoly(cursor_poly_cache.arrow_r_i)
        render.drawPoly(cursor_poly_cache.arrow_u_i)
        render.drawPoly(cursor_poly_cache.arrow_d_i)
    end,
    
    -- RESIZEX
    [5] = function(mainColor, outlineColor)
        render.setColor(outlineColor)
        render.drawRect(-8, -2, 16, 4)
        render.drawPoly(cursor_poly_cache.arrow_l_o)
        render.drawPoly(cursor_poly_cache.arrow_r_o)
        
        render.setColor(mainColor)
        render.drawRect(-9.5, -1, 19, 2)
        render.drawPoly(cursor_poly_cache.arrow_l_i)
        render.drawPoly(cursor_poly_cache.arrow_r_i)
    end,
    
    -- RESIZEY
    [6] = function(mainColor, outlineColor)
        render.setColor(outlineColor)
        render.drawRect(-2, -8, 4, 16)
        render.drawPoly(cursor_poly_cache.arrow_u_o)
        render.drawPoly(cursor_poly_cache.arrow_d_o)
        
        render.setColor(mainColor)
        render.drawRect(-1, -9.5, 2, 19)
        render.drawPoly(cursor_poly_cache.arrow_u_i)
        render.drawPoly(cursor_poly_cache.arrow_d_i)
    end,
    
    -- WRITEABLE
    [7] = function(mainColor, outlineColor)
        render.setColor(mainColor)
        render.drawRect(0, 0, 32, 32)
        render.setColor(outlineColor)
        render.drawSimpleText(0, 0, "7")
    end
}

local themes = {
    light = {
        primaryColor        = Color(180, 180, 180),
        primaryColorLight   = Color(200, 200, 200),
        primaryColorDark   = Color(160, 160, 160),
        primaryTextColor    = Color(15, 15, 15),
        
        secondaryColor      = Color(50, 80, 150),
        secondaryColorLight = Color(80, 100, 180),
        secondaryColorDark  = Color(20, 60, 110),
        secondaryTextColor  = Color(90, 90, 90),
        
        font = render.createFont("Trebuchet", 18, 350, true),
        
        cornerStyle           = 1,
        cornerSize            = 5,
        animationSpeed        = 8,
        
        cursorMainColor       = Color(220, 220, 220),
        cursorOutlineColor    = Color(30, 30, 30),
        cursorSize            = 12,
        cursorRender          = cursor,
        
        overrides = {}
    },
    
    dark = {
        primaryColor        = Color(40, 40, 40),
        primaryColorLight   = Color(50, 50, 50),
        primaryColorDark    = Color(30, 30, 30),
        primaryTextColor    = Color(255, 255, 255),
        
        secondaryColor      = Color(50, 80, 150),
        secondaryColorLight = Color(80, 100, 180),
        secondaryColorDark  = Color(20, 60, 110),
        secondaryTextColor  = Color(160, 160, 160),
        
        font = render.createFont("Trebuchet", 18, 350, true),
        
        cornerStyle           = 1,
        cornerSize            = 5,
        animationSpeed        = 8,
        
        cursorMainColor       = Color(30, 30, 30),
        cursorOutlineColor    = Color(220, 220, 220),
        cursorSize            = 12,
        cursorRender          = cursor,
        
        overrides = {}
    }
}

----------------------------------------

local guis = {}
local clearcolor = Color(0, 0, 0, 0)

hook.add("inputPressed", "lib.gui", function(key)
    for gui, _ in pairs(guis) do
        if not gui._force_manual_input and gui._focus_object then
            for k, _ in pairs(gui._buttons.left) do
                if key == k then
                    gui:simulateLeftPress()
                end
            end
            
            for k, _ in pairs(gui._buttons.right) do
                if key == k then
                    gui:simulateRightPress()
                end
            end
        end
    end
end)

hook.add("inputReleased", "lib.gui", function(key)
    for gui, _ in pairs(guis) do
        if not gui._force_manual_input then
            for k, _ in pairs(gui._buttons.left) do
                if key == k then
                    gui:simulateLeftRelease()
                end
            end
            
            for k, _ in pairs(gui._buttons.right) do
                if key == k then
                    gui:simulateRightRelease()
                end
            end
        end
    end
end)

----------------------------------------

-- local render_count = 0
-- for k, v in pairs(_G.render) do
--     if type(v) == "function" then
--         local o = v
--         _G.render[k] = function(...)
--             render_count = render_count + 1
            
--             return o(...)
--         end
--     end
-- end

----------------------------------------

local GUI
GUI = class {
    type = "gui",
    
    constructor = function(self, w, h)
        self._id = math.random()
        self._w = w or 512
        self._h = h or (w or 512)
        self.theme = "dark"
        self._rtid = "lib.gui:" .. self._id
        
        render.createRenderTarget(self._rtid)
        
        guis[self] = self
    end,
    
    ----------------------------------------
    
    data = {
        _id = 0,
        _buttons = {left = {[107] = true, [15] = true}, right = {[108] = true}},
        _doubleclick_time = 0.25,
        _theme = false,
        _w = 0,
        _h = 0,
        _objects = {},
        _object_refs = {},
        _render_order = {},
        _remove_queue = {},
        _parent_queue = {},
        _focus_object = nil,
        _last_click = 0,
        _clicking_objects = {left = {}, right = {}},
        _cursor_mode = 0,
        _rtid = "",
        _redraw = {},
        _redraw_order = {},
        _redraw_all = true,
        _allow_draw = false,
        _force_manual_input = false,
        
        _cells = {},
        _cell_size = 64,
        
        _max_fps = 60,
        _last_update = 0,
        _deltatime = 0,
        
        ------------------------------
        
        _changed = function(self, obj, simple --[[gone for now, might add back later, probably not]])
            --self._redraw_all = true
            
            if self._redraw_all then return end
            
            if not self._redraw[obj] then
                self._redraw[obj] = true
                table.insert(self._redraw_order, obj)
            end
        end,
        
        ------------------------------
        
        destroy = function(self)
            render.destroyRenderTarget(self._rtid)
            
            guis[self] = nil
        end,
        
        create = function(self, name, parent)
            local element = GUI.elements[name]
            
            if not element then
                error(tostring(name) .. " is not a valid element", 2)
            end
            
            --
            
            local object = {
                parent = parent,
                children = {},
                order = {},
                bounding = {x = 0, y = 0, x2 = 0, y2 = 0},
                global_pos = Vector(),
                cursor = {x = 0, y = 0}
            }
            
            local obj = element.class()
            obj._gui = self
            obj._theme = self.theme
            
            -- Overrides
            
            local overrides = self._theme.overrides[name]
            if overrides then
                for k, v in pairs(overrides) do
                    rawset(obj, k, v)
                end
            end
            
            --
            
            object.object = obj
            
            self._object_refs[obj] = object
            
            if parent then
                self._object_refs[parent].children[obj] = object
                table.insert(self._object_refs[parent].order, 1, obj)
            else
                self._objects[obj] = object
                table.insert(self._render_order, 1, obj)
            end
            
            --
            
            local function callConstructor(ele, obj)
                if ele.inherit then
                    callConstructor(ele.inherit, obj)
                end
                
                ele.constructor(obj)
            end
            callConstructor(element, obj)
            
            return obj
        end,
        
        render = function(self, x, y, w, h)
            if self._allow_draw then
                local deltatime = self._deltatime
                local sx, sy = 1024 / self._w, 1024 / self._h
                local s = Vector(sx, sy)
                
                local m = Matrix()
                m:setScale(s)
                render.pushMatrix(m, true)
                render.selectRenderTarget(self._rtid)
                
                local function drawobject(object, x1o, y1o, x2o, y2o)
                    local obj = object.object
                    -- if not obj._enabled or not obj._visible then return end
                    
                    local pos = object.global_pos
                    local m = Matrix()
                    m:setTranslation(pos)
                    render.pushMatrix(m)
                    
                    local crm = obj._customRenderMask
                    if crm then
                        stencil.pushMask(function()
                            -- render_count = 0
                            crm(obj, obj._w, obj._h)
                            -- print(render_count)
                        end, obj._invert_render_mask)
                    end
                    
                    local b = object.bounding
                    render.enableScissorRect(math.max(x1o or 0, (b.x + pos.x)) * sx, math.max(y1o or 0, (b.y + pos.y)) * sy, math.min(x2o or self._w, (b.x2 + pos.x)) * sx, math.min(y2o or self._h, (b.y2 + pos.y)) * sy)
                    -- render_count = 0
                    obj:_draw(deltatime)
                    -- print(render_count)
                    render.disableScissorRect()
                    -- print("----")
                    if crm then
                        stencil.popMask()
                    end
                    
                    render.popMatrix()
                end
                
                if self._redraw_all then
                    -- render_count = 0
                    local function draw(object)
                        local obj = object.object
                        if not obj._enabled or not obj._visible then return end
                        
                        drawobject(object)
                        
                        for i = #object.order, 1, -1 do
                            draw(object.children[object.order[i]])
                        end
                    end
                    
                    render.clear(clearcolor)
                    for i = #self._render_order, 1, -1 do
                        draw(self._objects[self._render_order[i]])
                    end
                    
                    self._redraw = {}
                    self._redraw_order = {}
                    self._redraw_all = false
                    -- print(render_count)
                elseif table.count(self._redraw) > 0 then
                    local x, y, x2, y2
                    local function draw(objs)
                        table.sort(objs, function(a, b) return a.order > b.order end)
                        
                        for _, obj in pairs(objs) do
                            if obj.obj._visible and obj.obj._enabled then
                                drawobject(self._object_refs[obj.obj], x, y, x2, y2)
                                
                                draw(obj.children)
                            end
                        end
                    end
                    
                    local ignore = {}
                    local function doignore(object)
                        for child, child_object in pairs(object.children) do
                            ignore[child] = true
                            
                            doignore(child_object)
                        end
                    end
                    
                    for _, obj in pairs(self._redraw_order) do
                        doignore(self._object_refs[obj])
                    end
                    
                    for _, obj in pairs(self._redraw_order) do
                        if not ignore[obj] then
                            local object = self._object_refs[obj]
                            local cs = self._cell_size
                            
                            -- Clear old space
                            local p = object.global_pos_last
                            local b = object.bounding_last
                            render.enableScissorRect((b.x + p.x) * sx, (b.y + p.y) * sy, (b.x2 + p.x) * sx, (b.y2 + p.y) * sy)
                            render.clear(clearcolor)
                            render.disableScissorRect()
                            
                            -- Redraw elements where we cleared
                            -- x, y, x2, y2 = math.floor((b.x + p.x) / cs) * cs, math.floor((b.y + p.y) / cs) * cs, math.ceil((b.x2 + p.x) / cs) * cs, math.ceil((b.y2 + p.y) / cs) * cs
                            
                            local pl = object.global_pos
                            local bl = object.bounding
                            local gx = math.floor(math.min(bl.x + pl.x, b.x + p.x) / cs)
                            local gy = math.floor(math.min(bl.y + pl.y, b.y + p.y) / cs)
                            local gx2 = math.ceil(math.max(bl.x2 + pl.x, b.x2 + p.x) / cs)
                            local gy2 = math.ceil(math.max(bl.y2 + pl.y, b.y2 + p.y) / cs)
                            x, y, x2, y2 = gx * cs, gy * cs, gx2 * cs, gy2 * cs
                            
                            local gx2 = math.floor(math.max(bl.x2 + pl.x, b.x2 + p.x) / cs)
                            local gy2 = math.floor(math.max(bl.y2 + pl.y, b.y2 + p.y) / cs)
                            local todo, done = {}, {}
                            for x = gx, gx2 do
                                for y = gy, gy2 do
                                    if self._cells[x] and self._cells[x][y] then -- Idk why needed but w/e, happy it finally works
                                        for _, o in pairs(self._cells[x][y]) do
                                            if not done[o] then
                                                table.insert(todo, o)
                                                done[o] = o
                                            end
                                        end
                                    end
                                end
                            end
                            -- for _, cell in pairs(obj._cells) do
                            --     for _, o in pairs(self._cells[cell.x][cell.y]) do
                            --         if not done[o] then
                            --             table.insert(todo, o)
                            --             done[o] = o
                            --         end
                            --     end
                            -- end
                            
                            -- Sort in parent hierarchy
                            local objs, refs = {}, {}
                            while #todo > 0 do
                                local o = todo[1]
                                local p = o.parent
                                
                                if p then
                                    if refs[p] then
                                        table.insert(refs[p].children, {
                                            obj = o,
                                            order = table.keyFromValue(self._object_refs[p].order, o),
                                            children = {}
                                        })
                                        refs[o] = refs[p].children[#refs[p].children]
                                    end
                                else
                                    table.insert(objs, {
                                        obj = o,
                                        order = table.keyFromValue(self._render_order, o),
                                        children = {}
                                    })
                                    refs[o] = objs[#objs]
                                end
                                
                                table.remove(todo, 1)
                            end
                            
                            draw(objs)
                        end
                    end
                    
                    self._redraw = {}
                    self._redraw_order = {}
                end
                -- elseif table.count(self._redraw) > 0 then
                --     -- Disabled for now cuz fuck that shit
                --     -- First add all children of elements that are being redrawn
                --     local done = {}
                --     local redraw = {}
                --     local function add(objs)
                --         for _, obj in pairs(objs) do
                --             if not done[obj] or self._redraw[obj] then
                --                 done[obj] = true
                                
                --                 local object = self._object_refs[obj]
                --                 table.insert(redraw, object)
                --                 add(object.order)
                --             end
                --         end
                --     end
                    
                --     add(self._redraw_order)
                    
                --     -- Draw
                --     for _, object in pairs(redraw) do
                --         drawobject(object)
                --     end
                    
                --     self._redraw = {}
                --     self._redraw_order = {}
                -- end
                
                render.selectRenderTarget()
                render.popMatrix()
            end
            
            render.setRenderTargetTexture(self._rtid)
            render.setRGBA(255, 255, 255, 255)
            render.drawTexturedRect(x or 0, y or 0, w or self._w, h or self._h)
            
            -- Post Draw
            local dt = timer.frametime()
            local function postdraw(objects)
                for obj, object in pairs(objects) do
                    if obj._enabled and obj._visible then
                        obj:_postdraw(deltatime, dt)
                        
                        postdraw(object.children)
                    end
                end
            end
            postdraw(self._objects)
        end,
        
        renderHUD = function(self)
            local deltatime = self._deltatime
            local w, h = render.getResolution()
            local sx, sy = w / self._w, h / self._h
            local s = Vector(sx, sy)
            
            local function draw(object, masks)
                local obj = object.object
                if not obj._enabled or not obj._visible then return end
                
                local m = Matrix()
                m:setTranslation(obj._pos)
                render.pushMatrix(m)
                
                local crm = obj._customRenderMask
                if crm then
                    stencil.pushMask(function()
                        crm(obj, obj._w, obj._h)
                    end, obj._invert_render_mask)
                end
                
                local b = object.global_bounding
                render.enableScissorRect(b.x * sx, b.y * sy, b.x2 * sx, b.y2 * sy)
                obj:_draw(deltatime)
                render.disableScissorRect()
                
                if crm then
                    stencil.popMask()
                end
                
                for i = #object.order, 1, -1 do
                    draw(object.children[object.order[i]], masks)
                end
                
                render.popMatrix()
            end
            
            local m = Matrix()
            m:setScale(s)
            render.pushMatrix(m, true)
            for i = #self._render_order, 1, -1 do
                draw(self._objects[self._render_order[i]], {})
            end
            render.popMatrix()
        end,
        
        renderDirect = function(self)
            local sx, sy = 1024 / self._w, 1024 / self._h
            
            local function draw(object)
                local obj = object.object
                if not obj._enabled or not obj._visible then return end
                
                local m = Matrix()
                m:setTranslation(obj._pos)
                render.pushMatrix(m)
                
                obj:_draw()
                for i = #object.order, 1, -1 do
                    draw(object.children[object.order[i]])
                end
                
                render.popMatrix()
            end
            
            for i = #self._render_order, 1, -1 do
                draw(self._objects[self._render_order[i]])
            end
        end,
        
        renderDebug = function(self, simple)
            -- Bounding boxes & masks
            render.setRGBA(255, 0, 255, 50)
            render.setMaterial()
            
            local function draw(objects)
                for obj, object in pairs(objects) do
                    if obj._enabled and obj._visible then
                        local ox, oy = object.global_pos.x, object.global_pos.y
                        local b = object.bounding
                        local x, y, x2, y2 = b.x + ox, b.y + oy, b.x2 + ox, b.y2 + oy
                        
                        render.drawLine(x, y, x2, y)
                        render.drawLine(x, y, x, y2)
                        render.drawLine(x, y2, x2, y2)
                        render.drawLine(x2, y, x2, y2)
                        render.drawLine(x, y, x2, y2)
                        
                        local crm = obj._customRenderMask
                        if crm then
                            local p = object.global_pos
                            local m = Matrix()
                            m:setTranslation(Vector(p.x, p.y))
                            render.pushMatrix(m)
                            crm(obj, obj._w, obj._h)
                            render.popMatrix()
                        end
                        
                        draw(object.children)
                    end
                end
            end
            
            draw(self._objects)
            
            if not simple then
                -- Cells
                local cs = self._cell_size
                for x, column in pairs(self._cells) do
                    for y, cell in pairs(column) do
                        local c = (x + y) % 2 == 1 and 200 or 150
                        render.setRGBA(c, c, c, 50)
                        render.drawRect(x * cs, y * cs, cs, cs)
                        
                        render.setRGBA(255, 0, 255, 150)
                        render.drawSimpleText(x * cs + cs / 2, y * cs + cs / 2, tostring(#cell), 1, 1)
                    end
                end
                
                -- Cells focus
                if self._focus_object then
                    for _, cell in pairs(self._focus_object.object._cells) do
                        render.setRGBA(255, 0, 0, 50)
                        render.drawRect(cell.x * cs, cell.y * cs, cs, cs)
                    end
                end
            end
        end,
        
        --[[renderMasks = function(self)
            render.setRGBA(255, 0, 255, 50)
            render.setMaterial()
            
            for obj, object in pairs(self._object_refs) do
                if obj._enabled and obj._visible then
                    local crm = obj._customRenderMask
                    if crm then
                        local p = object.global_pos
                        local m = Matrix()
                        m:setTranslation(Vector(p.x, p.y))
                        render.pushMatrix(m)
                        crm(obj, obj._w, obj._h)
                        render.popMatrix()
                    end
                end
            end
        end,]]
        
        renderCursor = function(self, s)
            local cx, cy = self:getCursorPos()
            
            if cx then
                local theme = self._theme
                local w, h = render.getResolution()
                local sx, sy = w / self._w, h / self._h
                
                local m = Matrix()
                m:setTranslation(Vector(cx * sx, cy * sy))
                m:setScale(Vector(sx, sy) * self._theme.cursorSize / 32 * (s or 1))
                render.pushMatrix(m)
                render.setMaterial()
                theme.cursorRender[self._cursor_mode](theme.cursorMainColor, theme.cursorOutlineColor)
                render.popMatrix()
            end
        end,
        
        think = function(self, cx, cy, w, h)
            local t = timer.curtime()
            
            if self._last_update > t - 1 / self._max_fps then return end
            local deltatime = t - self._last_update
            self._last_update = t
            self._deltatime = deltatime
            self._allow_draw = true
            
            -- Remove objects
            if table.count(self._remove_queue) > 0 then
                for obj, _ in pairs(self._remove_queue) do
                    if self._objects[obj] then
                        for i, o in pairs(self._render_order) do
                            if o == obj then
                                table.remove(self._render_order, i)
                            end
                        end
                        
                        self._objects[obj] = nil
                    else
                        local parent = self._object_refs[self._object_refs[obj].parent]
                        
                        if parent then
                            for i, o in pairs(parent.order) do
                                if o == obj then
                                    table.remove(parent.order, i)
                                end
                            end
                            
                            parent.children[obj] = nil
                        end
                    end
                    
                    self._object_refs[obj] = nil
                end
                
                self._remove_queue = {}
                self._redraw_all = true
            end
            
            -- Think
            if not cx then
                local _, x, y = xpcall(render.cursorPos, input.getCursorPos)
                cx, cy = x, y
            end
            
            if cx then
                if not w then
                    w, h = render.getResolution()
                end
                
                cx, cy = self._w / w * cx, self._h / h * cy
            end
            
            self._cursorx = cx
            self._cursory = cy
            
            local function think(objects)
                for obj, object in pairs(objects) do
                    if obj._enabled and obj._visible then
                        local gp = object.global_pos
                        local lcx, lcy = cx and (cx - gp.x) or nil, cy and (cy - gp.y) or nil
                        
                        object.cursor = {x = lcx, y = lcy}
                        
                        obj:_think(deltatime, lcx, lcy)
                        
                        think(object.children)
                    end
                end
            end
            think(self._objects)
            
            
            local function postthink(objects)
                for obj, object in pairs(objects) do
                    obj:_postthink()
                    
                    postthink(object.children)
                end
            end
            postthink(self._objects)
            
            -- Mouse stuff
            local last = self._focus_object
            self._focus_object = nil
            
            if cx then
                local function dobj(object)
                    local obj = object.object
                    
                    local b = object.bounding
                    local c = object.cursor
                    
                    if c.x and c.x > b.x and c.y > b.y and c.x < b.x2 and c.y < b.y2 then
                        local cim = obj._customInputMask
                        if cim and not cim(obj, c.x, c.y) then return end
                        
                        local hover = not obj._translucent and object or nil
                        
                        for i, child in pairs(object.order) do
                            local h = dobj(object.children[child])
                            if h then
                                hover = h
                                
                                break
                            end
                        end
                        
                        return hover
                    end
                end
                
                for i, obj in pairs(self._render_order) do
                    local hover = dobj(self._objects[obj])
                    if hover then
                        self._focus_object = hover
                        
                        hover.object:_hover(deltatime)
                        
                        break
                    end
                end
            end
            
            if self._focus_object ~= last then
                if last then
                    last.object:_hoverEnd()
                end
                
                if self._focus_object then
                    self._focus_object.object:_hoverStart()
                end
            end
        end,
        
        forceRedraw = function(self)
            self._redraw_all = true
        end,
        
        ------------------------------
        
        getCursorPos = function(self, obj)
            if obj then
                local p = self._object_refs[obj].cursor
                
                return p.x, p.y
            else
                return self._cursorx, self._cursory
            end
        end,
        
        focus = function(self, obj)
            local object = self._object_refs[obj]
            local parent = self._object_refs[obj.parent]
            
            if parent then
                for i, o in pairs(parent.order) do
                    if o == obj then
                        table.remove(parent.order, i)
                    end
                end
                
                table.insert(parent.order, 1, obj)
            else
                for i, o in pairs(self._render_order) do
                    if o == obj then
                        table.remove(self._render_order, i)
                    end
                end
                
                table.insert(self._render_order, 1, obj)
            end
        end,
        
        simulateLeftPress = function(self)
            if not self._focus_object then return false end
            
            self._focus_object.object:_press()
            
            if timer.curtime() - self._last_click < self._doubleclick_time then
                self._focus_object.object:_pressDouble()
            end
            
            self._last_click = timer.curtime()
            
            table.insert(self._clicking_objects.left, self._focus_object)
            
            return true
        end,
        
        simulateRightPress = function(self)
            if not self._focus_object then return false end
            
            self._focus_object.object:_pressRight()
            
            table.insert(self._clicking_objects.right, self._focus_object)
            
            return true
        end,
        
        simulateLeftRelease = function(self)
            for _, obj in pairs(self._clicking_objects.left) do
                obj.object:_release()
            end
            
            self._clicking_objects.left = {}
            
            return true
        end,
        
        simulateRightRelease = function(self)
            for _, obj in pairs(self._clicking_objects.right) do
                obj.object:_releaseRight()
            end
            
            self._clicking_objects.right = {}
            
            return true
        end,
        
        ------------------------------
        
        setTheme = function(self, theme)
            self.theme = theme
        end,
        
        setButtonsLeft = function(self, ...)
            self._buttons.left = {}
            for _, key in pairs({...}) do
                self._buttons.left[key] = true
            end
        end,
        
        setButtonsRight = function(self, ...)
            self._buttons.right = {}
            for _, key in pairs({...}) do
                self._buttons.right[key] = true
            end
        end,
        
        getButtonsLeft = function(self)
            return self.buttonsLeft
        end,
        
        getButtonsRight = function(self)
            return self.buttonsRight
        end,
        
        setDoubleclickTime = function(self, value)
            self._doubleclick_time = value
        end,
        
        getDoubleclickTime = function(self)
            return self._doubleclick_time
        end,
        
        setFpsLimit = function(self, value)
            self._max_fps = value
        end,
        
        getFpsLimit = function(self)
            return self._max_fps
        end,
        
        setForceManualInput = function(self, state)
            self._force_manual_input = state
        end,
        
        getForceManualInput = function(self)
            return self._force_manual_input
        end
    },
    
    ----------------------------------------
    
    properties = {
        theme = {
            set = function(self, theme)
                local t = type(theme)
                
                if t == "table" then
                    for k, v in pairs(theme) do
                        self._theme[k] = v
                    end
                elseif t == "string" then
                    if not GUI.themes[theme] then
                        error(theme .. " is not a valid theme", 2)
                    end
                    
                    self._theme = table.copy(GUI.themes[theme])
                end
                
                self._redraw_all = true
                
                local function dobj(objects)
                    for obj, data in pairs(objects) do
                        obj._theme = self._theme
                        dobj(data.children)
                    end
                end
                dobj(self._objects)
            end,
            
            get = function(self)
                return self._theme
            end
        },
        
        buttonsLeft = {
            set = function(self, key)
                self:setButtonsLeft(key)
            end,
            
            get = function(self)
                local buttons = {}
                for key, _ in pairs(self._buttons.left) do
                    table.insert(buttons, key)
                end
                
                return buttons
            end
        },
        
        buttonsRight = {
            set = function(self, key)
                self:setButtonsRight(key)
            end,
            
            get = function(self)
                local buttons = {}
                for key, _ in pairs(self._buttons.right) do
                    table.insert(buttons, key)
                end
                
                return buttons
            end
        },
        
        doubleclickTime = {
            set = function(self, value)
                self._doubleclick_time = value
            end,
            
            get = function(self)
                return self.self._doubleclick_time
            end
        },
        
        fpsLimit = {
            set = function(self, value)
                self._max_fps = value
            end,
            
            get = function(self)
                return self._max_fps
            end
        },
        
        forceManualInput = {
            set = function(self, state)
                self._force_manual_input = state
            end,
            
            get = function(self)
                return self._force_manual_input
            end
        }
    },
    
    ----------------------------------------
    
    static_data = {
        themes = themes,
        
        elements = {},
        
        ------------------------------
        
        CURSORMODE = {
            NORMAL = 0,
            CLICKABLE = 1,
            LOADING = 2,
            DRAGGING = 3,
            RESIZE = 4,
            RESIZEX = 5,
            RESIZEY = 6,
            WRITEABLE = 7
        },
        
        DOCK = {
            NODOCK = 0,
            FILL = 1,
            LEFT = 2,
            RIGHT = 3,
            TOP = 4,
            BOTTOM = 5
        },
        
        ------------------------------
        -- Simple functions
        lerpColor = function(clr1, clr2, progress)
            return clr1 * (1 - progress) + clr2 * progress
        end,
        
        utf8sub = function(str, s, e)
            -- Doesnt support -1 as index
            if #str == 0 then return "" end
            
            local len = string.utf8len(str)
            local e = e or len
            if e < 0 then
                e = len - e + 1
            end
            
            if s > e then return "" end
            
            return string.sub(str, string.utf8offset(str, (s or 1) - 1), (string.utf8offset(str, e) or #str + 1) - 1)
        end,
        
        ------------------------------
        
        registerElement = function(name, data)
            if GUI.elements[name] then
                error(name .. " is already a registered element", 2)
            end
            
            local inherit = data.inherit
            local constructor = data.constructor
            
            -- General class related stuff
            data.type = "gui." .. name
            data.inherit = nil
            data.constructor = function() end
            
            -- Apply inherit
            if inherit then
                local i = GUI.elements[inherit].raw
                
                -- Main inherit stuff
                for k, v in pairs(i.data) do
                    if data.data[k] == nil then
                        data.data[k] = type(v) == "table" and table.copy(v) or v
                    end
                end
                
                for k, v in pairs(i.properties) do
                    if data.properties[k] == nil then
                        data.properties[k] = type(v) == "table" and table.copy(v) or v
                    end
                    
                    -- if t and v.set then
                    --     base["set" .. string.upper(k[1]) .. string.sub(k, 2)] = v.set
                    -- end
                    
                    -- if t and v.get then
                    --     base["get" .. string.upper(k[1]) .. string.sub(k, 2)] = v.get
                    -- end
                end
                
                -- Add base to data functions
                for k, v in pairs(data.data) do
                    if i.data[k] and type(v) == "function" then
                        local func = v
                        local func_i = i.data[k]
                        
                        data.data[k] = function(self, ...)
                            local vals = {...}
                            
                            local old_base = _G.base
                            _G.base = function()
                                return func_i(self, unpack(vals))
                            end
                            
                            local a = {func(self, ...)}
                            
                            _G.base = old_base
                            
                            return unpack(a)
                        end
                    end
                end
            end
            
            -- Generate methods
            for k, v in pairs(data.properties) do
                if type(v) == "table" and v.set then
                    data.data["set" .. string.upper(k[1]) .. string.sub(k, 2)] = v.set
                end
                
                if type(v) == "table" and v.get then
                    data.data["get" .. string.upper(k[1]) .. string.sub(k, 2)] = v.get
                end
            end
            
            -- Store element
            GUI.elements[name] = {
                raw = data,
                class = class(data),
                constructor = constructor,
                inherit = GUI.elements[inherit],
                inherit_name = inherit
            }
        end
    },
    
    ----------------------------------------
    
    static_properties = {
        
    }
    
}

----------------------------------------

-- Register all default elements
local old_GUI = _G.GUI
_G.GUI = GUI

local elements_raw = {}
for path, data in pairs(requiredir("./gui2")) do
    elements_raw[string.match(path, "/(%w+).lua$")] = data
end

local function doElement(name)
    local data = elements_raw[name]
    
    if not data.inherit or not elements_raw[data.inherit] then
        GUI.registerElement(name, data)
        
        elements_raw[name] = nil
    else
        doElement(data.inherit)
    end
end

while table.count(elements_raw) > 0 do
    for name, _ in pairs(elements_raw) do
        doElement(name)
        
        break
    end
end
_G.GUI = old_GUI

----------------------------------------

return GUI
