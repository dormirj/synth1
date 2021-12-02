(
s.waitForBoot{(
	(
		~tapeBus = Bus.audio(s, 2);
		~inputBus = Bus.audio(s, 2);
		~mixerBus = Bus.audio(s, 2);
		~caesarBus = Bus.audio(s, 2);

		// my rpi is a bit slow, so have a little patience
		30.wait;
		// array of loops created by superclean
		~arrayOfBuffers = ~clean.buffers[\fields];
		~currentLoop = 0;
		~firstLoop = ~clean.buffers[\fields][0].bufnum;
		~numLoops = ~arrayOfBuffers.size;
	);

	(
		/* i had some trouble with caesarlooper and the
		order of execution, so i added all things into groups*/
		~sourceGroup = Group.new;
		~analysisGroup = Group.after(~sourceGroup);
		~grainGroup = Group.after(~sourceGroup);
		~caesarGroup = Group.after(~grainGroup);
		~mixerGroup = Group.after(~caesarGroup);
	);

	s.sync;

	(
		Ndef(\input, {
			var amp, sig;
			amp = \amp.kr(0.8, 0.01);
			sig = SoundIn.ar([0,1]);
			sig * amp;
		}).play(~inputBus, 2, ~sourceGroup)
	);

	(
		Ndef(\tape).addSpec(
			\amp, [0, 1],
			\bufn, [~firstLoop, ~firstLoop + ~numLoops],
			\rate, [0.125, 8],
			\start, [0.0, 1],
			\end, [0.0, 1],
			\lpf, [20, 22050],
			\hpf, [10, 20050],
			\pitch2, [0.125, 8],
			\pitch2amp, [0, 1],
			\pitch3, [0.125, 8],
			\pitch3amp, [0, 1],
			\pitch4, [0.125, 8],
			\pitch4amp, [0, 1],
		)
	);

	s.sync;

	(
		Ndef(\tape, {
			var amp, bufn, rate, sig, ptr, bufFrames, start, end, lpf, hpf, mix,
			sig2, sig3, sig4, ptr2, ptr3, ptr4, pitch2, pitch2amp, pitch3, pitch3amp, pitch4, pitch4amp;

			amp = \amp.kr(0.8, 0.01);
			rate = \rate.kr(1, 0.2);
			bufn = \bufn.kr(~firstLoop, 0).round;
			bufFrames = BufFrames.kr(bufn);
			start = 0 + \start.kr(0, 0.1) * bufFrames;
			end = \end.kr(1, 0.1) * bufFrames;
			lpf = \lpf.kr(22050, 0.2);
			hpf = \hpf.kr(10, 0.2);

			/* this might not be the most beautiful solution,
			but it works for what i wanted to do, being able
			to play looped samples with variable playback
			speed as sort of "chords"*/
			pitch2 = \pitch2.kr(1, 0.1);
			pitch2amp = \pitch2amp.kr(0, 0.01);
			pitch3 = \pitch3.kr(1, 0.1);
			pitch3amp = \pitch3amp.kr(0, 0.01);
			pitch4 = \pitch4.kr(1, 0.1);
			pitch4amp = \pitch4amp.kr(0, 0.01);

			ptr = Phasor.ar(
				0,
				rate,
				start,
				end
			);

			sig = BufRd.ar(
				2,
				bufn,
				ptr
			);

			ptr2 = Phasor.ar(
				0,
				pitch2,
				start,
				end
			);

			sig2 = BufRd.ar(
				2,
				bufn,
				ptr2
			);

			ptr3 = Phasor.ar(
				0,
				pitch3,
				start,
				end
			);

			sig3 = BufRd.ar(
				2,
				bufn,
				ptr3
			);

			ptr4 = Phasor.ar(
				0,
				pitch4,
				start,
				end
			);

			sig4 = BufRd.ar(
				2,
				bufn,
				ptr4
			);

			mix = Mix.ar([sig, sig2 * pitch2amp, sig3 * pitch3amp, sig4 * pitch4amp]);
			mix = HPF.ar(mix, hpf);
			mix = LPF.ar(mix, lpf);

			mix * amp;
		}).play(~tapeBus, 2, ~sourceGroup);

		// Ndef(\tape).edit
	);

	(
		Ndef(\analysis).addSpec(
			\attack, [0.001, 0.3],
			\release, [0.001, 0.3],
			\threshold, [-100.0, -30.0],
			\hpf, [10, 1000],
			\knee, [0.9, 1.1],
		)
	);

	s.sync;

	(
		Ndef(\analysis, {
			var input, in, e, thresh, c, attack, release, kneelag;
			input = In.ar(~tapeBus, 2);

			attack = \attack.kr(0.01);
			release = \release.kr(0.1);
			thresh = \threshold.kr(-6);
			in = input * \trim.kr(0).dbamp;

			e = in.mean;

			e = HPF.ar( e, \hpf.kr(50) );

			e = EnvDetect.ar(e, attack, release);

			// how much we are over by
			o = e.ampdb.excess(thresh);

			// scale the excess value by ratio
			r = \ratio.kr(4);
			c = ( max(o, 0.0) ) * (r.reciprocal - 1);

			kneelag = attack * \knee.kr(0.0);

			c = c.lag( kneelag );
			c = c.dbamp;

		});

		Ndef('analysis').set('threshold', -58.6, 'release', 0.05, 'knee', 1.01);
		// Ndef(\analysis).edit;

	);

	(
		Ndef(\granular_comp).addSpec(
			\lookahead, [0.0,1],
			\saturate, \switch,
			\lpf, [0.0, 0.2],
			\inAmp, [0.0, 1],
			\tapeAmp, [0.0, 1],
			\wet, [0.0, 1],
			\lookahead, [0.0,4100],
			\rate, [0,1],
			\tFreq, [1, 22050, \exp],
			\overlap, [0.01, 512.0, \exp],
			\hpf, \freq,
			\wet, [0.0,1],
			\dry, [0.0,1],
			\gain, [0.0,40],
			\drop, [0, 90],
		)
	);
	s.sync;
	(
		Ndef(\granular_comp, {
			arg	inAmp = 0, tapeAmp = 1, gain = 0, lookahead = 0, tFreq = 20, overlap = 2, rate = 1, lpf = 0, drop = 0;

			var input, readPos, signal, writePos, grained, balance, t, bufFrames, buf, bufdur, sc;

			bufFrames = 2**16;
			buf = {LocalBuf(bufFrames).clear}!2;
			bufdur = BufDur.ir(buf);

			writePos = Phasor.ar(
				0,
				rate,
				0,
				bufFrames
			);

			input = Mix.ar([In.ar(~inputBus, 2) * inAmp, In.ar(~tapeBus, 2) * tapeAmp]);
			input = WaveLoss.ar(input, drop, 100, 2);
			// writing input to grain buffer
			buf.do {
				arg b, i;
				BufWr.ar( input[i], b, writePos)
			};

			t = Impulse.ar(tFreq);

			readPos = Wrap.ar(
				writePos - 64 - lookahead / bufFrames,
				0,
				1
			);

			sc = Ndef(\analysis).ar;

			// maybe change this to stereo at some point
			grained = GrainBufJ.ar(
				numChannels:1,
				loop: 1,
				trigger:t,
				// dur: overlap / tFreq,
				dur: sc * overlap / tFreq,
				sndbuf: buf,
				rate: rate - lpf,
				pos:readPos,
				interp: 4,
				// grainAmp: sc,
				pan: 0,
				envbufnum:-1
			);

			grained = HPF.ar( grained, \hpf.kr(40) );

			signal = Mix([
				LeakDC.ar( grained ) * \wet.kr(0),
				DelayC.ar(
					input,
					0.5,
					(64 + lookahead / SampleRate.ir )
				) * \dry.kr(1)
			]) * gain.dbamp;

			signal.tanh

		}).play(~mixerBus, 2, ~grainGroup);

		// Ndef(\granular_comp).edit

	);

	s.sync;

	(
		{
			// caesar needs a bit of patience
			~caesar = CaesarLooper(~mixerBus, ~caesarBus, 16, ~caesarGroup);
			9.wait;
			~caesar.inputLevel_(0);
			1.wait;
			~caesar.dryLevel_(0);
			1.wait;
			~caesar.delay_(16);
			1.wait;
			~caesar.effectLevel_(1);
			1.wait;
			~caesar.masterFeedback_(0);
			5.wait;
			~caesar.clear;
		}.fork;
	);

	s.sync;

	(
		Ndef(\mixer).addSpec(
			\finalAmp, [0.0, 1],
			\caesarAmp, [0.0, 1],
		)
	);

	s.sync;

	(

		Ndef(\mixer, {
			arg finalAmp = 0.5, caesarAmp = 0.0;
			var sig;

			sig = Mix.ar([In.ar(~mixerBus, 2), In.ar(~caesarBus, 2) * caesarAmp]);

			sig * finalAmp;
		}).play(0, 2, ~mixerGroup);

		// Ndef(\mixer).edit

	);

	s.sync;
	// just in case, this might get loud
	StageLimiter.activate;

	(
		// midi control things
		m = MKtl('mm',"akai-midimix");
		// m = MKtl('mm',"akai-hermod");

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

		MKtl(\mm).addNamed(\bankleft, MKtl(\mm).elAt(\bankLeft,0));
		MKtl(\mm).addNamed(\bankright, MKtl(\mm).elAt(\bankRight,0));

		/* this is a 5-bit binary "display" to have some feedback
		when scrolling through the buffers on the disk */
		~showCurrentLoop = {
			var binArray;
			binArray = ~currentLoop.asBinaryDigits(6).reverse;
			MKtl(\mm).elAt(\bt,1,2,0).value_(binArray[0].linlin(0,1,0,127));
			MKtl(\mm).elAt(\bt,1,3,0).value_(binArray[1].linlin(0,1,0,127));
			MKtl(\mm).elAt(\bt,1,4,0).value_(binArray[2].linlin(0,1,0,127));
			MKtl(\mm).elAt(\bt,1,5,0).value_(binArray[3].linlin(0,1,0,127));
			MKtl(\mm).elAt(\bt,1,6,0).value_(binArray[4].linlin(0,1,0,127));
		};

		// define what the actions actually do
		~controls = (
			actions: (
				//buttons
				selectBefore: {
					MKtl(\mm).elAt(\bt,1,0,0).value_(127);
					~currentLoop = ~currentLoop-1%~numLoops;
					~showCurrentLoop.value;
					Ndef(\tape).set(\bufn, ~currentLoop + ~firstLoop);
					MKtl(\mm).elAt(\bt,1,0,0).value_(0);
				},
				selectNext: {
					MKtl(\mm).elAt(\bt,1,1,0).value_(127);
					~currentLoop = ~currentLoop+1%~numLoops;
					~showCurrentLoop.value;
					Ndef(\tape).set(\bufn, ~currentLoop + ~firstLoop);
					MKtl(\mm).elAt(\bt,1,1,0).value_(0);
				},
				tapLength: { ~caesar.tapLength;},
				record: { if (~caesar.inputLevel == 1,
					{ MKtl(\mm).elAt(\bt,0,5,0).value_(0);
						~caesar.inputLevel_(0);
					}, { MKtl(\mm).elAt(\bt,0,5,0).value_(127);
						~caesar.inputLevel_(1);
				});},
				reverse: { ~caesar.reverse;},
				freeze: { if (~caesar.isFrozen,
					{ MKtl(\mm).elAt(\bt,0,7,0).value_(0);
						~caesar.freeze;
					}, { MKtl(\mm).elAt(\bt,0,7,0).value_(127);
						~caesar.freeze;
				});},
				// beware: adding readheads may make a feedback mess, use with caution
				// addReadHead: { if(~caesar.reads[7]==nil,{~caesar.addRead(~nextReadDiv,~nextReadLevel,rrand(-0.05,0.05));},{"too many read heads".postln;});},
				// removeReadHead: { if(~caesar.reads[1]==nil,{"don't want to remove the main read head".postln;},{~caesar.removeRead;});},

				// tapestuff
				setTapeSpeed: { |el| Ndef(\tape).set(\rate, el.value.linexp(0, 1, 0.125, 8)); },
				setTapeStart: { |el| Ndef(\tape).set(\start, el.value); },
				setTapeEnd: { |el| Ndef(\tape).set(\end, el.value); },
				setTapeLowpass: { |el| Ndef(\tape).set(\lpf, el.value.linlin(0, 1, 20, 22050)); },
				setTapeHighpass: { |el| Ndef(\tape).set(\hpf, el.value.linlin(0, 1, 10, 20050)); },
				setDrop: { |el| Ndef(\granular_comp).set(\drop, el.value.linlin(0, 1, 0, 90)); },

				// analysis & grancomp
				setAnalysisHighpass: { |el| Ndef(\analysis).set(\hpf, el.value.linexp(0, 1, 10, 1000)); },
				setAnalysisAttack: { |el| Ndef(\analysis).set(\attack, el.value.linlin(0, 1, 0.001, 0.2)); },
				setAnalysisRelease: { |el| Ndef(\analysis).set(\release, el.value.linlin(0, 1, 0.001, 0.3)); },
				setAnalysisThreshold: { |el| Ndef(\analysis).set(\threshold, el.value.linlin(0, 1, -100.0, -30.0)); },
				setAnalysisKnee: { |el| Ndef(\analysis).set(\knee, el.value.linlin(0, 1, 0.9, 1.1)); },

				setGranLookahead: { |el| Ndef(\granular_comp).set(\lookahead, el.value.linlin(0, 1, 0, 4100)); },
				setGranLowpass: { |el| Ndef(\granular_comp).set(\lpf, el.value.linlin(0, 1, 0.0, 0.2)); },
				setGranHighpass: { |el| Ndef(\granular_comp).set(\hpf, el.value.linexp(0, 1, 10, 22050)); },
				setGranGain: { |el| Ndef(\granular_comp).set(\gain, el.value.linlin(0, 1, 0.0, 40.0)); },
				setGranRate: { |el| Ndef(\granular_comp).set(\rate, el.value); },
				setGranTFreq: { |el| Ndef(\granular_comp).set(\tFreq, el.value.linexp(0, 1, 1, 22050)); },
				setGranOverlap: { |el| Ndef(\granular_comp).set(\overlap, el.value.linexp(0, 1, 0.01, 512.0)); },
				setAnalysisRatio: { |el| Ndef(\analysis).set(\ratio, el.value.linlin(0, 1, 1.0, 4.0)); },

				//caesarstuff
				setCaesarPitch: { |el| ~caesar.pitch_(el.value.linlin(0,1,-4,4));},
				setCaesarFeedback: { |el| ~caesar.masterFeedback_(el.value);},

				// chord action
				setPitch2: { |el| Ndef(\tape).set(\pitch2, el.value.linexp(0, 1, 0.125, 8)); },
				setPitch2Amp: { |el| Ndef(\tape).set(\pitch2amp, el.value); },
				setPitch3: { |el| Ndef(\tape).set(\pitch3, el.value.linexp(0, 1, 0.125, 8)); },
				setPitch3Amp: { |el| Ndef(\tape).set(\pitch3amp, el.value); },
				setPitch4: { |el| Ndef(\tape).set(\pitch4, el.value.linexp(0, 1, 0.125, 8)); },
				setPitch4Amp: { |el| Ndef(\tape).set(\pitch4amp, el.value); },

				// vols
				setInAmp: { |el| Ndef(\granular_comp).set(\inAmp, el.value); },
				setTapeAmp: { |el| Ndef(\granular_comp).set(\tapeAmp, el.value); },
				setDryAmp: { |el| Ndef(\granular_comp).set(\dry, el.value); },
				setGrainAmp: { |el| Ndef(\granular_comp).set(\wet, el.value); },
				setCaesarAmp: { |el| Ndef(\mixer).set(\caesarAmp, el.value); },
				setFinalAmp: { |el| Ndef(\mixer).set(\finalAmp, el.value); },
			)
		);

		// sort out which control gets which action
		~controls.put(
			\mm, (
				\ctlMap1: (
					// button1-4 TODO
					\button5: \tapLength,
					\button6: \record,
					\button7: \reverse,
					\button8: \freeze,
					\button9: \selectBefore,
					\button10: \selectNext,

					// tapestuff
					\knob1: \setTapeSpeed,
					\knob2: \setTapeStart,
					\knob3: \setTapeEnd,

					// analysis & granular
					\knob4: \setAnalysisHighpass,
					\knob5: \setAnalysisAttack,
					\knob6: \setAnalysisRelease,
					\knob7: \setAnalysisThreshold,
					\knob8: \setAnalysisKnee,
					\knob9: \setGranLookahead,
					\knob10: \setGranLowpass,
					\knob11: \setGranHighpass,
					\knob12: \setGranGain,
					\knob13: \setGranRate,
					\knob14: \setGranTFreq,
					\knob15: \setGranOverlap,
					\knob16: \setAnalysisRatio,

					// again some tapestuff
					\knob17: \setTapeLowpass,
					\knob18: \setTapeHighpass,

					// caesarstuff
					\knob19: \setCaesarPitch,
					\knob20: \setCaesarFeedback,

					// the waveloss
					\knob21: \setDrop,

					// chordstuff
					\knob22: \setPitch2,
					\knob23: \setPitch3,
					\knob24: \setPitch4,

					// volumes
					\slider1: \setInAmp,
					\slider2: \setTapeAmp,
					\slider3: \setDryAmp,
					\slider4: \setGrainAmp,
					\slider5: \setCaesarAmp,
					\slider6: \setPitch2Amp,
					\slider7: \setPitch3Amp,
					\slider8: \setPitch4Amp,
					\slider9: \setFinalAmp
				)
			)
		);

		~controls.mm.ctlMap1.keysValuesDo { |elName, actName|
			MKtl(\mm).elAt(elName).postln.action = ~controls.actions[actName.postln].postln;
		};
		// m.gui;
	);
);
}
)
