-- Parses every .lua file in the repo (syntax check only). Run from the repo root.
local pipe = assert(io.popen("find . -name '*.lua' -not -path './.git/*'"))
local count, failures = 0, 0
for path in pipe:lines() do
  count = count + 1
  local chunk, err = loadfile(path)
  if not chunk then
    failures = failures + 1
    io.stderr:write("PARSE FAIL " .. tostring(err) .. "\n")
  end
end
pipe:close()
if failures > 0 or count == 0 then
  os.exit(1)
end
print("parsed " .. count .. " files")
