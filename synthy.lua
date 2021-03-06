-- synthy v0.3.2
-- soft, melancholic synth
--
-- llllllll.co/t/synthy
--
--
--
--    ▼ instructions below ▼
-- E2 modulates flanger
-- E3 modulates lpf
-- K2 generates chords
-- K3 stops/starts chord
--    sequencer

engine.name="Synthy"
articulation=include('synthy/lib/arm')
fourchords_=include("synthy/lib/fourchords")
chordy_=include("synthy/lib/chordsequencer")

synthy={filter=0,amplitude=0,show_help=0,chord=nil,note_played=false,notes={}}

function note_on(note,velocity)
  synthy.note_played=true
  synthy.notes[note]=true
  local notes={}
  for note,v in pairs(synthy.notes) do
    table.insert(notes,note)
  end
  table.sort(notes)

  if params:get("synthy_crow")==2 then
    for i,note in ipairs(notes) do
      if i<=4 then
        crow.output[i].volts=(note-60)/12
      end
    end
  end
  if params:get("synthy_jf")==2 then
    for i,note in ipairs(notes) do
      if i<=4 then
        crow.ii.jf.play_voice(i,(note-60)/12,util.linlin(0,1.0,0,10,velocity))
      end
    end
  end

  local ch=params:get("synthy_midiout_ch")-1
  if ch==0 then
    ch=1
  end
  if params:get("synthy_midiout_device")==2 then
    -- output to ALL midi devices
    print("midiout: "..note)
    for _,conn in ipairs(midi_connections) do
      conn:note_on(note,math.floor(velocity*127),ch)
    end
  elseif params:get("synthy_midiout_device")>2 then
    print("midiout: "..note)
    midi_connections[params:get("synthy_midiout_device")-2]:note_on(note,math.floor(velocity*127),ch)
  end

  engine.synthy_note_on(note,velocity)
end

function note_off(note)
  synthy.notes[note]=false

  local ch=params:get("synthy_midiout_ch")-1
  if ch==0 then
    ch=1
  end
  if params:get("synthy_midiout_device")==2 then
    -- output to ALL midi devices
    for _,conn in ipairs(midi_connections) do
      conn:note_off(note,0,ch)
    end
  elseif params:get("synthy_midiout_device")>2 then
    midi_connections[params:get("synthy_midiout_device")-2]:note_off(note,0,ch)
  end

  engine.synthy_note_off(note)
end

