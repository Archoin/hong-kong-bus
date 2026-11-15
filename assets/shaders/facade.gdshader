shader_type spatial;
render_mode cull_disabled;
uniform vec4 paint : source_color = vec4(0.7,0.67,0.6,1.0);
uniform bool glass = false;
void fragment(){
 vec2 cell=fract(UV/vec2(3.05,3.0));
 vec2 aa=max(fwidth(UV/vec2(3.05,3.0)),vec2(.008));
 float window=smoothstep(.18-aa.x,.18+aa.x,cell.x)*(1.0-smoothstep(.82-aa.x,.82+aa.x,cell.x))*smoothstep(.24-aa.y,.24+aa.y,cell.y)*(1.0-smoothstep(.83-aa.y,.83+aa.y,cell.y));
 float bars=step(.46,cell.x)*step(cell.x,.50)+step(.50,cell.y)*step(cell.y,.53);
 float variation=fract(sin(dot(floor(UV/3.0),vec2(12.98,78.23)))*43758.54);
 vec3 dark=mix(vec3(.12,.23,.25),vec3(.35,.50,.49),variation);
 if(glass){window=step(.035,cell.x)*step(.03,cell.y);dark=mix(vec3(.20,.39,.46),vec3(.50,.68,.69),variation*.45);}
 vec3 surface=mix(paint.rgb,dark,window*(1.0-clamp(bars,0.0,1.0)*.6));
 float grime=.94+.06*sin(UV.x*.7+UV.y*.23);
 surface=mix(surface,mix(paint.rgb,dark,.42),smoothstep(100.0,350.0,length(VERTEX)));
 ALBEDO=surface*grime;
 ROUGHNESS=.88;
}
void light(){
 float n=dot(NORMAL,LIGHT);
 float shade=n>.55?1.0:(n>.0?.72:.48);
 DIFFUSE_LIGHT+=ALBEDO*LIGHT_COLOR*ATTENUATION*shade/3.14159265;
}
