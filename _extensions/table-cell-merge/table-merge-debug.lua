-- table-merge-debug.lua
-- Dump Caption to a file for debugging

function Table(tbl)
  local home = os.getenv("USERPROFILE") or os.getenv("HOME") or "."
  local f = io.open(home .. "/tbl-merge-debug.txt", "a")
  f:write("=== Table called ===\n")

  local long = tbl.caption and tbl.caption.long
  if not long or #long == 0 then
    f:write("  caption: empty\n")
    f:close()
    return nil
  end

  local block = long[1]
  if not block or not block.content then
    f:write("  caption block: no content\n")
    f:close()
    return nil
  end

  for i, il in ipairs(block.content) do
    local txt = il.text or ""
    if il.t == "Quoted" then
      local v = ""
      for _, c in ipairs(il.content) do
        if c.text then v = v .. c.text end
      end
      txt = '"' .. v .. '"'
    end
    f:write(string.format("  [%d] t=%-8s text=%s\n", i, il.t, txt))
  end

  f:close()
  return nil
end
