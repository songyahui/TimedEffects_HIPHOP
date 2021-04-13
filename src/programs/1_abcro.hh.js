"use hiphop"
"use hopscript"

var hh = require("hiphop");

hiphop module prg( in A, in B, in C, in R, out O ) 
    /*@ requires "True && emp " @*/
    /*@ ensures "True && (A? // B? // C?)^*" @*/
{
   do {
      fork {
	 await( A.now );
      } par {
	 await( B.now );
      } par {
	 await( C.now );
      };
      emit O();
   } every( R.now )
}
exports.prg = new hh.ReactiveMachine( prg, "ABCRO" );
