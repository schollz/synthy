-- moomin v0.1.0
-- soft, melancholic synth
--
-- llllllll.co/t/moomin
--
--
--
--    ▼ instructions below ▼


-- include('moomin/lib/p8')
articulation=include('moomin/lib/arm')
engine.name="Moomin"

function init()

	for _, dev in ipairs(midi.devices) do
	  if dev.port ~= nil then
	    local conn=midi.connect(dev.port)
	    conn.event=function(data)
	      local d=midi.to_msg(data)
	      if d.type=="note_on" then
	        engine.moomin_note_on(d.note,0.5)
	      elseif d.type=="note_off" then
	      	engine.moomin_note_off(d.note)
	      end
	    end
	  end
	end


	arms={}
	arms[1]=articulation:new()
	arms[1]:init(20,64,-1)
	arms[2]=articulation:new()
	arms[2]:init(128-20,64,1)

	filterpos=0
  osc.event=function(path,args,from)
  	filterpos=tonumber(args[2])
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
    pos_y=pos_y-z
  end

end

-- -- https://twitter.com/jamesedge/status/1419289823580405768
-- l,x,y,z,w={0,0,0},0,0,0,0
-- function redraw()
--  screen.clear()
--  screen.level(15)
--  u,v,e,f,p,q=1,0,pos_x,pos_y,64,32
--  for g=1,3 do 
--    a=l[g]
--    c,s=cos(a),-sin(a)
--    u,v=u*c-v*s,u*s+v*c 
--    m,n=p+u*25,q+v*25
--    line(p,q,m,n)
--    circ(m,n,2)
--    l[g]=l[g]+((q-w)*x+(z-p)*y)*.0001
--    p,q=m,n 
--  end 
--  x,y,z,w=(e-p)*.1,(f-q)*.1,p,q 
--  circ(e,f,4)
--  flip()
-- end

function redraw()
	screen.clear()

	local color=math.floor(util.linexp(-1,1,1,15.999,filterpos))
	screen.level(1)
	screen.circle(pos_x,pos_y+48,76+4)
	screen.fill()
	screen.level(0)
	screen.circle(pos_x,pos_y+48,76)
	screen.fill()

	local ps={}
	local gy={}
	for i=1,2 do
		gy[i]={}
		gy[i][1]=util.linlin(-1,1,-1,2,calculate_lfo(i*4,i*2))
		gy[i][2]=util.linlin(-1,1,-1,2,calculate_lfo(i*5,i*3))
	end
	for i, arm in ipairs(arms) do
		arm:move(pos_x+(i-1)*20-10+gy[i][1],pos_y+gy[i][2])
		ps[i]=arm:draw(color)
	end
	screen.move(ps[1][3][1],ps[1][3][2])
	screen.line(ps[2][3][1],ps[2][3][2])
	screen.stroke()

	local eyes={{ps[1][3][1]-5,ps[1][3][2]+5},{ps[2][3][1]+5,ps[2][3][2]-5}}
	local blink=math.random()<0.01
	for i, eye in ipairs(eyes) do
		if blink then
			screen.level(color)
		  screen.circle(eye[1]-4, eye[2]-5, 6)
		  screen.fill()
			screen.level(color)
			screen.circle(eye[1]-4, eye[2]-5, 6)
			screen.stroke()
		else
			screen.level(0)
			screen.circle(eye[1]-4, eye[2]-5, 6)
			screen.fill()
			screen.level(color)
			screen.circle(eye[1]-4, eye[2]-5, 6)
			screen.stroke()
			screen.level(color)
			screen.circle(eye[1]-(i), eye[2]-(i), 2)
			screen.fill()
		end
	end

	local mouth=util.linlin(-1,1,-10,40,filterpos)
	screen.level(color)
	screen.curve(eyes[1][1]+2,eyes[1][2]+6,pos_x,pos_y+mouth,eyes[2][1]-1,eyes[2][2]+7)
	screen.stroke()


	screen.update()
end


function rerun()
  norns.script.load(norns.state.script)
end

function calculate_lfo(period,offset)
  if period==0 then
    return 1
  else
    return math.sin(2*math.pi*clock.get_beat_sec()*clock.get_beats()/period+offset)
  end
end