function init()

  -- setup midi listening
  midi_connections={}
  local midi_devices={"none","any"}
  local midi_channels={"all"}
  for i=1,16 do
    table.insert(midi_channels,i)
  end
  for j,dev in pairs(midi.devices) do
    if dev.port~=nil then
      table.insert(midi_devices,dev.name)
      local conn=midi.connect(dev.port)
      table.insert(midi_connections,conn)
      conn.event=function(data)
        local d=midi.to_msg(data)
        -- visualize ccs
        -- if d.cc~=nil and d.val~=nil then
        --   if d.cc>0 and d.val>0 then
        --     print("cc",d.cc,d.val)
        --   end
        -- end
        if params:get("synthy_midi_device")==1 then
          do return end
        end
        if dev.name~=midi_devices[params:get("synthy_midi_device")]
          and params:get("synthy_midi_device")>2 then
          do return end
        end
        if d.ch~=midi_channels[params:get("synthy_midi_ch")]
          and params:get("synthy_midi_ch")>2 then
          do return end
        end
        if d.type=="note_on" then
          note_on(d.note,0.5+util.linlin(0,128,-0.25,0.25,d.vel))
        elseif d.type=="note_off" then
          engine.synthy_note_off(d.note)
        elseif d.cc==64 then -- sustain pedal
          local val=d.val
          if val>126 then
            val=1
          else
            val=0
          end
          if params:get("synthy_pedal_mode")==1 then
            engine.synthy_sustain(val)
          else
            engine.synthy_sustenuto(val)
          end
        end
      end
    end
  end

  params:add_group("SYNTHY",21)
  params:add_option("synthy_midi_device","midi device",midi_devices,1)
  params:add_option("synthy_midi_ch","midi channel",midi_channels,1)
  params:add_control("synthy_detuning","squishy detuning",controlspec.new(0,20,'lin',0.1,1,'',0.1/20))
  params:add_control("synthy_tremolo","squishy tremolo",controlspec.new(0,20,'lin',0.1,1,'',0.1/20))
  params:add_control("synthy_sub","sub",controlspec.new(0,3,'lin',0.1,1.0,'amp',0.1/3))
  params:set_action("synthy_sub",function(x)
    engine.synthy_sub(x)
  end)
  params:add_control("synthy_lpf","lpf",controlspec.WIDEFREQ)
  params:set_action("synthy_lpf",function(x)
    print("synthy: setting lpf "..x)
    engine.synthy_lpf(x)
  end)
  params:add_control("synthy_hold_control","lpf hold control",controlspec.new(0,300,'lin',1,5,'s',1/300))
  params:set_action("synthy_hold_control",function(x)
    engine.synthy_hold_control(x)
  end)
  params:add_control("synthy_reverb","reverb send",controlspec.new(0,100,'lin',0.1,2,'%',0.1/100))
  params:set_action("synthy_reverb",function(x)
    engine.synthy_reverb(x/100)
  end)
  params:add_control("synthy_flanger","flanger send",controlspec.new(0,100,'lin',1,0,'%',1/100))
  params:set_action("synthy_flanger",function(x)
    x=x/100
    engine.synthy_flanger(x*x*math.exp(x)/math.exp(1))
  end)
  params:add_control("synthy_attack","attack",controlspec.new(0.01,30,'lin',0.01,1.0,'s',0.01/30))
  params:set_action("synthy_attack",function(x)
    engine.synthy_attack(x)
  end)
  params:add_control("synthy_decay","decay",controlspec.new(0,30,'lin',0.1,0.1,'s',0.1/30))
  params:set_action("synthy_decay",function(x)
    engine.synthy_decay(x)
  end)
  params:add_control("synthy_sustain","sustain",controlspec.new(0,1,'lin',0.1,0.9,'amp',0.1/1))
  params:set_action("synthy_sustain",function(x)
    engine.synthy_sustain(x)
  end)
  params:add_control("synthy_release","release",controlspec.new(0,30,'lin',0.1,5,'s',0.1/30))
  params:set_action("synthy_release",function(x)
    engine.synthy_release(x)
  end)
  params:add_option("synthy_pedal_mode","pedal mode",{"sustain","sostenuto"},1)
  params:add_option("synthy_groove","groove",{"no","yes"},1)
  params:add_option("synthy_crow","crow output",{"no","yes"},1)
  params:add_option("synthy_jf","jf output",{"no","yes"},1)
  params:set_action("synthy_jf",function(x)
    if x==2 then
      crow.ii.jf.mode(1)
    end
  end)
  params:add_control("synthy_gyro_juice","gyro juice",
  controlspec.new(0.1,8,'lin',0.1,2,"tsp",0.1/8))
  params:set_action("synthy_gyro_juice",function (x)
    engine.synthy_gyro_juice(x)
  end)
  params:add_option("synthy_chord_selection","chord randomness",{"popular","unpopular"},1)
  params:add_option("synthy_midiout_device","midi out device",midi_devices,1)
  params:add_option("synthy_midiout_ch","midi out channel",midi_channels,1)

  arms={}
  arms[1]=articulation:new()
  arms[1]:init(20,62,-1)
  arms[2]=articulation:new()
  arms[2]:init(128-20,62,1)

  synthy.filter=0
  gyro_juice=1.5
  osc.event=function(path,args,from)
    -- from touchOSC mark I (the free one):
    -- https://hexler.net/touchosc-mk1/manual/configuration-options
    if path=="/accxyz" then
      local gyro_juice=params:get("synthy_gyro_juice")
      inc_pos_x(util.clamp((args[1]*gyro_juice)^3,-2,2))
      inc_lpf(util.clamp((args[2]*gyro_juice)^3,-0.5,0.5))
    end
    if args[1]==1 then
      synthy.filter=tonumber(args[2])
    elseif args[1]==2 then
      synthy.amplitude=tonumber(args[2])
    end
  end

  -- initiate sequencer
  fourchords=fourchords_:new({fname=_path.code.."synthy/lib/4chords_top1000.txt"})
  chordy=chordy_:new()
  chordy:chord_on(function(data)
    print("synthy: playing "..data[1])
    synthy.chord=data[1]
    -- data[1] is chord name
    -- data[2] is table of parameters
    -- data[2][..].m is midi value
    -- data[2][..].v is frequency
    -- data[2][..].v is volts
    -- data[2][..].n is name of note
    for i,d in ipairs(data[2]) do
      note_on(d.m,0.5)
    end
  end)
  chordy:chord_off(function(data)
    print("synthy: stopping "..data[1])
    for i,d in ipairs(data[2]) do
      note_off(d.m)
    end
  end)
  chordy:on_stop(function()
    synthy.chord=nil
  end)

  clock.run(function()
    clock.sleep(3)
    if not synthy.note_played then
      synthy.show_help=120
      synthy.note_played=true
      clock.sleep(3)
      local new_chords=table.concat(fourchords:random_weighted()," ")
      if params:get("synthy_chord_selection")==2 then
        print("synthy: getting unpopular chords")
        new_chords=table.concat(fourchords:random_unpopular()," ")
      end
      print("synthy: generated new chords: "..new_chords)
      params:set("chordy_chords",new_chords)
      params:delta("chordy_start",1)
    end
  end)
  clock.run(function()
    while true do
      clock.sleep(1/15)
      redraw()
      if synthy.show_help>0 then
        synthy.show_help=synthy.show_help-1
      end
    end
  end)

  pos_x=30
  params:set("synthy_lpf",6000)
