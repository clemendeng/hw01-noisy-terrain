#version 300 es
precision highp float;

uniform vec2 u_PlanePos; // Our location in the virtual world displayed by the plane
uniform float u_Time;
uniform float u_Day;
uniform float u_Magic;
uniform float u_Palette;

in vec3 fs_Pos;
in vec4 fs_Nor;
in vec4 fs_Col;

in float fs_Sine;
in float temp;
in float myst;
in float fs_y;

out vec4 out_Col; // This is the final output color that you will see on your
                  // screen for the pixel that is currently being processed.

float random1( vec2 p , vec2 seed) {
  return fract(sin(dot(p + seed, vec2(127.1, 311.7))) * 43758.5453);
}

vec2 random2(vec2 p, vec2 seed) {
  return fract(sin(vec2(dot(p + seed, vec2(311.7, 127.1)), dot(p + seed, vec2(269.5, 183.3)))) * 85734.3545);
}

vec2 worleyPoint(int x, int y, float seed) {
  //The random point inside grid cell (x, y)
  return random2(vec2(13.72 * float(x) * seed, 2.38 * float(y) * seed), vec2(0.28, 0.328));
}

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

float falloff(float t) {
  return t*t*t*(t*(t*6.f - 15.f) + 10.f);;
}

float lerp(float a, float b, float t) {
  return (1.0 - t) * a + t * b;
}

float dotGridGradient(int ix, int iy, float x, float y, float seed) {
  vec2 dist = vec2(x - float(ix), y - float(iy));
  vec2 rand = (random2(vec2(ix, iy), vec2(seed, seed * 2.139)) * 2.f) - 1.f;
  return dist[0] * rand[0] + dist[1] * rand[1];
}

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

vec3 palette( float t, vec3 a, vec3 b, vec3 c, vec3 d )
{
    return a + b*cos( 6.28318*(c*t+d) );
}

void main()
{
    //COLD DIRT AND GRASS
    //thresh: [0, 1]
    float thresh = fs_y * 2.25;
    thresh = clamp(0.0, 1.0, thresh);
    vec3 brown = vec3(0.341, 0.231, 0.047);
    vec3 green = vec3(0.376, 0.502, 0.22);
    vec3 coldCol = mix(brown, green, thresh);
    coldCol = mix(coldCol, vec3(1.0, 1.0, 1.0), perlin((fs_Pos.xz + u_PlanePos) / 8.f, 0.43889) / 5.f);

    //WINTER
    vec3 colderCol;
    float t;
    if(fs_y < 0.05) {
      //Ice pools
      colderCol = vec3(0.8, 0.9, 1);
    } else if(fs_y < 0.07) {
      t = smoothstep(0.05, 0.07, fs_y);
      vec3 outBase = mix(vec3(0.8, 0.9, 1), vec3(0.95, 0.95, 0.95), t);
      vec3 outMix = vec3(0.7, 0.7, 0.7);
      colderCol = vec3(mix(outBase, outMix, pow(perlin((fs_Pos.xz + u_PlanePos) / 4.f, 0.13889), 2.f)));
    } else {
      t = smoothstep(0.07, 0.3, fs_y);
      vec3 outBase = mix(vec3(0.95, 0.95, 0.95), vec3(1, 1, 1), t);
      vec3 outMix = vec3(0.7, 0.7, 0.7);
      colderCol = vec3(mix(outBase, outMix, pow(perlin((fs_Pos.xz + u_PlanePos) / 4.f, 0.13889), 2.f)));
    }

    float t1 = smoothstep(0.38, 0.58, temp);
    vec3 col = mix(coldCol, colderCol, t1);

    vec3 a = vec3(0.5, 0.5, 0.5);
    vec3 b = vec3(0.5, 0.5, 0.5);
    vec3 c = vec3(1.0, 1.0, 1.0);
    vec3 d = vec3(0.0, 0.33, 0.67);
    if(u_Palette > 1.0) {
      d = vec3(0.1, 0.3, 0.1);
    }
    if(u_Palette > 2.0) {
      d = vec3(0.4, 0.1, 0.0);
    }
    vec3 mystColor = palette(fract(u_Time / 100.0) + fs_Pos.x / 100.f, a, b, c, d);
    float t2 = smoothstep(0.7, 0.9, myst);
    t2 = t2 * u_Magic / 10.f;
    col = mix(col, mystColor, t2);

    float t3 = clamp(smoothstep(40.0, 50.0, length(fs_Pos)), 0.0, 1.0); // Distance fog
    vec3 skyCol = vec3(9.0 / 255.0, 11.0 / 255.0, 47.0 / 255.0);
    if(u_Day < 2.0) {
      skyCol = vec3(164.0 / 255.0, 233.0 / 255.0, 1.0);
    }
    out_Col = vec4(mix(col, skyCol, t3), 1.0);
}
