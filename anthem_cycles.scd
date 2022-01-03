/* Title: Anthem Cycles
 * Composer: Andrew Davis
 * Year: 2021
 *
 * Instructions: The piece is performed through live execution of
 * various patterns.  The operator (i.e., the person executing the
 * code) has free reign to execute those cells at their own pacing.
 * Suggested time limits between each block code are provided in
 * comments.  Because the piece has carefully controlled randomized
 * patterns and freedom from the operator, the piece varies from
 * performance to performance.  A typically performance lasts
 * around 9 - 10 minutes but could last much longer if so desired.
 *
 * The piece is run by executing the cell block below to setup
 * the server and load all the sounds.  After that the operator
 * can optionally open up any windows to monitor the sound.  When
 * ready, the piece begins with the first code block under
 * "Background Wash" and proceeds sequentially from code to block
 * to code block until the piece is complete.
 *
 * Questions or technical difficulties can be directed to Andrew Davis
 * at andrewdavis33@gmail.com.
 *
 * Dependencies: The piece requires the SuperMassive plugin from
 * Valhalla and should be loaded using the extension VSTPlugin.
 * This piece requires version 3.11 or higher of SuperCollider.
 */

(
// Server setup
Pbindef.all.do(_.clear);
Window.closeAll;
s.options.memSize_(2.pow(20)); // Prevent memory alloc crashes
// ServerOptions.outDevices;
// s.options.outDevice_("Out_Soundflower_Built-In");
// ServerBoot.removeAll;
// ServerTree.removeAll;
// ServerQuit.removeAll;

// Globals and load functions file
~out = 0;
~tempo = 72;
~parentPath = thisProcess.nowExecutingPath.dirname;
~functionsPath = ~parentPath +/+ "functions.scd";
~functionsPath.load;
~smPresets = ~parentPath +/+ "supermassive_presets";

~setup = {
	~clock = TempoClock(~tempo/60);

	// Master out
	~masterBus = Bus.audio(s, 2);
	~masterSynth = Synth(\master, [\inBus, ~masterBus, \outBus, ~out]);

	// Reverb group
	~reverbGroup = Group(~masterSynth, \addBefore);
	~washBus = Bus.audio(s, 2);
	~washSynth = Synth(\wash, [\inBus, ~washBus, \outBus, ~masterBus], ~reverbGroup);
	~reverbBus = Bus.audio(s, 2);
	~reverbSynth = Synth(\reverb, [\inBus, ~reverbBus, \outBus, ~masterBus], ~reverbGroup);
	~supermassiveBus = Bus.audio(s, 2);
	~supermassiveSynth = Synth(
		\supermassive,
		[\inBus, ~supermassiveBus, \outBus, ~masterBus],
		~reverbGroup
	);
	~supermassive = VSTPluginController(~supermassiveSynth).open(
		"/Library/Audio/Plug-Ins/VST/ValhallaSupermassive.vst"
	);
	~supermassiveBus2 = Bus.audio(s, 2);
	~supermassiveSynth = Synth(
		\supermassive,
		[\inBus, ~supermassiveBus2, \outBus, ~masterBus],
		~reverbGroup
	);
	~supermassive2 = VSTPluginController(~supermassiveSynth).open(
		"/Library/Audio/Plug-Ins/VST/ValhallaSupermassive.vst"
	);

	// Fadeout trigger just for chords
	~chordBus = Bus.audio(s, 2);
	~chordVolumeSynth = Synth(
		\fadeOut,
		[\inBus, ~chordBus, \outBus, ~supermassiveBus2],
		~reverbGroup,
		\addBefore
	);

	// Scale and Cycles
	~scale = #[0, 2, 3, 5, 7, 8, 10]; // Piece in C minor
	~melodyCycle = [
		[1, 4], [3, 4], [4, 8], [1, 4], [3, 4], [4, 4], [5, 4], [3, 4], [2, 4],
		[1, 4], [3, 4], [1, 4], [0, 4], [-1, 4], [-2, 4], [-1, 4], [-3, 4], [-2, 8],
		[Rest(), 4], [-2, 4]
	];
	~cycle1 = Pseq(
		[
			2, 4, 5,
			Rest(1),
			Prand([Rest(1), 5]),
			5
		] - 1,
		inf
	);
	~cycle1_mod = [
		[2, 3.5], [4, 3.5], [5, 7], [Rest(1), 3.5], [5, 7], [5, 3.5]
	];
	~chordCycle = [
		[1, 1, 7], [3, 2, 6], [1, 7, 6], [2, 3, 6, 3, 1, 6],
		[1, 6, 6], [2, 2, 6, 3, 7, 5], [1, 5, 6], [2, 1, 6, 3, 6, 5], [1, 4, 6],
		[2, 7, 5, 3, 5, 5], [1, 3, 6], [1, 1, 6, 3, 4, 5]
	];
};

s.waitForBoot({

	// Sound sources
	SynthDef(\tone, {
		arg outBus = 0, freq = 521, amp = 0.2, pos = 0, atk = 0.05,
		select = 0, center_freq = 1000, q = 1, db = -3;
		var sig;

		sig = Klank.ar(`[
			[freq, freq*1.501, freq*1.97], // freqs
			[0.7, 0.45, 0.25], // amps
			[0.2, 0.3, 0.48] // phases
		], Impulse.ar(0));
		DetectSilence.ar(sig, doneAction: 2);

		// Filter out mids if necessary
		sig = Select.ar(select, [sig, BPeakEQ.ar(sig, center_freq, 1/q, db)]);

		sig = sig * EnvGen.kr(Env([0, 1], [atk]));
		sig = Pan2.ar(sig, pos, amp);

		Out.ar(outBus, sig);
	}).add;

	SynthDef(\saw, {
		arg outBus, amp = 0.1, freq = 440, pos = 0, cutoff = 1500,
		atk = 2, rel = 2, dec = 1, susLvl = 0.8, gate = 1, cutoff_fac = 1.05;
		var sig, env, cutoff_env;

		// Envelope
		env = EnvGen.kr(Env.adsr(atk, dec, susLvl, rel), gate, doneAction: 2);

		// Subtractive synth with saw
		sig = Saw.ar(freq, amp);
		cutoff_env = env.range(1, cutoff_fac) * cutoff;
		sig = MoogVCF.ar(sig, cutoff_env, 0.1);
		sig = BHiShelf.ar(sig, 2400, db: -3);

		sig = sig * env;
		sig = Pan2.ar(sig, pos);

		Out.ar(outBus, sig);
	}).add;

	SynthDef(\saw2, {
		arg outBus, amp = 0.1, freq = 440, pos = 0, cutoff = 1500,
		atk = 2, rel = 2, dec = 1, susLvl = 0.8, gate = 1, cutoff_fac = 1.05;
		var sig, env, cutoff_env;

		// Envelope
		env = EnvGen.kr(Env.adsr(atk, dec, susLvl, rel), gate, doneAction: 2);

		// Subtractive synth with saw
		sig = Saw.ar(freq, amp);
		cutoff_env = EnvGen.kr(Env([1, cutoff_fac, 1], [3, 3])) * cutoff;
		sig = MoogVCF.ar(sig, cutoff_env, 0.1);
		sig = BHiShelf.ar(sig, 2400, db: -3);

		sig = sig * env;
		sig = Pan2.ar(sig, pos);

		Out.ar(outBus, sig);
	}).add;

	SynthDef(\bell, {
		arg outBus = 0, freq = 200, pos = 0, amp = 0.1, atk = 0.03;
		var sig;

		sig = Klank.ar(`[[1, 1.95, 1.5, 2.01, 2.5] * freq, nil, 1 ! 4], Impulse.ar(0)) * amp;
		sig = BHiShelf.ar(sig, freq * 1.5, db: -9);

		// Turn off if silence detected
		DetectSilence.ar(sig, amp: 0.001, doneAction:2);

		// Wait 5 seconds and turn off anyway
		EnvGen.kr(Env([0, 0], [5]), doneAction: 2);

		sig = sig * EnvGen.kr(Env([0, 1], [atk]));
		sig = Pan2.ar(sig, pos);

		Out.ar(outBus, sig);
	}).add;

	SynthDef(\play, {
		arg outBus = 0, buf, pos = 0, amp = 1;
		var sig;

		sig = PlayBuf.ar(2, buf, startPos: pos, doneAction: 2) * amp;
		Out.ar(outBus, sig);
	}).add;

	// Reverbs
	SynthDef(\wash, {
		arg outBus = 0, inBus;
		var sig, numFilters = 16;

		sig = In.ar(inBus, 2);

		numFilters.do({
			sig = AllpassN.ar(
				in: sig,
				maxdelaytime: 0.2,
				delaytime: {Rand(0.05, 0.15)} ! 2,
				decaytime: {Rand(2, 4)} ! 2
			);
		});

		sig = LPF.ar(sig, 3500);

		Out.ar(outBus, sig);
	}).add;

	SynthDef(\reverb, {
		arg outBus = 0, inBus, mix = 0.4;
		var dry, wet, sig, numFilters = 8;

		dry = In.ar(inBus, 2);

		wet = dry;
		numFilters.do({
			wet = AllpassN.ar(
				in: wet,
				maxdelaytime: 0.2,
				delaytime: {Rand(0.05, 0.15)} ! 2,
				decaytime: {Rand(1, 2)} ! 2
			);
		});

		wet = LPF.ar(wet, 3500);
		sig = dry.blend(wet, mix);

		Out.ar(outBus, sig);
	}).add;

	SynthDef(\supermassive, {
		arg outBus, inBus, bypass = 0;
		var sig;

		sig = In.ar(inBus, 2);
		sig = VSTPlugin.ar(sig, 2, bypass);

		Out.ar(outBus, sig);
	}).add;

	// Audio out
	SynthDef(\fadeOut, {
		arg inBus, outBus, gate = 1, relTime = 4;
		var sig, env;

		sig = In.ar(inBus, 2);
		sig = sig * EnvGen.kr(
			Env.cutoff(relTime, curve: \sine),
			gate,
			doneAction: 2
		);

		Out.ar(outBus, sig);
	}).add;

	SynthDef(\master, {
		arg inBus, outBus, mute = 1, hi_cutoff = 4000, hi_db = 4, low_cutoff = 1000, low_db = 1;
		var sig;
		sig = In.ar(inBus, 2);
		sig = sig * mute;

		// Any processing here
		sig = BPeakEQ.ar(sig, 74.5, 1/0.6, -5);
		sig = BHiShelf.ar(sig, hi_cutoff, db: hi_db);
		sig = BLowShelf.ar(sig, low_cutoff, db: low_db);
		sig = Limiter.ar(sig, dur: 0.05);

		Out.ar(outBus, sig);
	}).add;

	s.sync;

	~boomDict = ~loadSoundsFolder.(~parentPath +/+ "booms");
	~reverseDict = ~loadSoundsFolder.(~parentPath +/+ "reverses");

	s.sync;

	~setup.value;

	s.sync;

	~supermassive.readProgram(~smPresets +/+ "preset1.fxp");
	~supermassive2.readProgram(~smPresets +/+ "preset2.fxp");

	s.sync;

	"Setup complete".postln;
});
)

