#version 330

// Input vertex attributes (from vertex shader)
in vec2 fragTexCoord;
in vec4 fragColor;

// Output fragment color
out vec4 finalColor;

// Custom uniform input
uniform float seconds;

void main()
{
    // สร้าง Effect แบบคลื่นแม่สี
    float r = abs(sin(seconds + fragTexCoord.x));
    float g = abs(sin(seconds + fragTexCoord.y + 2.0));
    float b = abs(sin(seconds + fragTexCoord.x + fragTexCoord.y + 4.0));

    finalColor = vec4(r, g, b, 1.0) * fragColor;
}
