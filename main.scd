(
s.boot;
s.waitForBoot {(
	//INIT STUFF,BUSSES,SYNTHDEFS,VARS
	~inputBus = Bus.audio(s,2);
	~tapeBus = Bus.audio(s,2);
	~noiseBus = Bus.audio(s,2);
	~preMixerBus = Bus.audio(s,2);
	~postMixerBus = Bus.audio(s,2);

	~caesarInputBus = Bus.audio(s,2);
	~caesarOutputBus = Bus.audio(s,2);

	~currentLoop = 0;
	//array of loops in my home folder
	~arrayOfBuffers = "/home/patch/Documents/fields/*".pathMatch.sort.collect{|file| Buffer.read(s,file);};
	~numLoops = ~arrayOfBuffers.size;

	~cloud1Frozen = 0;
	~cloud2Frozen = 0;

    //synthdefs start here
	SynthDef.new(\input,{
		arg amp=0.8;
		var sig;
		sig=SoundIn.ar([0,0]*amp);
		//sig=SinOsc.ar([220.0,221.0]);//for testing purposes
		Out.ar(~inputBus,sig);
	}).add;

	SynthDef.new(\tape,{
		arg amp=0.8,rate=1,bufn;
		var sig,ptr;
		ptr=Phasor.ar(0,
			BufRateScale.kr(bufn)*rate,
			0,
			BufFrames.kr(bufn)
		);
		sig=BufRd.ar(2,bufn,ptr);
		Out.ar(~tapeBus,sig);
	}).add;

	/*SynthDef.new(\recorder,{
		arg amp=0.8,rate=1,bufn,gain=0;
		var sig,ptr;
		ptr=Phasor.ar(0,
			BufRateScale.kr(bufn)*rate,
			0,
			BufFrames.kr(bufn)
		);
		sig=IBufWr.ar(In.ar(~inputBus,2)*gain,bufn,ptr,1,1);
	}).add;

	SynthDef.new(\noise,{
	arg amount=0.1,amp=0.8,out;
	var sig,noise1,noise2,gaussian;
	noise1 = WhiteNoise.ar.abs*amount+(1-amount);
	noise2 = WhiteNoise.ar([2pi,2pi+0.001]);
	gaussian = sqrt(-2*log(noise1))*cos(noise2);
	sig = gaussian.dup*amp;
	Out.ar(~noiseBus,sig);
	}).add;*/

	SynthDef.new(\noise,{
		arg amount=0.1,amp=0.8;
		var pop,imp,modImp,midNoise,hiNoise,loNoise,loopTime=64,numChan=2,w,x,y;
		pop=TDuty.ar(Dseq({ 1.0.bilinrand.abs } ! loopTime,inf));
		pop=Resonz.ar(Decay.ar(pop,TRand.ar(0.001,0.1,pop)),Demand.ar(pop,0,Dseq({ 7000.bilinrand.abs+40 }!loopTime,inf)),
			mul:Demand.ar(pop,0,Dseq({ exprand(0.1,0.87) } ! loopTime,inf)));
		pop = LeakDC.ar(pop,TRand.ar(0.9,0.9995,pop))*0.2;
		#w,x,y = PanB2.ar(pop,Demand.ar(pop,0,Dseq({ 1.0.rand2 } ! loopTime,inf)));
		imp = { arg i; HPF.ar(LPF.ar(Dust2.ar(8),8000.0),6000.0,WhiteNoise.ar(0.7)) }!numChan;
		modImp = LPF.ar(Dust.ar(LFDNoise3.ar(1).exprange(100,500),LFDNoise3.ar(10).exprange(0.01,0.07)),9000.0)!numChan;
		midNoise = LPF.ar(GrayNoise.ar(LFDNoise3.ar(60))*WhiteNoise.ar(amount.linlin(0,1,0.0009,0.002)),12000.0)!numChan;
		hiNoise = HPF.ar(LPF.ar(GrayNoise.ar(LFDNoise3.ar(60))*WhiteNoise.ar(0.01),14000.0),8000.0)!numChan;
		loNoise = LPF.ar(BrownNoise.ar(PinkNoise.ar.range(0.001,0.02)),1200)!numChan;
		Out.ar(~noiseBus,DecodeB2.ar(numChan,w,x,y)+imp+modImp+midNoise+hiNoise+loNoise*amp);
	}).add;

	SynthDef.new(\preMixer,{
		arg inAmp=0,tapeAmp=0,cloud1Amp=0,cloud2Amp=0,noiseAmp=0,dryAmp=0,caesarAmp=0,
		lowpass=16384,highpass=16,
		cloud1Pitch=0,cloud1Pos=0.5,cloud1Size=0.25,cloud1Dens=0.4,cloud1Tex=0.5,cloud1Spread=0.5,cloud1Reverb=0,cloud1Feedback=0,
		t_cloud1Freeze=0,
		drop=0,outof=100,
		drive=0.5,shelf=600;
		var sig,cloud1,cloud2,premix,postmix;
		premix=Mix.ar([In.ar(~inputBus,2)*inAmp,In.ar(~tapeBus,2)*tapeAmp]);
		premix=LPF.ar(premix,lowpass);
		premix=HPF.ar(premix,highpass);
		premix=AnalogTape.ar(premix,0.2,0.2,0.2,2,2);
		cloud1=MiClouds.ar(premix,
			cloud1Pitch,cloud1Pos,cloud1Size,cloud1Dens,cloud1Tex,1,1,cloud1Spread,cloud1Reverb,cloud1Feedback,ToggleFF.kr(t_cloud1Freeze));
		sig=Mix.ar([premix*dryAmp,cloud1*cloud1Amp]);
		sig=WaveLoss.ar(sig,drop,outof,2);
		sig=AnalogVintageDistortion.ar(sig,drive,0,0.1,0.1,shelf,2);
		Out.ar(~caesarInputBus,sig);
		//sig=AnalogTape.ar(sig,0.5,drive,saturation,2,2);
		Out.ar(~preMixerBus,sig);
	}).add;

	SynthDef.new(\postMixer,{
		arg cloud2Amp=0,caesarAmp=0,noiseAmp=0,	cloud2Pitch=0,cloud2Pos=0.5,cloud2Size=0.25,cloud2Dens=0.4,cloud2Tex=0.5,cloud2Spread=0.5,cloud2Reverb=0,cloud2Feedback=0,
		t_cloud2Freeze=0;
		var sig,cloud2;
		sig=Mix.ar([In.ar(~preMixerBus,2),In.ar(~caesarOutputBus,2)*caesarAmp]);
		cloud2=MiClouds.ar(sig,
			cloud2Pitch,cloud2Pos,cloud2Size,cloud2Dens,cloud2Tex,1,1,cloud2Spread,cloud2Reverb,cloud2Feedback,ToggleFF.kr(t_cloud2Freeze));
		sig=Mix.ar([sig,cloud2*cloud2Amp,In.ar(~noiseBus,2)*noiseAmp]);
		Out.ar(~postMixerBus,sig);
	}).add;

	SynthDef.new(\output,{
		arg amp=0;
		var sig;
		sig=In.ar(~postMixerBus,2)*amp;
		//sig=SinOsc.ar([223.0,224.0])*amp;
		StageLimiter.activate;
		Out.ar(0,sig);
	}).add;
);
s.sync;
(
//CREATE GROUPS
~pointerGroup=Group.new;
~sourceGroup=Group.after(~pointerGroup);
~preMixerGroup=Group.after(~sourceGroup);
~recGroup=Group.after(~preMixerGroup);
~postMixerGroup=Group.after(~recGroup);
~outputGroup=Group.after(~mixerGroup);
);
(
//SYNTH CREATION
~inputSynth=Synth.new(\input,[\amp,0.8],~sourceGroup);
~noiseSynth=Synth.new(\noise,[\amp,0.8],~sourceGroup);
~tapeSynth=Synth.new(\tape,[\amp,0.8,\rate,1,\bufn,~arrayOfBuffers[~currentLoop].bufnum],~sourceGroup);
//~recorderSynth=Synth.new(\recorder,[\amp,0.8,\rate,1,\bufn,~arrayOfBuffers[~currentLoop].bufnum,\gain,0],~recGroup);
~caesar = CaesarLooper(~caesarInputBus,~caesarOutputBus,30,~recGroup);
~preMixerSynth=Synth.new(\preMixer,[
	\inAmp,0,\tapeAmp,0,\cloud1Amp,0,
	\lowpass,16384,\highpass,16,
	\cloud1Pitch,0,\cloud1Pos,0.5,\cloud1Size,0.25,\cloud1Dens,0.4,\cloud1Tex,0.5,\cloud1Spread,0.5,\cloud1Reverb,0,\cloud1Feedback,0,\cloud1Freeze,0,
	\drop,0,\outof,100,
	\drive,0.5,\shelf,0.5],~preMixerGroup);
~postMixerSynth=Synth.new(\postMixer,[
	\cloud2Amp,0,\noiseAmp,0,\caesarAmp,0,
	\cloud2Pitch,0,\cloud2Pos,0.5,\cloud2Size,0.25,\cloud2Dens,0.4,\cloud2Tex,0.5,\cloud2Spread,0.5,\cloud2Reverb,0,\cloud2Feedback,0,\cloud2Freeze,0],~postMixerGroup);
~outputSynth=Synth.new(\output,[\amp,0],~outputGroup);
);
s.sync;
(
//MIDI CONTROL
m = MKtl('mm',"akai-midimix");

//give all the midimix controls names
MKtl(\mm).addNamed(\knob1, MKtl(\mm).elAt(\kn,0,0));
MKtl(\mm).addNamed(\knob2, MKtl(\mm).elAt(\kn,0,1));
MKtl(\mm).addNamed(\knob3, MKtl(\mm).elAt(\kn,0,2));
MKtl(\mm).addNamed(\knob4, MKtl(\mm).elAt(\kn,0,3));
MKtl(\mm).addNamed(\knob5, MKtl(\mm).elAt(\kn,0,4));
MKtl(\mm).addNamed(\knob6, MKtl(\mm).elAt(\kn,0,5));
MKtl(\mm).addNamed(\knob7, MKtl(\mm).elAt(\kn,0,6));
MKtl(\mm).addNamed(\knob8, MKtl(\mm).elAt(\kn,0,7));
MKtl(\mm).addNamed(\knob9, MKtl(\mm).elAt(\kn,1,0));
MKtl(\mm).addNamed(\knob10, MKtl(\mm).elAt(\kn,1,1));
MKtl(\mm).addNamed(\knob11, MKtl(\mm).elAt(\kn,1,2));
MKtl(\mm).addNamed(\knob12, MKtl(\mm).elAt(\kn,1,3));
MKtl(\mm).addNamed(\knob13, MKtl(\mm).elAt(\kn,1,4));
MKtl(\mm).addNamed(\knob14, MKtl(\mm).elAt(\kn,1,5));
MKtl(\mm).addNamed(\knob15, MKtl(\mm).elAt(\kn,1,6));
MKtl(\mm).addNamed(\knob16, MKtl(\mm).elAt(\kn,1,7));
MKtl(\mm).addNamed(\knob17, MKtl(\mm).elAt(\kn,2,0));
MKtl(\mm).addNamed(\knob18, MKtl(\mm).elAt(\kn,2,1));
MKtl(\mm).addNamed(\knob19, MKtl(\mm).elAt(\kn,2,2));
MKtl(\mm).addNamed(\knob20, MKtl(\mm).elAt(\kn,2,3));
MKtl(\mm).addNamed(\knob21, MKtl(\mm).elAt(\kn,2,4));
MKtl(\mm).addNamed(\knob22, MKtl(\mm).elAt(\kn,2,5));
MKtl(\mm).addNamed(\knob23, MKtl(\mm).elAt(\kn,2,6));
MKtl(\mm).addNamed(\knob24, MKtl(\mm).elAt(\kn,2,7));

MKtl(\mm).addNamed(\button1, MKtl(\mm).elAt(\bt,0,0,0));
MKtl(\mm).addNamed(\button2, MKtl(\mm).elAt(\bt,0,1,0));
MKtl(\mm).addNamed(\button3, MKtl(\mm).elAt(\bt,0,2,0));
MKtl(\mm).addNamed(\button4, MKtl(\mm).elAt(\bt,0,3,0));
MKtl(\mm).addNamed(\button5, MKtl(\mm).elAt(\bt,0,4,0));
MKtl(\mm).addNamed(\button6, MKtl(\mm).elAt(\bt,0,5,0));
MKtl(\mm).addNamed(\button7, MKtl(\mm).elAt(\bt,0,6,0));
MKtl(\mm).addNamed(\button8, MKtl(\mm).elAt(\bt,0,7,0));
MKtl(\mm).addNamed(\button9, MKtl(\mm).elAt(\bt,1,0,0));
MKtl(\mm).addNamed(\button10, MKtl(\mm).elAt(\bt,1,1,0));
MKtl(\mm).addNamed(\button11, MKtl(\mm).elAt(\bt,1,2,0));
MKtl(\mm).addNamed(\button12, MKtl(\mm).elAt(\bt,1,3,0));
MKtl(\mm).addNamed(\button13, MKtl(\mm).elAt(\bt,1,4,0));
MKtl(\mm).addNamed(\button14, MKtl(\mm).elAt(\bt,1,5,0));
MKtl(\mm).addNamed(\button15, MKtl(\mm).elAt(\bt,1,6,0));
MKtl(\mm).addNamed(\button16, MKtl(\mm).elAt(\bt,1,7,0));

MKtl(\mm).addNamed(\slider1, MKtl(\mm).elAt(\sl,0));
MKtl(\mm).addNamed(\slider2, MKtl(\mm).elAt(\sl,1));
MKtl(\mm).addNamed(\slider3, MKtl(\mm).elAt(\sl,2));
MKtl(\mm).addNamed(\slider4, MKtl(\mm).elAt(\sl,3));
MKtl(\mm).addNamed(\slider5, MKtl(\mm).elAt(\sl,4));
MKtl(\mm).addNamed(\slider6, MKtl(\mm).elAt(\sl,5));
MKtl(\mm).addNamed(\slider7, MKtl(\mm).elAt(\sl,6));
MKtl(\mm).addNamed(\slider8, MKtl(\mm).elAt(\sl,7));
MKtl(\mm).addNamed(\slider9, MKtl(\mm).elAt(\sl,8));

/*this is a 6-bit binary "display" to have some feedback
when scrolling through the buffers on the disk*/
~showCurrentLoop = {
	var binArray;
	binArray = ~currentLoop.asBinaryDigits(6);
	MKtl(\mm).elAt(\bt,1,2,0).value_(binArray[0].linlin(0,1,0,127));
	MKtl(\mm).elAt(\bt,1,3,0).value_(binArray[1].linlin(0,1,0,127));
	MKtl(\mm).elAt(\bt,1,4,0).value_(binArray[2].linlin(0,1,0,127));
	MKtl(\mm).elAt(\bt,1,5,0).value_(binArray[3].linlin(0,1,0,127));
	MKtl(\mm).elAt(\bt,1,6,0).value_(binArray[4].linlin(0,1,0,127));
	MKtl(\mm).elAt(\bt,1,7,0).value_(binArray[5].linlin(0,1,0,127));
};

//define what the actions actually do
~controls = (
	actions: (
		//selecting tapes
		selectBefore: {
			MKtl(\mm).elAt(\bt,1,0,0).value_(127);
			~currentLoop = ~currentLoop-1%~numLoops;
			~showCurrentLoop.value;
			~tapeSynth.free;
			~tapeSynth=Synth.new(\tape,[\amp,0.8,\rate,1,\bufn,~arrayOfBuffers[~currentLoop].bufnum],~sourceGroup);
			MKtl(\mm).elAt(\bt,1,0,0).value_(0);
		},
		selectNext: {
			MKtl(\mm).elAt(\bt,1,1,0).value_(127);
			~currentLoop = ~currentLoop+1%~numLoops;
			~showCurrentLoop.value;
			~tapeSynth.free;
			~tapeSynth=Synth.new(\tape,[\amp,0.8,\rate,1,\bufn,~arrayOfBuffers[~currentLoop].bufnum],~sourceGroup);
			MKtl(\mm).elAt(\bt,1,1,0).value_(0);
		},
		//clouding
		cloud1Freeze: { |el|
			if(~cloud1Frozen==0,
				{ MKtl(\mm).elAt(\bt,0,0,0).value_(127);
					//"freeze".postln;
					~cloud1Frozen=1;
				}, { MKtl(\mm).elAt(\bt,0,0,0).value_(0);
					//"unfreeze".postln;
					~cloud1Frozen=0;
			});
			~mixerSynth.set(\t_cloud1Freeze, 1);
		},
		cloud2Freeze: { |el|
			if(~cloud2Frozen==0,
				{ MKtl(\mm).elAt(\bt,0,1,0).value_(127);
					//"freeze".postln;
					~cloud2Frozen=1;
				}, { MKtl(\mm).elAt(\bt,0,1,0).value_(0);
					//"unfreeze".postln;
					~cloud2Frozen=0;
			});
			~mixerSynth.set(\t_cloud2Freeze, 1);
		},
		tapLength: { ~caesar.tapLength;},
		record: { if (~caesar.inputLevel == 1,
			{ MKtl(\mm).elAt(\bt,0,4,0).value_(0);
				~caesar.inputLevel_(0);
			}, { MKtl(\mm).elAt(\bt,0,4,0).value_(127);
				~caesar.inputLevel_(1);
		});},
		clear: { ~caesar.clear;},
		reverse: { ~caesar.reverse;},
		freeze: { if (~caesar.isFrozen,
			{ MKtl(\mm).elAt(\bt,0,7,0).value_(0);
				~caesar.freeze;
			}, { MKtl(\mm).elAt(\bt,0,7,0).value_(127);
				~caesar.freeze;
		});},
		setCloud1Pitch: { |el| ~preMixerSynth.set(\cloud1Pitch, el.value.linlin(0,1,-24.0,24.0));},
		setCloud1Pos: { |el| ~preMixerSynth.set(\cloud1Pos, el.value);},
		setCloud1Size: { |el| ~preMixerSynth.set(\cloud1Size, el.value);},
		setCloud1Dens: { |el| ~preMixerSynth.set(\cloud1Dens, el.value);},
		setCloud1Tex: { |el| ~preMixerSynth.set(\cloud1Tex, el.value);},
		setCloud1Spread: { |el| ~preMixerSynth.set(\cloud1Spread, el.value);},
		setCloud1Reverb: { |el| ~preMixerSynth.set(\cloud1Reverb, el.value);},
		setCloud1Feedback: { |el| ~preMixerSynth.set(\cloud1Feedback, el.value);},
		setCloud2Pitch: { |el| ~postMixerSynth.set(\cloud2Pitch, el.value.linlin(0,1,-24.0,24.0));},
		setCloud2Pos: { |el| ~postMixerSynth.set(\cloud2Pos, el.value);},
		setCloud2Size: { |el| ~postMixerSynth.set(\cloud2Size, el.value);},
		setCloud2Dens: { |el| ~postMixerSynth.set(\cloud2Dens, el.value);},
		setCloud2Tex: { |el| ~postMixerSynth.set(\cloud2Tex, el.value);},
		setCloud2Spread: { |el| ~postMixerSynth.set(\cloud2Spread, el.value);},
		setCloud2Reverb: { |el| ~postMixerSynth.set(\cloud2Reverb, el.value);},
		setCloud2Feedback: { |el| ~postMixerSynth.set(\cloud2Feedback, el.value);},
		//other fx
		setTapeSpeed: { |el| ~tapeSynth.set(\rate, el.value.linlin(0,1,0.5,1.5));},
		//setRecLevel: { |el| ~recorderSynth.set(\gain, el.value);},
		setCaesarPitch: { |el| ~caesar.pitch_(el.value.linlin(0,1,-4,4));},
		setLowpass: { |el| ~preMixerSynth.set(\lowpass, el.value.linlin(0,1,32,16384));},
		setHighpass: { |el| ~preMixerSynth.set(\highpass, el.value.linlin(0,1,16,8192));},
		setDrop: { |el| ~preMixerSynth.set(\drop, el.value.linlin(0,1,0,90));},
		//setOutof: { |el| ~preMixerSynth.set(\outof, el.value.linlin(0,1,20,100));},
		setCaesarFeedback: { |el| ~caesar.masterFeedback_(el.value);},
		setDrive: { |el| ~preMixerSynth.set(\drive, el.value);},
		setShelf: { |el| ~preMixerSynth.set(\shelf, el.value);},
		//vols
		setInAmp: { |el| ~preMixerSynth.set(\inAmp,el.value);},
		setTapeAmp: { |el| ~preMixerSynth.set(\tapeAmp,el.value);},
		setDryAmp: { |el| ~preMixerSynth.set(\dryAmp,el.value);},
		setNoiseAmp: { |el| ~postMixerSynth.set(\noiseAmp,el.value);},
		setCaesarAmp: { |el| ~postMixerSynth.set(\caesarAmp,el.value);},
		setCloud1Amp: { |el| ~preMixerSynth.set(\cloud1Amp,el.value*1.5);},
		setCloud2Amp: { |el| ~postMixerSynth.set(\cloud2Amp,el.value*1.5);},
		setFinalAmp: { |el| ~outputSynth.set(\amp,el.value);}
	)
);

//sort out which control gets which action
~controls.put(
	\mm, (
		\ctlMap1: (
			\button1: \cloud1Freeze,
			\button2: \cloud2Freeze,
			\button4: \tapLength,
			\button5: \record,
			\button6: \clear,
			\button7: \reverse,
			\button8: \freeze,
			\button9: \selectBefore,
			\button10: \selectNext,
			//clouding
			\knob1: \setCloud1Pitch,
			\knob2: \setCloud1Pos,
			\knob3: \setCloud1Size,
			\knob4: \setCloud1Dens,
			\knob5: \setCloud1Tex,
			\knob6: \setCloud1Spread,
			\knob7: \setCloud1Reverb,
			\knob8: \setCloud1Feedback,
			\knob9: \setCloud2Pitch,
			\knob10: \setCloud2Pos,
			\knob11: \setCloud2Size,
			\knob12: \setCloud2Dens,
			\knob13: \setCloud2Tex,
			\knob14: \setCloud2Spread,
			\knob15: \setCloud2Reverb,
			\knob16: \setCloud2Feedback,
			//other fx
			\knob17: \setTapeSpeed,
			\knob18: \setCaesarPitch,
			\knob19: \setLowpass,
			\knob20: \setHighpass,
			\knob21: \setDrop,
			\knob22: \setCaesarFeedback,
			\knob23: \setDrive,
			\knob24: \setShelf,
			//buttons
			\slider1: \setInAmp,
			\slider2: \setTapeAmp,
			\slider3: \setDryAmp,
			\slider4: \setNoiseAmp,
			\slider5: \setCloud1Amp,
			\slider6: \setCloud2Amp,
			\slider7: \setCaesarAmp,
			\slider9: \setFinalAmp
		)
	)
);

~controls.mm.ctlMap1.keysValuesDo { |elName, actName|
	MKtl(\mm).elAt(elName).postln.action = ~controls.actions[actName.postln].postln;
};
//m.gui;
);
(
//LOOPER INIT
~caesar.delay_(7);
~caesar.dryLevel_(0);
~caesar.inputLevel_(1);
0.1.wait;
/*i don't know why yet, but caesarlooper seems to have a bug,
when i just set inputlevel to zero, so i set it to 1, wait
and then set it to zero, otherwise it would be recording
at startup*/
~caesar.inputLevel_(0);
~caesar.effectLevel_(1);
~caesar.masterFeedback_(0);
~caesar.clear;
);
}
)