/***********
 * Windows *
 ***********/

// Optionally open up windows
s.meter;
s.plotTree;
~supermassive.editor;
~supermassive2.editor;
FreqScope.new

// Optionally record
s.record;

~masterSynth.set(\low_db, 1);

/*******************
 * Background Wash *
 *******************/

// Description: a low rumble of a pitched wash

(
Pbindef(\low_rumble,
	\instrument, \tone,
	\scale, ~scale,
	\degree, Prand((1..7) - 1, inf),
	\octave, 3,

	\amp, Pwhite(0.25, 0.3) * Pseg([0, 1, 1], [10, inf]),
	\atk, 0.004,

	\select, 1,
	\center_freq, 600,
	\q, 1,
	\db, -3,

	\pos, Pwhite(-1.0, 1.0),
	\outBus, ~washBus,

	\dur, Pwhite(0.1, 0.2)
).play(~clock);
)

// Wait: 5 - 15 sceonds
// Description: a rumble one octave higher than the low rumble

(
Pbindef(\mid_rumble,
	\instrument, \tone,
	\scale, ~scale,
	\degree, Prand((1..7) - 1, inf),
	\octave, 4,

	\amp, Pwhite(0.25, 0.3) * Pseg([0, 1, 1], [10, inf]),
	\atk, 0.004,

	\select, 1,
	\center_freq, 1000,
	\q, 1,
	\db, -3,

	\pos, Pwhite(-1.0, 1.0),
	\outBus, ~washBus,

	\dur, Pwhite(0.1, 0.2)
).play(~clock);
)

