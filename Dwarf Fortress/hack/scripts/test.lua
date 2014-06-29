args = {...}

function split(str, pat)
   local t = {}  -- NOTE: use {n = 0} in Lua-5.0
   local fpat = "(.-)" .. pat
   local last_end = 1
   local s, e, cap = str:find(fpat, 1)
   while s do
      if s ~= 1 or cap ~= "" then
	 table.insert(t,cap)
      end
      last_end = e+1
      s, e, cap = str:find(fpat, last_end)
   end
   if last_end <= #str then
      cap = str:sub(last_end)
      table.insert(t, cap)
   end
   return t
end

file = args[1]..".txt"
path = dfhack.getDFPath().."/hack/scripts/spells/"..file

iofile = io.open(path,"r")
read = iofile:read("*all")
iofile:close()

reada = split(read,',')
x = {}
y = {}
t = {}
xi = 0
yi = 1
for i,v in ipairs(reada) do
	if split(v,'\n')[1] ~= v then
		xi = 1
		yi = yi + 1
	else
		xi = xi + 1
	end
	if v == 'X' or v == '\nX' then
		x0 = xi
		y0 = yi
	end
	if v == 'X' or v == '\nX' or v == '1' or v == '\n1' then
		t[i] = true
	else
		t[i] = false
	end
	x[i] = xi
	y[i] = yi
end

rx = math.max(table.unpack(x))
ry = math.max(table.unpack(y))
for i,_ in ipairs(x) do
	x[i] = x[i] - x0 + 121
	y[i] = y[i] - y0 + 146
	t[tostring(x[i])..'_'..tostring(y[i])] = t[i]
end

printall(t)
