# synth1
fx unit/ambient generator, plays field recordings, degrades and granulates sound sources, does looping, configured to be controlled by an akai midimix, but could be adapted to any device with sufficient controls.

uses:
the absolutely stunning https://github.com/X2theL/CaesarLooper<br>
(for which in turn you need https://github.com/tremblap/IBufWr)<br>
some audio mangling tools from https://github.com/madskjeldgaard/portedplugins<br>
the stage limiter from https://github.com/supercollider-quarks/BatLib<br>
and some midi control from http://modalityteam.github.io/<br>

the current signal chain is:

audio input & buffer player --> granular compression and degradation --> looper & mixer --> out