// Wait: 5 - 15 seconds
// Repeat: 2 - 4 times and wait a few seconds between each repetition
// Description: soft bleeps pinging back and forth over the span of a few seconds

(
Pbind(
	\instrument, \tone,
	\scale, ~scale,
	\degree, Prand([1, 3, 4] - 1, inf),
	\octave, 5,

	\amp, Pwhite(0.1, 0.15) * Pseg([0.01, 1, 1, 0.01], [5, 4, 6], [\exp, \lin]),
	\atk, 0.004,

	\pos, Prand([-0.8, 0.8], inf),
	\outBus, ~reverbBus,

	\dur, Pwhite(0.1, 0.25)
).play(~clock);
)

// Wait: 5 - 15 seconds
// Description: a high rumble two octaves above the lower rumble

(
Pbindef(\high_rumble,
	\instrument, \tone,
	\scale, ~scale,
	\degree, Prand((1..7) - 1, inf),
	\octave, 5,

	\amp, Pwhite(0.15, 0.25) * Pseg([0, 1, 1], [10, inf]), // fade in
	\atk, 0.004,

	\select, 1,
	\center_freq, 1000,
	\q, 1,
	\db, -6,

	\pos, Pwhite(-1.0, 1.0),
	\outBus, ~washBus,

	\dur, Pwhite(0.05, 0.1)
).play(~clock);
)

// Wait: 5 - 10 seconds
// Description: soft bleeps pinging back and forth over the span of a few seconds

(
Pbind(
	\instrument, \tone,
	\scale, ~scale,
	\degree, Prand([1, 3, 4] - 1, inf),
	\octave, 5,

	\amp, Pwhite(0.2, 0.3) * Pseg([0.01, 1, 1, 0.01], [5, 4, 6], [\exp, \lin]),
	\atk, 0.004,

	\pos, Prand([-0.8, 0.8], inf),
	\outBus, ~reverbBus,

	\dur, Pwhite(0.1, 0.25)
).play(~clock);
)

