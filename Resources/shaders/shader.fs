
extern Image tex;

vec4 effect(vec4 color, Image texture, vec2 texture_coords,
            vec2 screen_coords) {
  // vec4 pixel = Texel(texture, texture_coords );//This is the current pixel
  // color
  vec4 c = vec4(1, 1, 1, 1);
  vec4 data = Texel(tex, (screen_coords / vec2(love_ScreenSize.xy)));
  c.r=data.r;
  c.g=data.g;
  c.b=data.b;
  c.a = data.a;
  return c;
}