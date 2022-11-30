"use hiphop"
"use hopscript"

const hh = require( "hiphop" );

module prg( in Tick, out O ) 
   /*@ requires "True && emp" @*/
   /*@ ensures "True && Tick?.Tick?.Tick?.({O}.Tick?.Tick?.Tick?)^*" @*/
{

   loop {
      await count( 3, Tick );
      emit O();
   }
}

exports.prg = new hh.ReactiveMachine( prg, "await3" );