// Wait: 5 seconds
// Description: sustained soft bleeps pinging back and forth

(
Pbindef(\dots,
	\instrument, \tone,
	\scale, ~scale,
	\degree, Prand([1, 2, 3, 4, 5, 7] - 1, inf),
	\octave, 5,

	\amp, Pwhite(0.25, 0.3) * Pseg([0, 1, 1], [5, inf]),
	\atk, 0.01,

	\pos, Prand([-0.8, 0.8], inf),
	\outBus, ~reverbBus,

	\dur, Pwhite(0.1, 0.2)
).play(~clock);
)

/***********
 * Strings *
 ***********/

// Wait: 5 seconds
// Description: Play the first string melody playing ~cycle1
s.plotTree;
(
// Reduce rumbles
Pbindef(\low_rumble, \amp, Pwhite(0.2, 0.3));
Pbindef(\mid_rumble, \amp, Pwhite(0.2, 0.3));
Pbindef(\high_rumble, \amp, Pwhite(0.15, 0.18));

// Make dots quieter
Pbindef(\dots, \amp, Pwhite(0.15, 0.2));

// First string instrument
Pbindef(\mid_strings,
	\instrument, \saw,
	\melody, [], // Ensures melody will be above other keys later
	\scale, ~scale,
	\degree, ~cycle1,
	\octave, 4,

	\cutoff, 850,

	\amp, 0.4,
	\atk, 1.5,
	\dec, 0,
	\susLvl, 1,
	\rel, 3,
	\legato, 0.95,

	\pos, Pwhite(-0.5, 0.5),
	\outBus, ~supermassiveBus,

	\dur, Pwhite(3.5, 4)
).play(~clock);
)

// Wait: 45 seconds or so; at least one pass through ~cycle1
// Repeat: 2 - 4 times; wait a few seconds between each repetition
// Description: more audible ping-ponging bleeps

(
Pbind(
	\instrument, \tone,
	\scale, ~scale,
	\degree, Prand([1, 3, 4] - 1, inf),
	\octave, 6,

	\amp, Pwhite(0.16, 0.18) * Pseg([0.01, 1, 1, 0.01], [5, 5, 6], [\exp, \lin]),
	\atk, 0.004,

	\pos, Prand([-0.8, 0.8], inf),
	\outBus, ~reverbBus,

	\dur, Pwhite(0.1, 0.25)
).play(~clock);
)

// Wait: 5 seconds
// Description: sustained ping-ponging bleeps

(
Pbindef(\higher_dots,
	\instrument, \tone,
	\scale, ~scale,
	\degree, Prand([1, 3, 4, 5] - 1, inf),
	\octave, 6,

	\amp, Pwhite(0.16, 0.18) * Pseg([0.01, 1, 1, 0.01], [4, 4, 4.4], [\exp, \lin], inf),
	\atk, 0.004,

	\pos, Prand([-0.8, 0.8], inf),
	\outBus, ~reverbBus,

	\dur, Pwhite(0.1, 0.2)
).play(~clock);
)

// Wait: 5 - 10 seconds
// Description: Bass pattern that introduces the melodic cycle

(
Pbindef(\mid_strings, \pos, Pwhite(-0.5, -0.4));
Pbindef(\low_strings,
	\instrument, \saw,
	\melody, Pseq(~melodyCycle, inf), // Ensures melody will be above other keys later
	\scale, ~scale,
	\degree, Pkey(\melody).collect({|pair| if(pair[0] != Rest(), {pair[0] - 1}, {Rest()})}),
	\octave, 3,

	\cutoff, 800,

	\amp, 0.4,
	\atk, 1.5,
	\dec, 0,
	\susLvl, 1,
	\rel, 1.5,
	\legato, 0.95,

	\pos, Pwhite(-0.2, 0.2),
	\outBus, ~supermassiveBus,

	\dur, Pkey(\melody).collect({|pair| pair[1]}),
).play(~clock, quant:0);
)

// Wait: 25 - 30 seconds
// Description: brings in second string playing ~cycle1 just above the first string

(
Pbindef(\mid_strings2,
	\instrument, \saw,
	\melody, [], // Ensures melody will be above other keys later
	\scale, ~scale,
	\degree, ~cycle1 + 5,
	\octave, 4,

	\cutoff, 1200,

	\amp, 0.4,
	\atk, 1.5, // make first longer
	\dec, 0,
	\susLvl, 1,
	\rel, 3,
	\legato, 0.95,

	\pos, Pwhite(0.4, 0.5),
	\outBus, ~supermassiveBus,

	\dur, 4
).play(~clock, quant: 0);
)

// Wait: 25 - 30 seconds
// Description: Bring in third string playing ~cycle1

