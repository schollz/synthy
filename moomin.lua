-- moomin v0.1.0
-- soft, melancholic synth
--
-- llllllll.co/t/moomin
--
--
--
--    ▼ instructions below ▼


engine.name="Moomin"
articulation=include('moomin/lib/arm')
moomin={filter=0,amplitude=0}

function init()

	-- setup midi listening
	local midi_devices={"any"}
	local midi_channels={"all"}
	for i=1,16 do 
		table.insert(midi_channels,i)
	end
	for _, dev in ipairs(midi.devices) do
	  if dev.port ~= nil then
	  	table.insert(midi_devices,dev.name)
	    local conn=midi.connect(dev.port)
	    conn.event=function(data)
	      local d=midi.to_msg(data)
	      if dev.name~=midi_devices[params:get("moomin_midi_device")]
	      		and params:get("moomin_midi_device") > 1 then
	      			do return end 
	      end
	      if d.ch~=midi_channels[params:get("moomin_midi_ch")] 
	      		and params:get("moomin_midi_ch")>1 then
	      			do return end
	      end
	      if d.type=="note_on" then
	        engine.moomin_note_on(d.note,0.5+util.linlin(0,128,-0.25,0.25,d.vel))
	      elseif d.type=="note_off" then
	      	engine.moomin_note_off(d.note)
	      elseif d.cc==64 then -- sustain pedal
	      	local val=d.val
	      	if val > 0 then 
	      		val=1
	      	end
	      	if params:get("moomin_pedal")==1 then
	      		engine.moomin_sustain(val)
	      	else
	      		engine.moomin_sustenuto(val)
	      	end
	      end
	    end
	  end
	end

	params:add_group("MOOMIN",11)
	params:add_option("moomin_midi_device","midi device",midi_devices,1)
	params:add_option("moomin_midi_ch","midi channel",midi_channels,1)
	params:add_control("moomin_sub","sub",controlspec.new(0,3,'lin',0.1,1.0,'amp',0.1/3))
	params:set_action("moomin_sub",function(x)
	  engine.moomin_sub(x)
	end)
	params:add_control("moomin_lpf","lpf",controlspec.new(100,20000,'exp',10,8000,'hz',10/20000))
	params:set_action("moomin_lpf",function(x)
	  engine.moomin_lpf(x)
	end)
	params:add_control("moomin_hold_control","lpf hold control",controlspec.new(0,300,'exp',0.5,5,'s',0.5/300))
	params:set_action("moomin_hold_control",function(x)
	  engine.moomin_hold_control(x)
	end)
	params:add_control("moomin_reverb","reverb send",controlspec.new(0,100,'lin',1,2,'%',1/100))
	params:set_action("moomin_reverb",function(x)
	  engine.moomin_reverb(x)
	end)
	params:add_control("moomin_attack","attack",controlspec.new(0,30,'exp',0.001,0.1,'s',0.001/30))
	params:set_action("moomin_attack",function(x)
	  engine.moomin_attack(x)
	end)
	params:add_control("moomin_decay","decay",controlspec.new(0,30,'exp',0.001,0.1,'s',0.001/30))
	params:set_action("moomin_decay",function(x)
	  engine.moomin_decay(x)
	end)
	params:add_control("moomin_sustain","sustian",controlspec.new(0,1,'lin',0.1,1.0,'amp',0.1/1))
	params:set_action("moomin_sustain",function(x)
	  engine.moomin_sustain(x)
	end)
	params:add_control("moomin_release","release",controlspec.new(0,30,'exp',0.001,0.1,'s',0.001/30))
	params:set_action("moomin_release",function(x)
	  engine.moomin_release(x)
	end)
	params:add_option("moomin_pedal_mode","pedal mode",{"sustain","sostenuto"},1)


	arms={}
	arms[1]=articulation:new()
	arms[1]:init(20,62,-1)
	arms[2]=articulation:new()
	arms[2]:init(128-20,62,1)

	moomin.filter=0
  osc.event=function(path,args,from)
  	if args[1]==1 then
	  	moomin.filter=tonumber(args[2])
	  elseif args[1]==2 then
	  	moomin.amplitude=tonumber(args[2])
	  end
  end

	clock.run(function()
		while true do
			clock.sleep(1/15)
			redraw()
		end
	end)
