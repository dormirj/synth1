# synth1
fx unit/ambient generator, plays field recordings, degrades and granulates sound sources, does looping, configured to be controlled by an akai midimix, but could be adapted to any device with sufficient controls.

uses:
the clouds implementation from https://github.com/v7b1/mi-UGens<br>
the absolutely stunning https://github.com/X2theL/CaesarLooper<br>
(for which in turn you need https://github.com/tremblap/IBufWr)<br>
some audio mangling tools from https://github.com/madskjeldgaard/mkplugins<br>
the stage limiter from https://github.com/supercollider-quarks/BatLib<br>
and some midi control from http://modalityteam.github.io/<br>

the signal chain is:

audio input&buffer player  -->  preMixer with fx --> looper --> postMixer with other fx --> output