(
// Bring down other strings and increase dots
Pbindef(\mid_strings2, \amp, 0.3);
Pbindef(\mid_strings, \amp, 0.3);
Pbindef(\dots, \amp, Pwhite(0.3, 0.4));
Pbindef(\higher_dots, Pwhite(0.21, 0.25));

// Create a fading in/out high rumble
Pbindef(\high_rumble2,
	\instrument, \tone,
	\scale, ~scale,
	\degree, Prand((1..7) - 1, inf),
	\octave, 6,

	\amp, Pwhite(0.2, 0.4) * Pseg([0.2, 1, 0.2], [4, 4], 'lin', inf), // fade in,
	\atk, 0.004,

	\outBus, ~washBus,

	\dur, Pwhite(0.1, 0.2),
).play(~clock);

Pbindef(\high_strings,
	\instrument, \saw,
	\scale, ~scale,
	\degree, ~cycle1 + 3,
	\octave, 5,

	\cutoff, 1300,

	\amp, 0.45,
	\atk, 2,
	\dec, 0,
	\susLvl, 1,
	\rel, 1.5,
	\legato, 0.95,

	\pos, Pwhite(-0.4, -0.1),
	\outBus, ~supermassiveBus2,

	\dur, 3.5,
).play(~clock, quant: 0);
)

// Wait: 25 - 30 seconds
// Description: Move the high strings up a perfect 4th

(
Pbindef(\high_strings,
	\degree, ~cycle1 + 5,
	\cutoff, 1350
);
)

/************
 * High End *
 ************/

// Wait: 15 - 20 seconds
// Description: Introduce a swelling higher shimmer

(
Pbindef(\swelling_rumble,
	\instrument, \tone,
	\scale, ~scale,
	\degree, Prand([0, 1, 2, 3, 4, 5, 6], inf),
	\octave, 7,

	\amp, Pwhite(0.04, 0.06) * Pseg([0.01, 1, 1, 0.01, 0.01], [1, 2, 1.4, 6], [\exp, \lin], inf),
	\atk, 0.004,

	\select, 1,
	\center_freq, 1500,
	\q, 1,
	\db, -3,

	\pos, Pseg([-0.8, 0.8, -0.8], Prand([5, 7, 9], inf), repeats: inf),
	\outBus, ~washBus,

	\dur, Pwhite(0.05, 0.1),
).play(~clock);
)

// Wait: 5 - 15 seconds
// Description: Introduce repeating diatonic bells

(
Pbindef(\bells,
	\instrument, \bell,
	\rand, Prand([3, 5, 7, 11], inf),

	\scale, ~scale,
	\degree, Pstutter(Pkey(\rand), Prand([0, 1, 2, 3, 4, 5, 6], inf)),
	\octave, 6,

	\amp, Pwhite(0.06, 0.15) * Pseg([0, 1, 1], [10, inf]),
	\atk, Pwhite(0.001, 0.01),

	\pos, Pstutter(Pkey(\rand), Pwhite(-0.6, 0.6)),
	\outBus, ~reverbBus,

	\dur, Pwhite(0.1, 0.3)
).play(~clock);
)

// Wait: 5 - 15 seconds
// Description: Highest strings play the ~melodicCycle

(
// Reduce amplitude of of higher strings
Pbindef(\high_strings, \degree, ~cycle1 + 3, \cutoff, 1400, \amp, 0.35);

// Introduce highest strings
Pbindef(\highest_strings,
	\instrument, \saw2,
	\melody, Pseq(~melodyCycle, inf),
	\scale, ~scale,
	\degree, Pkey(\melody).collect({|pair| if(pair[0] != Rest(), {pair[0] - 1}, {Rest()})}) + 3,
	\octave, 6,

	//\cutoff, Pseg([1900, 2000], [10], repeats: inf),
	\cutoff, 2500,
	\cutoff_fac, 1.1,

	\amp, 0.3,
	\atk, 2.5,
	\dec, 0,
	\susLvl, 1,
	\rel, 1.5,
	\legato, 0.95,

	\pos, Pwhite(-0.1, 0.4),
	\outBus, ~supermassiveBus,

	\dur, Pkey(\melody).collect({|pair| pair[1]}),
).play(~clock, quant: 0);
)

/**********
 * Climax *
 **********/

// Wait: 30 - 45 seconds
// Description: Build intensity as volume and high end increase

