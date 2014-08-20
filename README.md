Vocal-Sketcher
==============

Vocal Sketcher is an app created to transcribe audio input to MIDI data.

It achieves this through the following steps: 1 - Create a recording with the device's microphone.
                                              2 - Process this audio with an FFT algorithm
                                              3 - Use the output of the FFT to determine pitch and timing values
                                              4 - Write these pitch and timing values to a MIDI file
                                              5 - Export the MIDI file of the device via email
                                              
The algorithm is still in experimental stages, and struggles to correctly discern the human voice. However, 
it is capable of transcribing simple sine tones (albeit with slightly off frequency values) to MIDI data.


Almost all of the code is contained within vocalSketcherRebuilt/ViewController.m, with some supporting code in 
ViewController.h



Enjoy!
