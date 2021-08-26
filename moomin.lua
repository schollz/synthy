-- engine.name="Velvet"

include('moomin/lib/p8')

function init()
	-- clock.run(function()
	-- 	engine.velvet_note_on(60)
	-- 	clock.sleep(2)
	-- 	engine.velvet_note_on(60-12)
	-- 	clock.sleep(2)
	-- 	engine.velvet_note_on(64)
	-- 	clock.sleep(4)
	-- 	engine.velvet_note_off(60)
	-- end)

	for _, dev in ipairs(midi.devices) do
	  if dev.port ~= nil then
	    local conn=midi.connect(dev.port)
	    conn.event=function(data)
	      local d=midi.to_msg(data)
	      if d.type=="note_on" then
	        engine.velvet_note_on(d.note)
	      elseif d.type=="note_off" then
	      	engine.velvet_note_off(d.note)
	      end
	    end
	  end
	end


	
	clock.run(function()
		while true do
			clock.sleep(1/15)
			redraw()
		end
	end)
end


pos_x,pos_y=30,30
function enc(k,z)
  if k==2 then
    pos_x=pos_x+z
  elseif k==3 then
    pos_y=pos_y+z
  end

end

-- https://twitter.com/jamesedge/status/1419289823580405768
l,x,y,z,w={0,0,0},0,0,0,0
function redraw()
 screen.clear()
 screen.level(15)
 u,v,e,f,p,q=1,0,pos_x,pos_y,64,32
 for g=1,3 do 
   a=l[g]
   c,s=cos(a),-sin(a)
   u,v=u*c-v*s,u*s+v*c 
   m,n=p+u*25,q+v*25
   line(p,q,m,n)
   circ(m,n,2)
   l[g]=l[g]+((q-w)*x+(z-p)*y)*.0001
   p,q=m,n 
 end 
 x,y,z,w=(e-p)*.1,(f-q)*.1,p,q 
 circ(e,f,4)
 flip()
end