(
// Increase string volume and open up filters
Pbindef(\low_strings,
	\degree, Pseq([1, 3, 4], inf) - 1,
	\amp, Pseg([0.4, 0.45, 0.45], [20, inf], \exp),
	//\cutoff, Pseg([800, 1200, 1200], [20, inf])
);
Pbindef(\mid_strings,
	\amp, Pseg([0.35, 0.45, 0.45], [20, inf], \exp),
	//\cutoff, Pseg([850, 1300, 1300], [20, inf])
);
Pbindef(\mid_strings2,
	\amp, Pseg([0.35, 0.45, 0.45], [20, inf], \exp),
	//\cutoff, Pseg([1200, 1500, 1500], [20, inf]),
);
Pbindef(\high_strings,
	\amp, Pseg([0.35, 0.5, 0.5], [20, inf], \exp),
	\cutoff, Pseg([1500, 2000, 2000], [20, inf])
);
Pbindef(\highest_strings,
	\amp, Pseg([0.3, 0.35, 0.35], [20, inf], \exp),
	\cutoff, Pseg([2500, 3500, 3500], [20, inf])
);

// Bring up the volume of the rumbles
Pbindef(\mid_rumble, \amp, Pseg([0.4, 0.2, 0.2], [20, inf]));
Pbindef(\high_rumble, \amp, Pseg([0.25, 0.3, 0.3], [20, inf]));
Pbindef(\high_rumble2, \amp, Pseg([0.2, 0.4, 0.4], [20, inf]));
Pbindef(\swelling_rumble,
	\octave, Pseg([8, 14, 8], [2, 2], repeats: inf),
	\amp, Pseg([0.05, 0.25, 0.25], [20, inf]),
	\pos, Pseg([-0.8, 0.8, -0.8], [5, 5], repeats: inf),
	\dur, Pwhite(0.01, 0.02),
);
)

// Wait: 30 - 40 seconds
// Description: Bring in the rising chords and start to reduce the background noise while increasing
// the ping-ponging bleeps
// Note: chords are traced so you can see len which maps to duration

(
Pbindef(\chords,
	\instrument, \saw2,
	\scale, ~scale,
	\degree, [1, 7] - 1 + Pseq(Array.series(5), inf) + Pstutter(5, Pseries(0, 1, inf)),
	\octave, 6,

	\cutoff, 3500,

	\amp, Pseg([0.3, 0.4, 0.4], [20, inf]),
	\atk, 2.5,
	\dec, 0,
	\susLvl, 1,
	\rel, 1.5,
	\legato, 0.95,

	\pos, [-0.5, 0.5],
	\outBus, ~supermassiveBus,

	\dur, 4
).trace(\dur).play(~clock);

// Increase dots volume
Pbindef(\dots,
	\amp, Pseg([0.2, 0.4, 0.4], [20, inf], \exp),
	\pos, Pwhite(-0.8, 0.8),
	\dur, Pwhite(0.1, 0.2) / Pseg([1, 2], [20, inf])
);
Pbindef(\higher_dots,
	\amp, Pseg([0.16, 0.3, 0.3], [20, inf], \exp),
	\dur, Pwhite(0.05, 0.1) / Pseg([1, 2], [20, inf]),
	\pos, Pwhite(-0.8, 0.8)
);

// Start fading out rumbles
Pbindef(\low_rumble, \amp, Pseg([0.2, 0.04, 0.0001], [40, 10], \lin));
Pbindef(\mid_rumble, \amp, Pseg([0.2, 0.05, 0.0001], [40, 10], \lin));
Pbindef(\high_rumble, \amp, Pseg([0.3, 0.01, 0.0001], [40, 10], \lin));
Pbindef(\high_rumble2, \amp, Pseg([0.4, 0.01, 0.0001], [40, 10], \lin));
)

/***********
 * Fallout *
 ***********/

// Wait: 25 - 30 seconds
// Description: Fade out all of the background flutter leaving only the strings

(
Pbindef(\swelling_rumble, \amp, Pseg([0.25, 0.0001], [37]));
Pbindef(\dots, \amp, Pseg([0.3, 0.0001], [35], \lin));
Pbindef(\higher_dots, \amp, Pseg([0.3, 0.0001], [34], \lin));
Pbindef(\highest_strings).stop;
Pbindef(\bells, \amp, Pwhite(0.06, 0.1) * Pseg([1, 0.0001], [31], \lin));
)

// Wait: 15 seconds
// Description: Fade out all strings except the chords; lengths will increase for chords
// and shown in post window

(
Pbindef(\low_strings, \amp, Pseg([0.4, 0.0001], [40], \lin));
Pbindef(\mid_strings, \amp, Pseg([0.3, 0.0001], [50], \lin));
Pbindef(\mid_strings2, \amp, Pseg([0.3, 0.0001], [40], \lin));
Pbindef(\high_strings, \amp, Pseg([0.25, 0.0001], [30], \lin));
Pbindef(\chords,
	\cutoff, Pseg([4000, 3000, 3000], [50, inf], \lin),
	\dur, Pseg([4, 6, 6], [30, inf]),
	\amp, Pseg([0.3, 0.1], [50]),
);
)

// Wait: 30 seconds or so, until other strings have faded out
// Description: Will hold one the next chord after pressed

Pbindef(\chords, \dur, Pseq([15]), \atk, 5, \dec, 5, \susLvl, 0.8, \rel, 1, \amp, 0.1);

/********************
 * Boom and Descent *
 ********************/

// Wait: Execute once the held chord is played and you see length of 30 in the post window
// Description: Crossfade the held chord with the sharp rise into a giant boom

