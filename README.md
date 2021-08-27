# synthy

a synth that's soft and on the verge of melancholy.

![image](https://user-images.githubusercontent.com/6550035/131072123-00275007-b08a-470a-85d5-a0cee8179c21.gif)

https://vimeo.com/545281946

synthy is a polyphonic synth composed of two saw-wave oscillators per note which are mildly chorused plus a pulse-wave sub-oscillator that responds with low-note priority as a monophonic bass.

synthy's mnind is its own and obeys an internal stochastic rhythm. synthy may decide to shrink or grow and when it does, it causes the filter to close (when shrinking) or open (when growing). you can use K3 to manually take control, but after you stop turning K3 the synthy will revert to its own behavior after a certain time (available to change as a setting).

synthy's body is modeled as six revolute joints which are kinematically re-positioned when moving with K2 or K3. the x- and y- flucuations from the kinematics of the body movement do detuning and tremelo respectively. the degree of modulation is available to change in parameters ("squishy detuning" or "squishy tremelo").
 

## Requirements

- norns
- any midi controller

## Documentation


## Install

install with 

```
;install https://github.com/schollz/synthy
```

## license

MIT