end


pos_x=30
function enc(k,z)
  if k==2 then
    pos_x=pos_x+z
  elseif k==3 then
	 params:delta("lpf",z)
   --pos_y=pos_y-z
  end

end

function redraw()
	screen.clear()

	local color=math.floor(util.linexp(-1,1,1,15.999,moomin.filter))
	local pos_y=math.floor(util.linlin(1.3,4.3,128,1,math.log(moomin.filter)))

	local ps={}
	local gy={}
	local base={}
	for i=1,2 do
		gy[i]={}
		gy[i][1]=util.linlin(-1,1,-1,2,calculate_lfo(i*4,i*2))
		gy[i][2]=util.linlin(-1,1,-1,2,calculate_lfo(i*5,i*3))
		if i==1 then
			base[i]=util.linlin(-1,1,16,24,calculate_lfo(i*5,i*3))
		else
			base[i]=util.linlin(-1,1,128-24,128-16,calculate_lfo(i*5,i*3))
		end
	end

	screen.line_width(1)
	screen.level(util.clamp(color-3,1,15))
	for i=1,2 do
		screen.move(base[i],62)
		if i==1 then
			screen.curve(1-20+rmove(4*i,i),64+rmove(3*i,i),1,-30,128-pos_x,pos_y+5)
		else
			screen.curve(128+10+rmove(4*i,i),64+rmove(3*i,i),128,-10,128-pos_x,pos_y+5)
		end
		screen.stroke()
	end

	screen.line_width(2)
	for i, arm in ipairs(arms) do
		arm:set_base(base[i],62)
		arm:move(pos_x+(i-1)*20-10+gy[i][1],pos_y+gy[i][2])
		ps[i]=arm:draw(color)
	end
	screen.move(ps[1][3][1],ps[1][3][2])
	screen.line(ps[2][3][1],ps[2][3][2])
	screen.stroke()

	screen.line_width(1)
	local eyes={{ps[1][3][1]-5,ps[1][3][2]+4},{ps[2][3][1]+5,ps[2][3][2]-4}}
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
			local pyadjust=0
			if i==1 then
				pyadjust=-2
			end
			screen.level(0)
			screen.circle(eye[1]-4, eye[2]-5+pyadjust, 3+i)
			screen.fill()
			screen.level(color)
			screen.circle(eye[1]-4, eye[2]-5+pyadjust, 3+i)
			screen.stroke()
			screen.level(color)
			screen.circle(eye[1]-5+i, eye[2]-(i*0.5)-2+pyadjust, 2)
			screen.fill()
		end
	end

	screen.line_width(2)
	local mouth=util.linlin(0,0.02,5,40,moomin.amplitude)
	screen.level(color)
	screen.curve(eyes[1][1]+2,eyes[1][2]+6,pos_x,pos_y+mouth,eyes[2][1]-1,eyes[2][2]+7)
	screen.stroke()

	screen.level(color)
	screen.move(base[1],62)
	screen.line(base[2],62)
	screen.stroke()

	screen.update()

	local deviation_x=(ps[1][3][1]-ps[2][3][1])/20
	-- TODO: send the distance between eyes as a modulation of the volume
	-- TODO: send average eye X/Y position as modulation of ??/??
end


function rerun()
  norns.script.load(norns.state.script)
end

function rmove(period,offset,amt)
	if amt==nil then
		amt=4
	end
	return util.linlin(-1,1,-amt,amt,calculate_lfo(period,offset))
end

function calculate_lfo(period,offset)
  if period==0 then
    return 1
  else
    return math.sin(2*math.pi*clock.get_beat_sec()*clock.get_beats()/period+offset)
  end
end