(
~clock.sched(0, {
	s.bind({
		Synth(\play, [\outBus, ~out, \buf, ~reverseDict["reverse_verb.wav"], \amp, 1]);
	});
});

~clock.sched(9.5, {
	s.bind({
		~chordVolumeSynth.set(\gate, 0);
	});
});

~clock.sched(14.8, {
	Pbindef.all.keysValuesDo({
		|key, value|
		value.stop;
	});

	Pbindef(\bells3,
		\instrument, \bell,
		\scale, ~scale,
		\degree, 4 - 1,
		\octave, 6,

		\amp, Pwhite(0.04, 0.08) * Pseg([3, 1, 1], [1, inf], ['exp', 'lin']),
		\atk, Pwhite(0.001, 0.01),

		\pos, Pwhite(1, 1.1) * Pseg([0.2, 0.5, -0.1, 0.2], [5, 4, 2], \lin, inf),
		\outBus, ~reverbBus,

		\dur, Pwhite(0.1, 0.12)
	).play(~clock, quant: 0);

	s.bind({
		Synth(\play, [\outBus, ~out, \buf, ~boomDict["low_1000.wav"], \amp, 1]);
	});
});
)

// Wait: 10 seconds
// Description: Play a cyclical pattern of booms that occur once every 10 - 15 seconds

(
Pbindef(
	\booms,
	\instrument, \play,

	\high, 900,
	\low, 600,
	\buf, Pfunc({
		|event|
		var low = event[\low];
		var high = event[\high];

		var options = [];
		~boomDict.keysValuesDo({
			|fileName, buf|
			var cutoff = fileName.select({arg char; char.isDecDigit}).asInteger;
			if(cutoff <= high && (cutoff >= low), {
			options = options.add(buf);
			});
		});

		options.choose;
	}),

	\amp, Pseg([1, 0.1], [180], \exp),
	\outBus, ~out,

	\dur, Pwhite(10, 15),
).play(~clock, quant: 0);
)

// Wait: 10 seconds
// Description: Bring in another repeated bell sound

(
Pbindef(\booms, \high, 800, \low, 400);
Pbindef(\bells2,
	\instrument, \bell,
	\scale, ~scale,
	\degree, 6 - 1,
	\octave, 6,

	\amp, Pwhite(0.04, 0.08) * Pseg([0, 1, 1], [1, inf], 'lin'),
	\atk, Pwhite(0.001, 0.01),

	\pos, Pwhite(-0.6, -0.3),
	\outBus, ~reverbBus,

	\dur, Pwhite(0.1, 0.12)
).play(~clock, quant: 0);
)

// Wait: 10 seconds
// Description: Bring in third bell sound

(
Pbindef(\bells1,
	\instrument, \bell,
	\scale, ~scale,
	\degree, 7 - 1,
	\octave, 6,

	\amp, Pwhite(0.04, 0.08) * Pseg([0, 1, 1], [2, inf], 'lin'),
	\atk, Pwhite(0.001, 0.01),

	\pos, Pwhite(1, 1.1) * Pseg([0, 0.5, -0.5, 0], [4, 5, 6], \lin, inf),
	\outBus, ~reverbBus,

	\dur, Pwhite(0.1, 0.12)
).play(~clock, quant: 0);
)

// Wait: 10 seconds
// Description: Shift lower bell and bring in descending bass

(
Pbindef(\bells3, \degree, 3 - 1);
Pbindef(\descending_bass,
	\instrument, \saw,
	\scale, ~scale,
	\degree, Pseries(3 - 1, -1, inf),
	\octave, 5,

	\cutoff, 1500,

	\amp, 0.3,
	\atk, 2.5,
	\dec, 0,
	\susLvl, 1,
	\rel, 1.5,
	\legato, 0.95,

	\pos, Pwhite(1, 1.1) * Pseg([0.2, 0.5, -0.1, 0.2], [5, 4, 2], \lin, inf),
	\outBus, ~supermassiveBus,

	\dur, 8,
).play(~clock, quant: 0);


// Reduce the volume of ringing bells
Pbindef(\bells1, \amp, Pwhite(1, 2) * Pseg([0.04, 0.03, 0.03], [20, inf], 'exp', inf));
Pbindef(\bells2, \amp, Pwhite(1, 2) * Pseg([0.04, 0.03, 0.03], [20, inf], 'exp', inf));
Pbindef(\bells3, \amp, Pwhite(1, 2) * Pseg([0.04, 0.03, 0.03], [20, inf], 'exp', inf));
)

// Wait: 10 - 20 seconds
// Description: Introduce swelling rumbles

