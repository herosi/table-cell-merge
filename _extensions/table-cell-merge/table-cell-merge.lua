-- table-cell-merge.lua
-- Quarto / Pandoc Lua filter that adds colspan / rowspan to tables.
--
-- Usage:
--   | A | B | C | D |
--   |---|---|---|---|
--   | 1 | 2 | 3 | 4 |
--   | 5 | 6 | 7 | 8 |
--   : Caption {tbl-merge="[1:1:col:3, 2:2:row:2]"}
--
-- tbl-merge format:  [row:col:direction:span, ...]
--   row       : 1-based row index (header rows first, then body rows)
--   col       : 1-based col index
--   direction : col (colspan) | row (rowspan)
--   span      : number of cells to merge (>= 2)

-- ---------------------------------------------
-- caption util
-- ---------------------------------------------

local function caption_inlines(tbl)
  local long = tbl.caption and tbl.caption.long
  if not long or #long == 0 then return nil end
  local block = long[1]
  if (block.t == "Plain" or block.t == "Para") and block.content then
    return block.content
  end
  return nil
end

local function inline_to_str(il)
  if     il.t == "Str"    then return il.text
  elseif il.t == "Space"  then return " "
  elseif il.t == "Quoted" then
    local s = ""
    for _, c in ipairs(il.content) do s = s .. inline_to_str(c) end
    return s
  else return "" end
end

local function normalize_inlines(inlines)
  -- Split cases where `{` or `}` are attached to a token, such as `{foo=`.
  local result = pandoc.List()
  for _, il in ipairs(inlines) do
    if il.t == "Str" and il.text:match("^{.+") then
      result:insert(pandoc.Str("{"))
      result:insert(pandoc.Str(il.text:sub(2)))
    elseif il.t == "Str" and il.text:match(".+}$") and il.text ~= "}" then
      result:insert(pandoc.Str(il.text:sub(1, -2)))
      result:insert(pandoc.Str("}"))
    else
      result:insert(il)
    end
  end
  return result
end

local function extract_tbl_merge(inlines)
  -- At the post-quarto stage, `{tbl-merge='[...]'}` is treated as a single token
  for _, il in ipairs(inlines) do
    if il.t == "Str" then
      local val = il.text:match("tbl%-merge=['\"](%[.-%])['\"]")
      if val then return val end
    end
  end
  -- Normal stage: normalize and look for the pattern `tbl-merge=` + Quoted
  local normalized = normalize_inlines(inlines)
  for i, il in ipairs(normalized) do
    if il.t == "Str" and il.text == "tbl-merge=" then
      local nxt = normalized[i + 1]
      if nxt and nxt.t == "Quoted" then
        local val = ""
        for _, c in ipairs(nxt.content) do val = val .. inline_to_str(c) end
        return val
      end
    end
  end
  return nil
end

local function strip_tbl_merge(inlines)
  local result = pandoc.List()

  -- Post-quarto stage: `tbl-merge='[...]'` may be combined with other text
  -- Normal stage: `tbl-merge=` + Quoted (two-token form)
  -- To support both cases, first check whether it is the post-quarto form
  local has_single_token = false
  for _, il in ipairs(inlines) do
    if il.t == "Str" and il.text:match("tbl%-merge=['\"]%[.-%]['\"]") then
      has_single_token = true; break
    end
  end

  if has_single_token then
    -- Post-quarto form: pattern-match each token and remove the tbl-merge part
    -- Cases:
    --   "{tbl-merge='[...]'}"  → remove the entire token
    --   "{tbl-merge='[...]'"   → keep "{"
    --   "tbl-merge='[...]'}"   → keep "}"
    --   "tbl-merge='[...]'"    → remove the entire token (middle case)
    for _, il in ipairs(inlines) do
      if il.t == "Str" and il.text:match("tbl%-merge=['\"]%[.-%]['\"]") then
        local t = il.text
        local stripped
        if t:match("^{tbl%-merge=['\"]%[.-%]['\"]'?}$") then
          stripped = ""                            -- whole `{tbl-merge='[...]'}`
        elseif t:match("^{tbl%-merge=['\"]%[.-%]['\"]'?%s*$") or
               t:match("^{tbl%-merge=['\"]%[.-%]['\"]$") then
          stripped = "{"                           -- `{tbl-merge='[...]'`  -> `{`
        elseif t:match("^%s*tbl%-merge=['\"]%[.-%]['\"]'?}$") or
               t:match("tbl%-merge=['\"]%[.-%]['\"]'?}$") then
          stripped = "}"                           -- `tbl-merge='[...]'}`  -> `}`
        else
          stripped = ""                            -- Standalone token (`tbl-merge='[...]'`)
        end
        if stripped == "" then
          if #result > 0 and result[#result].t == "Space" then
            result:remove()
          end
        elseif stripped == "{" then
          result:insert(pandoc.Str(stripped))
          -- Flag to remove the following Space token later
        else
          -- If the token is "}", remove the preceding `Space` token
          if #result > 0 and result[#result].t == "Space" then
            result:remove()
          end
          result:insert(pandoc.Str(stripped))
        end
      else
        result:insert(il)
      end
    end
    -- Remove the `Space` token immediately after "{"
    for j, il in ipairs(result) do
      if il.t == "Str" and il.text == "{" then
        if result[j+1] and result[j+1].t == "Space" then
          result:remove(j+1)
        end
        break
      end
    end
    return result
  end

  -- Normal stage: normalize tokens and remove `tbl-merge=` followed by a `Quoted` token
  local normalized = normalize_inlines(inlines)
  local i = 1
  while i <= #normalized do
    local il = normalized[i]
    if il.t == "Str" and il.text == "tbl-merge=" then
      if #result > 0 and result[#result].t == "Space" then
        result:remove()
      end
      local skip = i + 1
      if normalized[skip] and normalized[skip].t == "Quoted" then skip = skip + 1 end
      i = skip
    else
      result:insert(il)
      i = i + 1
    end
  end

  -- Remove the `Space` token immediately after "{"
  local brace_start, brace_end = nil, nil
  for j, il in ipairs(result) do
    if il.t == "Str" and il.text == "{" then brace_start = j end
    if il.t == "Str" and il.text == "}" then brace_end   = j end
  end
  if brace_start and result[brace_start + 1] and result[brace_start + 1].t == "Space" then
    result:remove(brace_start + 1)
    if brace_end then brace_end = brace_end - 1 end
  end
  if brace_start and brace_end then
    local only_space = true
    for j = brace_start + 1, brace_end - 1 do
      if result[j].t ~= "Space" then only_space = false; break end
    end
    if only_space then
      local final = pandoc.List()
      local skip_start = brace_start
      if skip_start > 1 and result[skip_start - 1].t == "Space" then
        skip_start = skip_start - 1
      end
      for j, il in ipairs(result) do
        if j < skip_start or j > brace_end then final:insert(il) end
      end
      return final
    end
  end

  return result
