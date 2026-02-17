#version 330

// This shader is based on the basic lighting shader
// This only supports one light, which is directional, and it (of course) supports shadows

// Input vertex attributes (from vertex shader)
in vec3 fragPosition;
in vec2 fragTexCoord;
//in vec4 fragColor;
in vec3 fragNormal;

// Input uniform values
uniform sampler2D texture0;
uniform vec4 diffuse_color;

// Output fragment color
out vec4 finalColor;

// Input lighting values
uniform vec3 light_direction;
uniform vec4 light_color;
uniform vec4 ambient_color;
uniform vec3 view_position;

// Input shadowmapping values
uniform mat4 light_view_proj; // Light source view-projection matrix
uniform sampler2D depth_target;

uniform int depth_texture_size;

void main()
{

// ==================================================
// Base texture + vectors setup
// ==================================================

vec4 texelColor = texture(texture0, fragTexCoord);

vec3 lightDot = vec3(0.0);
vec3 normal   = normalize(fragNormal);
vec3 viewD    = normalize(view_position - fragPosition);
vec3 specular = vec3(0.0);

vec3 l = -light_direction;



// ==================================================
// Diffuse lighting (Lambert)
// แสงกระจายแบบ Lambert: ผิวที่หันเข้าหาแสงจะสว่างมากกว่า
// ==================================================

float NdotL = max(dot(normal, l), 0.0);
lightDot += light_color.rgb * NdotL;



// ==================================================
// Specular lighting (currently disabled)
// แสงสะท้อนเงาวาว (Specular) — ยังไม่ได้เปิดใช้
// ==================================================

float specCo = 0.0;
// if (NdotL > 0.0)
//     specCo = pow(max(0.0, dot(viewD, reflect(-l, normal))), 16.0);
// specular += specCo;



// ==================================================
// Combine base color (no shadow yet)
// รวมสีพื้นฐาน (ยังไม่คำนวณเงา)
// ==================================================

finalColor =
    texelColor *
    ((diffuse_color + vec4(specular, 1.0)) * vec4(lightDot, 1.0));



// ==================================================
// Shadow mapping: transform fragment into light space
// Shadow mapping: แปลงตำแหน่ง fragment ให้อยู่ในมุมมองของแสง
// ==================================================

vec4 fragPosLightSpace = light_view_proj * vec4(fragPosition, 1.0);

// perspective divide
fragPosLightSpace.xyz /= fragPosLightSpace.w;

// NDC [-1, 1] -> texture space [0, 1]
fragPosLightSpace.xyz = (fragPosLightSpace.xyz + 1.0) / 2.0;

vec2 sampleCoords = fragPosLightSpace.xy;
float curDepth    = fragPosLightSpace.z;



// ==================================================
// Shadow bias (reduce shadow acne)
// ค่า bias ของเงา (ลดปัญหา shadow acne)
// ==================================================

float bias =
    max(0.0002 * (1.0 - dot(normal, l)), 0.00002)
    + 0.00001;



// ==================================================
// PCF shadow sampling (3x3)
// ใช้ Percentage Closer Filtering ตรวจสอบเงาหลายจุดรอบพิกเซลเพื่อให้ขอบเงานุ่ม
// ==================================================

int shadowCounter = 0;
const int numSamples = 9;

vec2 texelSize = vec2(1.0 / float(depth_texture_size));

for (int x = -1; x <= 1; x++) {
    for (int y = -1; y <= 1; y++) {
        float sampleDepth =
            texture(depth_target, sampleCoords + texelSize * vec2(x, y)).r;

        if (curDepth - bias > sampleDepth) {
            shadowCounter++;
        }
    }
}



// ==================================================
// Dithered hard shadow (pixelized style)
// เงาแข็งที่ใช้ dither เพื่อให้แตกเป็นลายพิกเซล
// * This Cool Effect You Might Need to read more
// ==================================================

bool ditherX = mod(gl_FragCoord.x, 2.0) > 0.5;
bool ditherY = mod(gl_FragCoord.y, 2.0) > 0.5;

if (shadowCounter > 0 && (ditherY || ditherX)) {
    finalColor = vec4(0.0, 0.0, 0.0, 1.0);
}



// ==================================================
// Shadow blending + ambient light
// ==================================================

finalColor =
    mix(finalColor, vec4(0.0, 0.0, 0.0, 1.0),
        float(shadowCounter) / float(numSamples));

finalColor +=
    texelColor * (ambient_color / 10.0) * diffuse_color;



// ==================================================
// Gamma correction (linear -> sRGB)
// ==================================================

finalColor = pow(finalColor, vec4(1.0 / 2.2));

}