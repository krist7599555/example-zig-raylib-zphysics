#version 330

in vec2 fragTexCoord;
out vec4 finalColor;

uniform sampler2D depthTex;

void main() {
    float d = texture(depthTex, fragTexCoord).r;
    float d2 = fract(d * 200.0);
    float wave = sin(d * 2000.0 * 3.14159);
    wave = wave * 0.5 + 0.5;
    finalColor = vec4(wave, wave, wave, 1.0);
}