end

-- ---------------------------------------------
-- Parse
-- ---------------------------------------------

local function parse_specs(str)
  local inner = str:match("^%s*%[(.-)%]%s*$") or str
  local specs = {}
  for token in inner:gmatch("[^,]+") do
    local r, c, d, s = token:match(
      "^%s*(%d+)%s*:%s*(%d+)%s*:%s*(%a+)%s*:%s*(%d+)%s*$")
    assert(r, "Invalid merge spec: '" .. token .. "'")
    specs[#specs + 1] = {
      row = tonumber(r), col = tonumber(c),
      dir = d,          span = tonumber(s),
    }
  end
  return specs
end

-- ---------------------------------------------
-- Flatten Table AST
-- ---------------------------------------------

local function flatten_rows(tbl)
  local rows = {}
  local function push(r) for _, row in ipairs(r) do rows[#rows+1] = row end end
  if tbl.head   then push(tbl.head.rows) end
  if tbl.bodies then
    for _, body in ipairs(tbl.bodies) do push(body.head); push(body.body) end
  end
  if tbl.foot   then push(tbl.foot.rows) end
  return rows
end

-- ---------------------------------------------
-- Apply Merge
-- ---------------------------------------------

local function apply_merges(tbl, specs)
  local rows = flatten_rows(tbl)
  -- cells to be removed
  local remove = {}
  for r = 1, #rows do remove[r] = {} end

  for _, spec in ipairs(specs) do
    local r, c = spec.row, spec.col
    if r > #rows or c > #rows[r].cells then
      io.stderr:write(string.format(
        "[table-merge] WARNING: (%d,%d) is out of range – skipped\n", r, c))
    else
      local cell = rows[r].cells[c]
      if spec.dir == "col" then
        cell.col_span = spec.span
        for i = c + 1, c + spec.span - 1 do
          if rows[r].cells[i] then remove[r][i] = true end
        end
      else  -- row
        cell.row_span = spec.span
        for i = r + 1, r + spec.span - 1 do
          if rows[i] and rows[i].cells[c] then remove[i][c] = true end
        end
      end
    end
  end

  -- remove cells along with marks
  for r, row in ipairs(rows) do
    local new_cells = {}
    for c, cell in ipairs(row.cells) do
      if not remove[r][c] then new_cells[#new_cells+1] = cell end
    end
    row.cells = pandoc.List(new_cells)
  end

  return tbl
end

-- ---------------------------------------------
-- Entrypoint of Pandoc Filter
-- ---------------------------------------------

function Table(tbl)
  local inlines = caption_inlines(tbl)
  if not inlines then return nil end

  local merge_str = extract_tbl_merge(inlines)
  if not merge_str then return nil end

  -- Remove { ... } from caption
  local clean = strip_tbl_merge(inlines)
  if #clean > 0 then
    tbl.caption.long[1] = pandoc.Plain(clean)
  else
    tbl.caption = { long = {}, short = pandoc.List() }
  end

  local ok, specs = pcall(parse_specs, merge_str)
  if not ok then
    io.stderr:write("[table-merge] ERROR: " .. tostring(specs) .. "\n")
    return tbl
  end

  return apply_merges(tbl, specs)
end
