#version 330 core
layout (location = 0) in vec4 vertex;
out vec2 TexCoords;

uniform mat4 projection;
uniform float depth;

void main(){
    gl_Position = projection * vec4(vertex.xy, 0.0, 1.0);
    gl_Position.z = depth;
    TexCoords = vertex.zw;
}