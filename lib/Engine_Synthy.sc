// Engine_Synthy
Engine_Synthy : CroneEngine {
	// <synthy>
	var synthyParameters;
	var synthyVoices;
	var synthyVoicesOn;
	var synthySynthFX;
	var synthyBusFx;
	var synthyOSFn;
	var fnNoteOn, fnNoteOff;
	var pedalSustainOn=false;
	var pedalSostenutoOn=false;
	var pedalSustainNotes;
	var pedalSostenutoNotes;
	// </synthy>


	*new { arg context, doneCallback;
		^super.new(context, doneCallback);
	}

	alloc {

		// <synthy>
		// initialize variables
		synthyParameters=Dictionary.with(*["sub"->1.0,"attack"->1.0,"decay"->0.2,"sustain"->0.9,"release"->5.0,"portamento"->1.0]);
		synthyVoices=Dictionary.new;
		synthyVoicesOn=Dictionary.new;
		pedalSustainNotes=Dictionary.new;
		pedalSostenutoNotes=Dictionary.new;

		// initialize synth defs
		SynthDef("synthyfx",{
			arg in, out, reverb=0.02, hold_control=5.0, t_trig=0.0, lpf=8000,flang=0;
			var snd,z,y,filterpos,filterswitch,flanger;
			snd = In.ar(in,2);
			// global filter
			filterswitch=EnvGen.kr(Env.new([0,1,1,0],[0.5,hold_control,4]),gate:t_trig);
			filterpos=SelectX.kr(filterswitch,[
				LinExp.kr(VarLag.kr(LFNoise0.kr(1/6),6,warp:\sine),-1,1,3200,8000),
				lpf
			]);
			
			// add flanger
			flanger = snd+LocalIn.ar(2); //add some feedback
			flanger= DelayN.ar(flanger,0.02,SinOsc.kr(0.1,0,0.005,0.005)); //max delay of 20msec
			LocalOut.ar(0.5*flanger);
			snd=SelectX.ar(flang,[snd,flanger]);

			SendTrig.kr(Impulse.kr(5),1,filterpos);
			snd=MoogLadder.ar(snd.tanh,filterpos);


			
			// reverb predelay time :
			z = DelayN.ar(snd, 0.048);
			// 7 length modulated comb delays in parallel :
			y = Mix.ar(Array.fill(7,{ CombL.ar(z, 0.1, LFNoise1.kr(0.1.rand, 0.04, 0.05), 15) }));
			// two parallel chains of 4 allpass delays (8 total) :
			4.do({ y = AllpassN.ar(y, 0.050, [0.050.rand, 0.050.rand], 1) });
			// add original sound to reverb and play it :
			snd=snd+(reverb*y);
			snd=HPF.ar(snd,20);

			SendTrig.kr(Impulse.kr(15),2,Lag.kr(Amplitude.kr(snd),2));
			Out.ar(out,snd);
		}).add;

		SynthDef("synthyosc",{
			arg out=0,hz=220,amp=0.5,gate=1,sub=0,portamento=1,
			attack=1.0,decay=0.2,sustain=0.9,release=5,
			perturb1=0,t_trig1=0,perturb2=0,t_trig2=0;
			var snd,note,env;
			var perturb1val,perturb2val;
			note=Lag.kr(hz,portamento).cpsmidi;
			perturb1val=VarLag.kr(EnvGen.kr(Env.perc(1/30,1/30,Latch.kr(perturb1,t_trig1)),t_trig1),0.1,warp:\sine);
			perturb2val=VarLag.kr(EnvGen.kr(Env.perc(1/30,1/30,Latch.kr(perturb2,t_trig2)),t_trig2),0.1,warp:\sine).abs;
			note=note+(note*perturb1val);
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
			env=env*Clip.ar(1+(perturb2val*LFPar.ar(perturb2val*10).range(-1,0)));
			Out.ar(out,snd*env);
		}).add;

		synthyOSFn = OSCFunc({ 
            arg msg, time; 
            // [time, msg].postln;
            NetAddr("127.0.0.1", 10111).sendMsg("synthy",msg[2],msg[3]);
        },'/tr', context.server.addr);

		// initialize fx synth and bus
		context.server.sync;
		synthyBusFx = Bus.audio(context.server,2);
		context.server.sync;
		synthySynthFX = Synth.new("synthyfx",[\out,0,\in,synthyBusFx,\reverb,synthyParameters.at("reverb")]);
		context.server.sync;

		// intialize helper functions
		fnNoteOn= {
			arg note,amp;
			var lowestNote=10000;
			var sub=0;
			("synthy_note_on "++note).postln;
			// low-note priority for sub oscillator
			synthyVoicesOn.keysValuesDo({ arg key, syn;
				if (key<lowestNote,{
					lowestNote=key;
				});
			});
			if (lowestNote<10000,{
				if (note<lowestNote,{
					sub=1;
					synthyVoices.at(lowestNote).set(\sub,0);
				},{
					sub=0;
				});
			},{
				sub=1;
			});

			("sub = "++sub).postln;
			synthyVoices.put(note,
				Synth.before(synthySynthFX,"synthyosc",[
					\amp,amp,
					\out,synthyBusFx,
					\hz,note.midicps,
					\sub,sub*synthyParameters.at("sub"),
					\attack,synthyParameters.at("attack"),
					\decay,synthyParameters.at("decay"),
					\sustain,synthyParameters.at("sustain"),
					\release,synthyParameters.at("release"),
					\portamento,synthyParameters.at("portamento"),
				]);
			);
			synthyVoicesOn.put(note,1);
			NodeWatcher.register(synthyVoices.at(note));
		};
		
		fnNoteOff = {
			arg note;
			var lowestNote=10000;
			("synthy_note_off "++note).postln;

			synthyVoicesOn.removeAt(note);

			if (pedalSustainOn==true,{
				pedalSustainNotes.put(note,1);
			},{
				if ((pedalSostenutoOn==true)&&(pedalSostenutoNotes.at(note)!=nil),{
					// do nothing, it is a sostenuto note
				},{
					// remove the sound
					synthyVoices.at(note).set(\gate,0);
					// swap sub
					synthyVoicesOn.keysValuesDo({ arg key, syn;
						if (key<lowestNote,{
							lowestNote=key;
						});
					});
					if (lowestNote<10000,{
						("swapping sub to "++lowestNote).postln;
						synthyVoices.at(note).set(\sub,0);
						synthyVoices.at(lowestNote).set(\sub,synthyParameters.at("sub"));
					});
				});
			});


		};



		// add norns commands
		this.addCommand("synthy_note_on", "if", { arg msg;
			var lowestNote=10000;
			var note=msg[1];
			if (synthyVoices.at(note)!=nil,{
				if (synthyVoices.at(note).isRunning==true,{
					("synthy_note_on retrigger "++note).postln;
					synthyVoices.at(note).set(\hz,msg[1].midicps,\amp,msg[2],\gate,0);
					synthyVoices.at(note).set(\gate,1);
					synthyVoicesOn.keysValuesDo({ arg key, syn;
						if (key<lowestNote,{
							lowestNote=key;
						});
					});
					if (note<lowestNote,{
						("swapping sub to "++note).postln;
						synthyVoices.at(lowestNote).set(\sub,0);
						synthyVoices.at(note).set(\sub,synthyParameters.at("sub"));
					});
					synthyVoicesOn.put(note,1);
				},{ fnNoteOn.(msg[1],msg[2]); });
			},{  fnNoteOn.(msg[1],msg[2]); });
		});	

		this.addCommand("synthy_note_off", "i", { arg msg;
			var note=msg[1];
			if (synthyVoices.at(note)!=nil,{
				if (synthyVoices.at(note).isRunning==true,{
					fnNoteOff.(note);
				});
			});
		});

		this.addCommand("synthy_sustain", "i", { arg msg;
			pedalSustainOn=(msg[1]==1);
			if (pedalSustainOn==false,{
				// release all sustained notes
				pedalSustainNotes.keysValuesDo({ arg note, val; 
					fnNoteOff.(note);
					pedalSustainNotes.removeAt(note);
				});
			});
		});

		this.addCommand("synthy_sustenuto", "i", { arg msg;
			pedalSostenutoOn=(msg[1]==1);
			if (pedalSostenutoOn==false,{
				// release all sustained notes
				pedalSostenutoNotes.keysValuesDo({ arg note, val; 
					fnNoteOff.(note);
					pedalSostenutoNotes.removeAt(note);
				});
			},{
				// add currently held notes
				synthyVoicesOn.keysValuesDo({ arg note, val;
					pedalSostenutoNotes.put(note,1);
				});
			});
		});

		this.addCommand("synthy_sub","f",{ arg msg;
			synthyParameters.put("sub",msg[1]);
		});
		this.addCommand("synthy_attack","f",{ arg msg;
			synthyParameters.put("attack",msg[1]);
			synthyVoices.keysValuesDo({ arg note, syn;
				if (syn.isRunning==true,{
					syn.set(\attack,msg[1]);
				});
			});
		});
		this.addCommand("synthy_decay","f",{ arg msg;
			synthyParameters.put("decay",msg[1]);
			synthyVoices.keysValuesDo({ arg note, syn;
				if (syn.isRunning==true,{
					syn.set(\decay,msg[1]);
				});
			});
		});
		this.addCommand("synthy_sustain","f",{ arg msg;
			synthyParameters.put("sustain",msg[1]);
			synthyVoices.keysValuesDo({ arg note, syn;
				if (syn.isRunning==true,{
					syn.set(\sustain,msg[1]);
				});
			});
		});
		this.addCommand("synthy_release","f",{ arg msg;
			synthyParameters.put("release",msg[1]);
			synthyVoices.keysValuesDo({ arg note, syn;
				if (syn.isRunning==true,{
					syn.set(\release,msg[1]);
				});
			});
		});
		this.addCommand("synthy_portamento","f",{ arg msg;
			synthyParameters.put("portamento",msg[1]);
			synthyVoices.keysValuesDo({ arg note, syn;
				if (syn.isRunning==true,{
					syn.set(\portamento,msg[1]);
				});
			});
		});
		this.addCommand("synthy_perturb1","f",{ arg msg;
			synthyVoices.keysValuesDo({ arg note, syn;
				if (syn.isRunning==true,{
					syn.set(\perturb1,msg[1],\t_trig1,1);
				});
			});
		});
		this.addCommand("synthy_perturb2","f",{ arg msg;
			synthyVoices.keysValuesDo({ arg note, syn;
				if (syn.isRunning==true,{
					syn.set(\perturb2,msg[1],\t_trig2,1);
				});
			});
		});
		this.addCommand("synthy_hold_control","f",{ arg msg;
			synthySynthFX.set(\hold_control,msg[1]);
		});
		this.addCommand("synthy_lpf","f",{ arg msg;
			synthySynthFX.set(\lpf,msg[1],\t_trig,1);
		});
		this.addCommand("synthy_reverb","f",{ arg msg;
			synthySynthFX.set(\reverb,msg[1]);
		});
		this.addCommand("synthy_flanger","f",{ arg msg;
			synthySynthFX.set(\flang,msg[1]);
		});
	

		// </synthy>
	}

	free {
		// <synthy>
		synthyBusFx.free;
		synthySynthFX.free;
		synthyVoices.keysValuesDo({ arg key, value; value.free; });
		// </synthy>
	}
}
