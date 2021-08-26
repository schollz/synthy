// Engine_Velvet
Engine_Velvet : CroneEngine {
	var velvetParameters;
	var velvetVoices;
	var velvetVoicesOn;
	var velvetSynthFX;
	var velvetBusFx;
	var fnAddVoice;

	*new { arg context, doneCallback;
		^super.new(context, doneCallback);
	}



	alloc {

		// <velvet>
		velvetParameters=Dictionary.with(*["reverbLevel"->0.05,"sub"->1.0]);
		velvetVoices=Dictionary.new;
		velvetVoicesOn=Dictionary.new;

		SynthDef("velvetfx",{
			arg in, out, reverbLevel=0.02;
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
			snd=snd+(reverbLevel*y);
			snd=HPF.ar(snd,20);
			Out.ar(out,snd);
		}).add;

		SynthDef("velvetosc",{
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

		context.server.sync;
		velvetBusFx = Bus.audio(context.server,2);
		context.server.sync;
		velvetSynthFX = Synth.new("velvetfx",[\out,0,\in,velvetBusFx]);
		context.server.sync;

		fnAddVoice= {
			arg note;
			var lowestNote=10000;
			var sub=0;
			("velvet_note_on "++note).postln;
			// low-note priority for sub oscillator
			velvetVoicesOn.keysValuesDo({ arg key, syn;
				if (key<lowestNote,{
					lowestNote=key;
				});
			});
			if (lowestNote<10000,{
				if (note<lowestNote,{
					sub=velvetParameters.at("sub");
					velvetVoices.at(lowestNote).set(\sub,0);
				},{
					sub=0;
				});
			},{
				sub=velvetParameters.at("sub");
			});

			("sub = "++sub).postln;
			velvetVoices.put(note,
				Synth.before(velvetSynthFX,"velvetosc",[
					\out,velvetBusFx,
					\hz,note.midicps,
					\sub,sub,
				]);
			);
			velvetVoicesOn.put(note,1);
			NodeWatcher.register(velvetVoices.at(note));
		};
		
		this.addCommand("velvet_note_on", "i", { arg msg;
			var lowestNote=10000;
			var note=msg[1];
			if (velvetVoices.at(note)!=nil,{
				if (velvetVoices.at(note).isRunning==true,{
					("velvet_note_on retrigger "++note).postln;
					velvetVoices.at(note).set(\hz,msg[1].midicps,\gate,0);
					velvetVoices.at(note).set(\gate,1);
					velvetVoicesOn.keysValuesDo({ arg key, syn;
						if (key<lowestNote,{
							lowestNote=key;
						});
					});
					if (note<lowestNote,{
						("swapping sub to "++note).postln;
						velvetVoices.at(lowestNote).set(\sub,0);
						velvetVoices.at(note).set(\sub,velvetParameters.at("sub"));
					});
					velvetVoicesOn.put(note,1);
				},{ fnAddVoice.(msg[1]); });
			},{  fnAddVoice.(msg[1]); });
		});	

		this.addCommand("velvet_note_off", "i", { arg msg;
			var lowestNote=10000;
			var note=msg[1];
			if (velvetVoices.at(note)!=nil,{
				if (velvetVoices.at(note).isRunning==true,{
					("velvet_note_off "++note).postln;
					velvetVoicesOn.removeAt(note);
					velvetVoices.at(note).set(\gate,0);
					// swap sub
					velvetVoicesOn.keysValuesDo({ arg key, syn;
						if (key<lowestNote,{
							lowestNote=key;
						});
					});
					if (lowestNote<10000,{
						("swapping sub to "++lowestNote).postln;
						velvetVoices.at(note).set(\sub,0);
						velvetVoices.at(lowestNote).set(\sub,velvetParameters.at("sub"));
					});
					// done swap sub
				});
			});
		});

		// </velvet>
	}

	free {
		velvetBusFx.free;
		velvetSynthFX.free;
		velvetVoices.keysValuesDo({ arg key, value; value.free; });
	}
}
