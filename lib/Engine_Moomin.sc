// Engine_Moomin
Engine_Moomin : CroneEngine {
	// <moomin>
	var moominParameters;
	var moominVoices;
	var moominVoicesOn;
	var moominSynthFX;
	var moominBusFx;
	var fnNoteOn, fnNoteOff;
	var pedalSustainOn=false;
	var pedalSostenutoOn=false;
	var pedalSustainNotes;
	var pedalSostenutoNotes;
	// </moomin>


	*new { arg context, doneCallback;
		^super.new(context, doneCallback);
	}

	alloc {

		// <moomin>
		// initialize variables
		moominParameters=Dictionary.with(*["reverbLevel"->0.05,"sub"->1.0,"attack"->1.0,"decay"->0.2,"sustain"->0.9,"release"->5.0,"portamento"->1.0]);
		moominVoices=Dictionary.new;
		moominVoicesOn=Dictionary.new;
		pedalSustainNotes=Dictionary.new;
		pedalSostenutoNotes=Dictionary.new;

		// initialize synth defs
		SynthDef("moominfx",{
			arg in, out, reverb=0.02;
			var snd,z,y;
			snd = In.ar(in,2);
			// global filter
			snd=MoogLadder.ar(snd.tanh,LinExp.kr(VarLag.kr(LFNoise0.kr(1/6),6,warp:\sine),-1,1,3200,8000));
			
			// reverb predelay time :
			z = DelayN.ar(snd, 0.048);
			// 7 length modulated comb delays in parallel :
			y = Mix.ar(Array.fill(7,{ CombL.ar(z, 0.1, LFNoise1.kr(0.1.rand, 0.04, 0.05), 15) }));
			// two parallel chains of 4 allpass delays (8 total) :
			4.do({ y = AllpassN.ar(y, 0.050, [0.050.rand, 0.050.rand], 1) });
			// add original sound to reverb and play it :
			snd=snd+(reverb*y);
			snd=HPF.ar(snd,20);
			Out.ar(out,snd);
		}).add;

		SynthDef("moominosc",{
			arg out=0,hz=220,amp=0.5,gate=1,sub=0,portamento=1,
			attack=1.0,decay=0.2,sustain=0.9,release=5;
			var snd,note,env;
			note=Lag.kr(hz,portamento).cpsmidi;
			sub=Lag.kr(sub,1);
			snd=Pan2.ar(Pulse.ar((note-12).midicps,LinLin.kr(LFTri.kr(0.5),-1,1,0.2,0.8))/12*amp*sub);
			snd=snd+Mix.ar({
				var snd2;
				snd2=SawDPW.ar(note.midicps);
				snd2=LPF.ar(snd2,LinExp.kr(SinOsc.kr(rrand(1/30,1/10),rrand(0,2*pi)),-1,1,2000,12000));
				snd2=DelayC.ar(snd2, rrand(0.01,0.03), LFNoise1.kr(Rand(5,10),0.01,0.02)/15 );
				Pan2.ar(snd2,VarLag.kr(LFNoise0.kr(1/3),3,warp:\sine))/12*amp
			}!2);
			env=EnvGen.ar(Env.adsr(attack,decay,sustain,release),gate,doneAction:2);
			Out.ar(out,snd*env);
		}).add;

		// initialize fx synth and bus
		context.server.sync;
		moominBusFx = Bus.audio(context.server,2);
		context.server.sync;
		moominSynthFX = Synth.new("moominfx",[\out,0,\in,moominBusFx,\reverb,moominParameters.at("reverb")]);
		context.server.sync;

		// intialize helper functions
		fnNoteOn= {
			arg note,amp;
			var lowestNote=10000;
			var sub=0;
			("moomin_note_on "++note).postln;
			// low-note priority for sub oscillator
			moominVoicesOn.keysValuesDo({ arg key, syn;
				if (key<lowestNote,{
					lowestNote=key;
				});
			});
			if (lowestNote<10000,{
				if (note<lowestNote,{
					sub=1;
					moominVoices.at(lowestNote).set(\sub,0);
				},{
					sub=0;
				});
			},{
				sub=1;
			});

			("sub = "++sub).postln;
			moominVoices.put(note,
				Synth.before(moominSynthFX,"moominosc",[
					\amp,amp,
					\out,moominBusFx,
					\hz,note.midicps,
					\sub,sub*moominParameters.at("sub"),
					\attack,moominParameters.at("attack"),
					\decay,moominParameters.at("decay"),
					\sustain,moominParameters.at("sustain"),
					\release,moominParameters.at("release"),
					\portamento,moominParameters.at("portamento"),
				]);
			);
			moominVoicesOn.put(note,1);
			NodeWatcher.register(moominVoices.at(note));
		};
		
		fnNoteOff = {
			arg note;
			var lowestNote=10000;
			("moomin_note_off "++note).postln;

			moominVoicesOn.removeAt(note);

			if (pedalSustainOn==true,{
				pedalSustainNotes.put(note,1);
			},{
				if ((pedalSostenutoOn==true)&&(pedalSostenutoNotes.at(note)!=nil),{
					// do nothing, it is a sostenuto note
				},{
					// remove the sound
					moominVoices.at(note).set(\gate,0);
					// swap sub
					moominVoicesOn.keysValuesDo({ arg key, syn;
						if (key<lowestNote,{
							lowestNote=key;
						});
					});
					if (lowestNote<10000,{
						("swapping sub to "++lowestNote).postln;
						moominVoices.at(note).set(\sub,0);
						moominVoices.at(lowestNote).set(\sub,moominParameters.at("sub"));
					});
				});
			});


		};



		// add norns commands
		this.addCommand("moomin_note_on", "if", { arg msg;
			var lowestNote=10000;
			var note=msg[1];
			if (moominVoices.at(note)!=nil,{
				if (moominVoices.at(note).isRunning==true,{
					("moomin_note_on retrigger "++note).postln;
					moominVoices.at(note).set(\hz,msg[1].midicps,\amp,msg[2],\gate,0);
					moominVoices.at(note).set(\gate,1);
					moominVoicesOn.keysValuesDo({ arg key, syn;
						if (key<lowestNote,{
							lowestNote=key;
						});
					});
					if (note<lowestNote,{
						("swapping sub to "++note).postln;
						moominVoices.at(lowestNote).set(\sub,0);
						moominVoices.at(note).set(\sub,moominParameters.at("sub"));
					});
					moominVoicesOn.put(note,1);
				},{ fnNoteOn.(msg[1],msg[2]); });
			},{  fnNoteOn.(msg[1],msg[2]); });
		});	

		this.addCommand("moomin_note_off", "i", { arg msg;
			var note=msg[1];
			if (moominVoices.at(note)!=nil,{
				if (moominVoices.at(note).isRunning==true,{
					fnNoteOff.(note);
				});
			});
		});

		this.addCommand("moomin_sustain", "i", { arg msg;
			pedalSustainOn=(msg[1]==1);
			if (pedalSustainOn==false,{
				// release all sustained notes
				pedalSustainNotes.keysValuesDo({ arg note, val; 
					fnNoteOff.(note);
					pedalSustainNotes.removeAt(note);
				});
			});
		});

		this.addCommand("moomin_sustenuto", "i", { arg msg;
			pedalSostenutoOn=(msg[1]==1);
			if (pedalSostenutoOn==false,{
				// release all sustained notes
				pedalSostenutoNotes.keysValuesDo({ arg note, val; 
					fnNoteOff.(note);
					pedalSostenutoNotes.removeAt(note);
				});
			},{
				// add currently held notes
				moominVoicesOn.keysValuesDo({ arg note, val;
					pedalSostenutoNotes.put(note,1);
				});
			});
		});

		this.addCommand("moomin_reverb","f",{ arg msg;
			moominParameters.put("reverb",msg[1]);
			moominSynthFX.set(\reverb,msg[1]);
		});
		this.addCommand("moomin_sub","f",{ arg msg;
			moominParameters.put("sub",msg[1]);
			moominVoices.keysValuesDo({ arg note, syn;
				syn.set(\sub,msg[1]);
			});
		});
		this.addCommand("moomin_attack","f",{ arg msg;
			moominParameters.put("attack",msg[1]);
			moominVoices.keysValuesDo({ arg note, syn;
				syn.set(\attack,msg[1]);
			});
		});
		this.addCommand("moomin_decay","f",{ arg msg;
			moominParameters.put("decay",msg[1]);
			moominVoices.keysValuesDo({ arg note, syn;
				syn.set(\decay,msg[1]);
			});
		});
		this.addCommand("moomin_sustain","f",{ arg msg;
			moominParameters.put("sustain",msg[1]);
			moominVoices.keysValuesDo({ arg note, syn;
				syn.set(\sustain,msg[1]);
			});
		});
		this.addCommand("moomin_release","f",{ arg msg;
			moominParameters.put("release",msg[1]);
			moominVoices.keysValuesDo({ arg note, syn;
				syn.set(\release,msg[1]);
			});
		});
		this.addCommand("moomin_portamento","f",{ arg msg;
			moominParameters.put("portamento",msg[1]);
			moominVoices.keysValuesDo({ arg note, syn;
				syn.set(\portamento,msg[1]);
			});
		});

		// </moomin>
	}

	free {
		// <moomin>
		moominBusFx.free;
		moominSynthFX.free;
		moominVoices.keysValuesDo({ arg key, value; value.free; });
		// </moomin>
	}
}