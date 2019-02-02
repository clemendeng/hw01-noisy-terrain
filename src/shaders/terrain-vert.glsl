#version 300 es


uniform mat4 u_Model;
uniform mat4 u_ModelInvTr;
uniform mat4 u_ViewProj;
uniform vec2 u_PlanePos; // Our location in the virtual world displayed by the plane
uniform float u_Time;

in vec4 vs_Pos;
in vec4 vs_Nor;
in vec4 vs_Col;

out vec3 fs_Pos;
out vec4 fs_Nor;
out vec4 fs_Col;

out float fs_y;
out float temp;
out float myst;
out float fs_Sine;

float random1( vec2 p , vec2 seed) {
  return fract(sin(dot(p + seed, vec2(127.1, 311.7))) * 43758.5453);
}

float random1( vec3 p , vec3 seed) {
  return fract(sin(dot(p + seed, vec3(987.654, 123.456, 531.975))) * 85734.3545);
}

vec2 random2( vec2 p , vec2 seed) {
  return fract(sin(vec2(dot(p + seed, vec2(311.7, 127.1)), dot(p + seed, vec2(269.5, 183.3)))) * 85734.3545);
}

vec2 worleyPoint(int x, int y, float seed) {
  //The random point inside grid cell (x, y)
  return random2(vec2(13.72 * float(x) * seed, 2.38 * float(y) * seed), vec2(0.28, 0.328));
}

//Worley returns a value in [0, 1]
float worley(vec2 pos, float seed) {
  //Calculating which unit the pixel lies in
  int x = int(floor(pos[0]));
  int y = int(floor(pos[1]));
  //Calculating closest distance
  float dist = 100000.f;
  for(int i = x - 1; i < x + 2; i++) {
    for(int j = y - 1; j < y + 2; j++) {
      vec2 point = vec2(float(i) + worleyPoint(i, j, seed)[0], float(j) + worleyPoint(i, j, seed)[1]);
      if(distance(pos, point) < dist) {
        dist = distance(pos, point);
      }
    }
  }
  return clamp(dist, 0.f, 1.f);
}

float falloff(float t) {
  return t*t*t*(t*(t*6.f - 15.f) + 10.f);;
}

float lerp(float a, float b, float t) {
  return (1.0 - t) * a + t * b;
}

//ix and iy are the corner coordinates
float dotGridGradient(int ix, int iy, float x, float y, float seed) {
  vec2 dist = vec2(x - float(ix), y - float(iy));
  vec2 rand = (random2(vec2(ix, iy), vec2(seed, seed * 2.139)) * 2.f) - 1.f;
  return dist[0] * rand[0] + dist[1] * rand[1];
}

//Perlin returns a value in [-1, 1]
float perlin(vec2 pos, float seed) {
  //Pixel lies in (x0, y0)
  int x0 = int(floor(pos[0]));
  int x1 = x0 + 1;
  int y0 = int(floor(pos[1]));
  int y1 = y0 + 1;

  float wx = falloff(pos[0] - float(x0));
  float wy = falloff(pos[1] - float(y0));

  float n0, n1, ix0, ix1, value;
  n0 = dotGridGradient(x0, y0, pos[0], pos[1], seed);
  n1 = dotGridGradient(x1, y0, pos[0], pos[1], seed);
  ix0 = lerp(n0, n1, wx);
  n0 = dotGridGradient(x0, y1, pos[0], pos[1], seed);
  n1 = dotGridGradient(x1, y1, pos[0], pos[1], seed);
  ix1 = lerp(n0, n1, wx);
  value = lerp(ix0, ix1, wy);

  return value;
}

//For mountains
float fbmWorley(vec2 pos, float octaves, float seed) {
  float total = 0.f;
  float persistence = 0.5f;

  for(float i = 0.f; i < octaves; i++) {
    float freq = pow(2.f, i);
    //divide by 2 so that max is 1
    float amp = pow(persistence, i) / 2.f;
    total += worley(pos * float(freq), seed) * amp;
  }

  return total;
}

//For noisy terrain
float fbmPerlin(vec2 pos, float octaves, float seed) {
  float total = 0.f;
  float persistence = 0.5f;

  for(float i = 0.f; i < octaves; i++) {
    float freq = pow(2.f, i);
    //divide by 2 so that max is 1
    float amp = pow(persistence, i) / 2.f;
    total += ((perlin(pos * float(freq), seed) + 1.f) / 2.f) * amp;
  }

  return total;
}

void main()
{
  fs_Pos = vs_Pos.xyz;
  fs_Sine = (sin((vs_Pos.x + u_PlanePos.x) * 3.14159 * 0.1) + cos((vs_Pos.z + u_PlanePos.y) * 3.14159 * 0.1));
  vec4 modelposition = vec4(vs_Pos.x, fs_Sine * 2.0, vs_Pos.z, 1.0);

  //temp threshold for ~50/50: 0.48
  temp = fbmPerlin((fs_Pos.xz + u_PlanePos) / 256.f, 4.0, 2.3294);
  float angle = mod(u_Time / 50.f, 360.f);
  myst = worley((fs_Pos.xz + u_PlanePos + vec2(cos(angle), sin(angle)) * u_Time / 5.f) / 128.f, 32.58);
  
  //COLD DIRT AND GRASS
  float coldY = (perlin((vs_Pos.xz + u_PlanePos) / 16.f, 1.38) + 1.f) / 2.f;
  coldY = pow(coldY, 4.f);

  //WINTER
  float fbm_Worley = fbmWorley((vs_Pos.xz + u_PlanePos) / 16.f, 8.f, 1.38);
  fbm_Worley = pow(fbm_Worley, 4.0) + smoothstep(0.15, 0.25, fbm_Worley) / 15.f;
  float colderY = fbm_Worley * 1.5;
  
  float t = smoothstep(0.38, 0.58, temp);
  fs_y = mix(coldY, colderY, t);
  modelposition = vec4(vs_Pos.x, fs_y * 10.f, vs_Pos.z, 1.0);

  modelposition = u_Model * modelposition;
  gl_Position = u_ViewProj * modelposition;
}
