engine.name="Velvet"

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
end