(
Pbindef(\swell_rumble1,
	\instrument, \tone,
	\scale, ~scale,
	\degree, Prand((1..7) - 1, inf),
	\octave, 6,

	\amp, Pwhite(0.2, 0.4) * Pseg([0, 1, 1], [10, inf]), // fade in
	\atk, 0.004,

	\select, 1,
	\center_freq, 1000,
	\q, 1,
	\db, -6,

	\pos, Pwhite(-1.0, 1.0),
	\outBus, ~washBus,

	\dur, Pwhite(0.05, 0.1),
).play(~clock);

Pbindef(\swell_rumble2,
	\instrument, \tone,
	\scale, ~scale,
	\degree, Prand((1..7) - 1, inf),
	\octave, 7 * Pstep([0, 1], Pwhite(9, 12), inf),

	\amp, Pwhite(0.1, 0.2) * Pseg([0, 1, 1], [10, inf]), // fade in
	\atk, 0.004,

	\outBus, ~washBus,

	\dur, Pwhite(0.05, 0.1),
).play(~clock);
)

// Wait: 10 - 20 Seconds
// Description: Cycle through a chord change for the bells

(
~chordChanges = Routine({
	var octave_offset = 0;
	// voice, degree, octave, ...
	loop({
		~chordCycle.do({
			|changeArray|
			var i = 0;
			while({i < changeArray.size}, {
				var voice = changeArray[i];
				var degree = changeArray[i + 1] - 1;
				var octave = changeArray[i + 2] + octave_offset;
				var name = ("bells" ++ voice.asString).asSymbol;
				Pbindef(name, \degree, degree, \octave, octave);

				i = i + 3;
			});

			// Wait time until next chord change
			rrand(4, 6).wait;
		});
		octave_offset = octave_offset - 1;
	});
	nil
}).play; // keep on system clock

// Fluctuate amplitude
Pbindef(\bells1,
	\amp, 1.5 * Pwhite(0.02, 0.04) * Pseg([1, 0.8, 1, 0.7, 1], [4, 2.5, 3, 2], \lin, inf),
);

Pbindef(\bells2,
	\amp, 1.5 * Pwhite(0.02, 0.04) * Pseg([1, 0.7, 1], [1, 4, 2], \lin, inf),
);

Pbindef(\bells3,
	\amp, 1.5 * Pwhite(0.02, 0.04) * Pseg([1, 0.7, 0.8, 0.5, 1], [3, 4.5, 2.5, 2.5, 2], \lin, inf),
);
)

// Wait: 20 - 25 seconds
// Description: Bring in a recap of ~cycle1

(
Pbindef(\booms, \high, 600, \low, 200);
Pbindef(\regal_strings,
	\instrument, \saw,
	\melody, Pseq(~cycle1_mod, inf),
	\scale, ~scale,
	\degree, Pkey(\melody).collect({|pair| if(pair[0] != Rest(), {pair[0] - 1}, {Rest()})}),
	\octave, 5,

	\cutoff, 1700,

	\amp, 0.7,
	\atk, 2.5,
	\dec, 0,
	\susLvl, 1,
	\rel, 1.5,
	\legato, 0.95,

	\pos, Pwhite(-0.5, 0.5),
	\outBus, ~supermassiveBus,

	\dur, Pkey(\melody).collect({|pair| pair[1]})
).play(~clock);

// Reduce volume of swells
Pbindef(\swell_rumble2, \amp, Pwhite(0.05, 0.1));
)

// Wait: 10 - 20 seconds
// Description: Bring in rumbles below melody cycle

(
Pbindef(\swell_mid_rumble,
	\instrument, \tone,
	\scale, ~scale,
	\degree, Prand((1..7) - 1, inf),
	\octave, 4 + Pstep([0, 1], Pwhite(9, 15), inf),

	\amp, Pwhite(0.4, 0.6) * Pseg([0, 1, 1], [10, inf]), // fade in
	\atk, 0.004,

	\pos, Pwhite(-1.0, 1.0),
	\outBus, ~washBus,

	\dur, Pwhite(0.1, 0.2),
).play(~clock);
)

/**********
 * ENDING *
 **********/

// Wait: 20 - 30 seconds
// Description: Fade out the bell chords

(
~chordChanges.stop;
Pbindef(\bells1, \amp, Pwhite(1, 2) * Pseg([0.02, 0], [20], \lin, 1));
Pbindef(\bells2, \amp, Pwhite(1, 2) * Pseg([0.02, 0], [20], \lin, 1));
Pbindef(\bells3, \amp, Pwhite(1, 2) * Pseg([0.02, 0], [20], \lin, 1));
)

// Wait: 10 - 15 seconds
// Description: Fade out the remaining instruments

(
Pbindef(\regal_strings, \amp, Pseg([0.7, 0.001], [70], \exp));
Pbindef(\descending_bass, \amp, Pseg([0.3, 0.001], [100], \exp));
Pbindef(\swell_mid_rumble, \amp, Pseg([0.5, 0.0001], [100], \exp));
Pbindef(\swell_rumble1, \amp, Pseg([0.3, 0.0001], [100], \exp));
Pbindef(\swell_rumble2, \amp, Pseg([0.3, 0.0001], [100], \exp));
)

/********
 * Stop *
 ********/

// Emergency if something happened and/or stop all patterns once fadeout is inaudible
(
Pbindef.all.keysValuesDo({
	|patName, pbindef|
	pbindef.stop;
});
)