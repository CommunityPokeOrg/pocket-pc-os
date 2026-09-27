-- PocketOS app registry. Apps register a descriptor; the shell uses it for
-- desktop icons and the Start menu. open(env) returns a window instance:
--   inst:draw(ctx)            ctx={x,y,w,h} content rect (absolute coords)
--   inst:touchDown(x,y,ctx)   coords are content-relative
--   inst:touchMove(x,y,ctx)
--   inst:touchUp(x,y,ctx)
--   inst:key(name,char,down)  keyboard events while focused
--   inst:onOpen(ctx) / inst:onClose()
local M = { list = {}, byId = {} }

function M.register(app)
  -- app = {id, title, glyph, w, h, open}
  M.list[#M.list + 1] = app
  M.byId[app.id] = app
end

function M.get(id)
  return M.byId[id]
end

return M
