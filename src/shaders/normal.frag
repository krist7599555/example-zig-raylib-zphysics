#version 330

// Input fragment attributes (from vertex shader)
in vec2 fragTexCoord;
in vec4 fragColor;
in vec3 fragNormal;
in vec3 fragWorldPos;

// Output fragment color
out vec4 finalColor;

void main()
{
    // คำนวณ Normal จากความต่างของตำแหน่งพิกัด (Partial Derivatives)
    // วิธีนี้ทำงานได้แม้โมเดลจะไม่มีข้อมูล Normal มาให้ (เช่น drawCylinder)
    vec3 calculatedNormal = normalize(cross(dFdx(fragWorldPos), dFdy(fragWorldPos)));

    // Mapping [-1, 1] -> [0, 1]
    vec3 color = calculatedNormal * 0.5 + 0.5;
    
    finalColor = vec4(color, 1.0);
}
