float life = 10000.; // life of each particle, in time units
float num = 10.; // particles generated per time interval
float size_end = 0.05; // ending size of each particle
float size_start = 0.01; // starting size of each particle
VECTOR color_end = {1.,0.,0.}; // ending color of each particle
VECTOR color_start = {1.,1.,0.}; // starting color of each particle
VECTOR dir = {0.01,0.002,0}; // direction in which particles are emitted
VECTOR emitter = {-1.,0.,0}; // location of particle emitter
VECTOR gravity = {0.,-1e-5,0}; // the force of gravity (or whatever)
VECTOR turb_dir = {0.,0.001,0.00}; // randomness of direction