end

function inc_pos_x(inc)
  params:delta("synthy_flanger",inc)
  pos_x=math.floor(util.linlin(0,100,30,128.9,params:get("synthy_flanger")))
end

function inc_lpf(inc)
  params:delta("synthy_lpf",inc)
end

function enc(k,z)
  if k==2 then
    inc_pos_x(unity(z))
  elseif k==3 then
    inc_lpf(unity(z))
    --pos_y=pos_y-z
  end

end

function key(k,z)
  if k==2 and z==1 then
    local new_chords=table.concat(fourchords:random_weighted()," ")
    if params:get("synthy_chord_selection")==2 then
      print("synthy: getting unpopular chords")
      new_chords=table.concat(fourchords:random_unpopular()," ")
    end
    print("synthy: generated new chords: "..new_chords)
    params:set("chordy_chords",new_chords)
  elseif k==3 and z==1 then
    params:delta("chordy_start",1)
  end
end

function redraw()
  screen.clear()
  if params:get("synthy_groove")==2 then
    pos_x=util.linlin(-1,1,30,80,calculate_lfo(clock.get_beat_sec()*8,0))
  end
  local color=math.floor(util.linexp(-1,1,1,15.999,synthy.filter))
  -- local pos_y=math.floor(129-util.clamp(util.linlin(math.log(50),math.log(20000),1,150,math.log(synthy.filter)),1,128))
  local pos_y=math.floor(util.clamp(util.linlin(math.log(125),math.log(16000),90,1,math.log(synthy.filter)),10,128))

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
  for i,arm in ipairs(arms) do
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
  for i,eye in ipairs(eyes) do
    if blink then
      screen.level(color)
      screen.circle(eye[1]-4,eye[2]-5,6)
      screen.fill()
      screen.level(color)
      screen.circle(eye[1]-4,eye[2]-5,6)
      screen.stroke()
    else
      local pyadjust=0
      if i==1 then
        pyadjust=-2
      end
      screen.level(0)
      screen.circle(eye[1]-4,eye[2]-5+pyadjust,3+i)
      screen.fill()
      screen.level(color)
      screen.circle(eye[1]-4,eye[2]-5+pyadjust,3+i)
      screen.stroke()
      screen.level(color)
      screen.circle(eye[1]-5+i,eye[2]-(i*0.5)-2+pyadjust,2)
      screen.fill()
    end
  end

  screen.line_width(2)
  local mouth=util.linlin(0,0.02,5,40,synthy.amplitude)
  screen.level(color)
  screen.curve(eyes[1][1]+2,eyes[1][2]+6,pos_x,pos_y+mouth,eyes[2][1]-1,eyes[2][2]+7)
  screen.stroke()

  screen.level(color)
  screen.move(base[1],62)
  screen.line(base[2],62)
  screen.stroke()

  if synthy.show_help>0 then
    screen.level(15)
    screen.rect(70,10,56,53)
    screen.fill()
    screen.level(0)
    screen.move(74,18)
    screen.text("looks like")
    screen.move(74,18+8)
    screen.text("you're mak-")
    screen.move(74,18+8+8)
    screen.text("ing music.")
    screen.move(74,18+8+8+8)
    screen.text("need some")
    screen.move(74,18+8+8+8+8)
    screen.text("help with")
    screen.move(74,18+8+8+8+8+8)
    screen.text("that?")
  end
  if synthy.chord~=nil then
    screen.level(15)
    screen.rect(70,10,56,50)
    screen.fill()
    screen.level(0)
    screen.move(74+22,18+25)
    screen.font_size(32)
    screen.text_center(synthy.chord)
    screen.font_size(8)
  end

  screen.update()

  local deviation_x=(ps[1][3][1]-ps[2][3][1]+32)/400*params:get("synthy_detuning") -- deviation around 0
  local deviation_y=-1*math.abs(ps[1][3][2]-ps[2][3][2]+3)/10*params:get("synthy_tremolo")
  engine.synthy_perturb1(deviation_x)
  engine.synthy_perturb2(deviation_y)
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

function unity(n)
  if n>0 then
    return 1
  else
    return-1
  end
end
