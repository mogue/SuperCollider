
// Modified from:
// https://github.com/maszkowicz/SuperCollider/blob/master/5_simple_MIDI_input.scd

(
~sus_gate = 0.0;
SynthDef(\bass, { | out=0 gate=1 sus_gate=0 freq amp=0.1 |
	var aEnv, fEnv, osc, flt;
	aEnv = EnvGen.kr(Env.adsr(0, 0.2, 1, 0.3), (gate | sus_gate), doneAction: 2);
	fEnv = EnvGen.kr(Env.adsr(0.05, 0.05, 1, 0.3), gate, levelScale: freq*4);
	osc = Mix([Saw.ar(freq * [1, 1.005]), Pulse.ar(freq, 0.25)]);
	flt = LPF.ar(osc, fEnv + (freq), aEnv);
	Out.ar(out, flt*amp);
}).add;

MIDIClient.init;
MIDIIn.connectAll;

// Create Aray of notes
~notes = Array.newClear(128);
~sustain_fn = {
	arg val;

	// Sustain ON
	if (val == 127, {
		~sus_gate = 1.0;
		~notes.do({
			arg item;
			(item.notNil && item.isPlaying).if({
				item.get(\gate, {
					arg gate;
					item.set(\sus_gate, gate);
				});
			});
		});
	});

	// Sustain OFF
	if (val == 0, {
		~sus_gate = 0.0;
		~notes.do({
			arg item;
			(item.notNil && item.isPlaying).if({
				item.set(\sus_gate, ~sus_gate);
			});
		});
	});
};


~midi_control_fn = {
	arg val, ccNum, chan, src;
//	[ ccNum, val ].postln;

	// Sustain Pedal (64)
	if (ccNum == 64,{
		~sustain_fn.value(val);
	});
};

~midi_noteOn_fn = {
	arg vel, nn, chan, src;
//	[vel, nn].postln;
	( ~notes[nn].notNil && ~notes[nn].isPlaying ).if({
		~notes[nn].set(\amp,  vel / 127.0);
		~notes[nn].set(\gate, 1);
	}, {
		s.makeBundle(nil, {
			~notes[nn] = Synth.new(
				\bass,
				[
					\freq, nn.midicps,
					\amp, vel / 127.0,
					\gate, 1,
					\sus_gate, ~sus_gate,
					\out, 0
				]
			);
			NodeWatcher.register(~notes[nn]);
		});
	});
};

~midi_noteOff_fn = {
	arg vel, nn;
	~notes[nn].set(\gate,0);
};

MIDIdef.cc(\control, ~midi_control_fn);
MIDIdef.noteOn(\noteOn, ~midi_noteOn_fn);
MIDIdef.noteOff(\noteOff, ~midi_noteOff_fn);
)

MIDIdef.freeAll;