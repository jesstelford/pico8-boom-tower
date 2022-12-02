-- From https://www.lexaloffle.com/bbs/?tid=37822
debugger=(function()

    poke(0x5f2d, 1)

    -- watched variables
    local vars,sy={},0

    -- mouse state, expanded, text cursor
    local mx,my,mb,pb,click,mw,exp,x,y

    function butn(exp,x,y)
        local hover=mx>=x and mx<x+4 and my>=y and my<y+6
        print(exp and "-" or "+",x,y,hover and 7 or 5)
        return hover and click
    end

    -- convert value into something easier to traverse and inspect
    function inspect(v,d)
        d=d or 0
        local t=type(v)  
        if t=="table" then
            if(d>5)return "[table]"
            local props={}
            for key,val in pairs(v) do
                props[inspect(key)]=inspect(val,d+1)
            end
            return {
                expand=false,
                props=props
            }
        elseif t=="string" then
            return chr(34)..v..chr(34)
        elseif t=="boolean" then
            return v and "true" or "false"
        elseif t=="nil" or t=="function" or t=="thread" then
            return "["..t.."]"
        else 
            return ""..v
        end
    end

    function drawvar(var,name)
        if type(var)=="string" then     
            print(name..":",x+4,y,6)
            print(var,x+#(""..name)*4+8,y,7)
            y+=6
        else

            -- expand button
            if(butn(var.expand,x,y))var.expand=not var.expand

            -- name
            print(name,x+4,y,12) y+=6

            -- content
            if var.expand then
                x+=2
                for key,val in pairs(var.props) do
                    drawvar(val,key)       
                end
                x-=2
            end
        end
    end

    function copyuistate(src,dst)
        if type(src)=="table" and type(dst)=="table" then
            dst.expand=src.expand
            for key,val in pairs(src.props) do
                copyuistate(val,dst.props[key])
            end
        end
    end

    function watch(var,name)
        name=name or "[var]"
        local p,i=vars[name],inspect(var)
        if(p)copyuistate(p,i)
        vars[name]=i
    end 

    function clear()
        vars={}
    end 

    function draw(dx,dy,w,h)
        dx=dx or 0
        dy=dy or 48
        w=w or 128-dx
        h=h or 128-dy

        -- collapsed mode
        if not exp then
            dx+=w-10
            w,h=10,5
        end

        -- window
        clip(dx,dy,w,h)
        rectfill(0,0,128,128,1)
        x=dx+2 y=dy+2-sy

        -- read mouse
        mx,my,mw=stat(32),stat(33),stat(36)
        mb=band(stat(34),1)~=0
        click=mb and not pb and mx>=dx and mx<dx+w and my>=dy and my<dy+h
        pb=mb

        if exp then     

            -- variables                            
            for k,v in pairs(vars) do
                drawvar(v,k)
            end

            -- scrolling
            local sh=y+sy-dy
            sy=max(min(sy-mw*8,sh-h),0)
        end

        -- expand/collapse btn
        if(butn(exp,dx+w-10,dy))exp=not exp

        -- draw mouse ptr
        clip()          
        line(mx,my,mx,my+2,8)
        color(7) 
    end

    function show()
        exp=true
        while exp do
            draw()
            flip()
        end
    end

    function prnt(v,name)
        watch(v,name)
        show()
    end

    return{
        watch=watch,
        clear=clear,
        expand=function(val)
            if(val~=nil)exp=val
            return exp
        end,
        draw=draw,
        show=show,
        print=prnt
    }
end)()

-- Debug overlay, triggered by pressing `
-- From: https://www.lexaloffle.com/bbs/?tid=33099
dbg_dbtn = '`' dbt = 7 don = false cc = 8 mc = 15 addr = 0x5e00 function dtxt(txt,x,y,c) print(txt, x,y+1,1) print(txt,x,y,c) end function init_dbg() poke(0x5f2d, 1) test_num = peek(∧addr) or 0 poke(∧addr, test_num+1) end dbtm = 0 dbu = {0,0,0} function sdbg() if stat(31) == dbg_dbtn then if don==false then don=true else don=false end end if don != true then return end local c=dbt local cpu=stat(1)*100 local mem=(stat(0)/100)/10*32 local fps=stat(7) local u=stat(7)..'' local _x=124-(#u*4) local du = {dbu[1],dbu[2],dbu[3]} dtxt(u, 124-(#u*4), 1, c) u=cpu..'%' dtxt(u, 124-(#u*4), 7, c) u=mem..'kb /' dtxt(u, 124-(#u*4)-32, 13, c) dtxt('31.25kib', 128-33, 13, c) dtxt(du[3]..'h', 124-44, 128-9, c) dtxt(du[2]..'m', 124-28, 128-9, c) dtxt(du[1] ..'s', 124-12, 128-9, c) dtxt('cpu', 1, 7, c) dtxt('mem', 1, 13, c) dtxt('pico-'..stat(5), 1, 128-15, c) dtxt('uptime', 1, 128-9, c) dbtm+=1 dbu[1] = flr(dbtm/stat(8)) dbu[2] = flr(dbu[1]/60) dbu[3] = flr(dbu[2]/60) dtxt('test number: '..peek(0x5e00), 0, 24, c) dtxt('mouse: {'..stat(32)..','..stat(33)..'}\nbitmask: '..stat(34), 0, 30, c) draw_dbg_info(c) end function draw_dbg_info(c) local m = {stat(32)/8, stat(33)/8} local tile=fget(mget(m[0],m[1]), 0) dtxt('tile flags', 0, 6*8, c) local res = {} res[1] = fget(mget(m[1],m[2]), 0) res[2] = fget(mget(m[1],m[2]), 1) res[3] = fget(mget(m[1],m[2]), 2) res[4] = fget(mget(m[1],m[2]), 3) res[5] = fget(mget(m[1],m[2]), 4) res[6] = fget(mget(m[1],m[2]), 5) res[7] = fget(mget(m[1],m[2]), 6) res[8] = fget(mget(m[1],m[2]), 7) dtxt('{'.. blton(res[1]) ..','..blton(res[2]) ..','..blton(res[3]) ..','..blton(res[4]) ..'\n '..blton(res[5]) ..','..blton(res[6]) ..','..blton(res[7]) ..','..blton(res[8]) ..'}\ntile-id: '..mget(m[1],m[2]), 0, 6*9, c) print('color: '..pget(m[1]*8,m[2]*8), 0, 6*12, max(pget(m[1]*8,m[2]*8), 1)) circ(stat(32), stat(33), 3, c) circfill(stat(32), stat(33),1, c) end function blton(v) return v and 1 or 0 end

function tableToString(table, pretty, indent)
  indent = indent or ''
  local nextIndent = indent..'  '
  local newline = '\n'
  if (not pretty) then
    nextIndent = ''
    newline = ''
  end
  local str = "{"
  for key, value in pairs(table) do
    str = str..newline..nextIndent.."["..key.."]="..(type(value) == "table" and tableToString(value, pretty, nextIndent) or value)
  end
  return str..newline..indent.."}"
end

function printTable(table, pretty)
  printh(tableToString(table, pretty))
end
