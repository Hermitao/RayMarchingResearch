// Created by Vinicius Krieger Granemann, 2022
//
// REFERENCE
// https://www.shadertoy.com/view/4tcGDr

const int MAX_MARCHING_STEPS = 255;
const float MIN_DIST = 0.01;
const float MAX_DIST = 1000.0;
const float EPSILON = 0.0001;


/**
 * Signed distance function for a cube centered at the origin
 * with dimensions specified by size.
 */
float boxSDF(vec3 p, vec3 size) {
    vec3 d = abs(p) - (size / 2.0);
    
    // Assuming p is inside the cube, how far is it from the surface?
    // Result will be negative or zero.
    float insideDistance = min(max(d.x, max(d.y, d.z)), 0.0);
    
    // Assuming p is outside the cube, how far is it from the surface?
    // Result will be positive or zero.
    float outsideDistance = length(max(d, 0.0));
    
    return insideDistance + outsideDistance;
}

float sphereSDF(vec3 p, float r, vec3 eye)
{
    vec3 dir = normalize(p - eye);
    return length(p - dir*r - eye);
}

float sceneSDF(vec3 eye)
{
    vec3 spherePos1 = vec3(5.0, 5.0, 5.0);
    float sphereRadius1 = 1.0;
    
    vec3 spherePos2 = vec3(5.5, 5.0, 5.0);
    float sphereRadius2 = 0.75;
    
    return min(sphereSDF(spherePos1, sphereRadius1, eye), sphereSDF(spherePos2, sphereRadius2, eye));
    
    //return boxSDF(eye, vec3(1.0, 0.5, 1.0)) * -1.0;
}

float shortestDistanceToSurface(vec3 eye, vec3 marchingDir, float start, float end)
{
    float depth = start;
    for (int i = 0; i < MAX_MARCHING_STEPS; ++i)
    {
        float dist = sceneSDF(eye + depth * marchingDir);
        if (dist < EPSILON)
        {
            return depth;
        }
        
        depth += dist;
        
        if (depth > MAX_DIST)
        {
            return end;
        }
    }
    return end;
}

vec3 rayDirection(float fov, vec2 size, vec2 fragCoord)
{
    vec2 xy = fragCoord - size / 2.0;
    float z = size.y / tan(radians(fov) / 2.0);
    return normalize(vec3(xy, -z));
}

/**
 * Return a transform matrix that will transform a ray from view space
 * to world coordinates, given the eye point, the camera target, and an up vector.
 *
 * This assumes that the center of the camera is aligned with the negative z axis in
 * view space when calculating the ray marching direction. See rayDirection.
 */
mat3 viewMatrix(vec3 eye, vec3 center, vec3 up) {
    // Based on gluLookAt man page
    vec3 f = normalize(center - eye);
    vec3 s = normalize(cross(f, up));
    vec3 u = cross(s, f);
    return mat3(s, u, -f);
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec3 viewDir = rayDirection(45.0, iResolution.xy, fragCoord);
    vec3 eye = vec3(sin(iTime * 0.32) * 9.0, 0.0 * cos(iTime * 0.633), 0.0);
    
    mat3 viewToWorld = viewMatrix(eye, vec3(5.0, 5.0, 5.0), vec3(0.0, 1.0, 0.0));
    vec3 worldDir = viewToWorld * viewDir;

    float dist = shortestDistanceToSurface(eye, worldDir, MIN_DIST, MAX_DIST);
    if (dist > MAX_DIST - EPSILON)
    {
        fragColor = vec4(0.0, 0.0, 0.0, 0.0);
        return;
    }
    
    float ndc = dist * 2.0 - 1.0;
    float far = 200.0;
    float near = MIN_DIST;
    float linearDepth = (2.0 * near * far) / (far + near - ndc * (far - near));
    
    float colLerper = 50.0;
    vec3 col = vec3(dist / colLerper);

    fragColor = vec4(col,1.0);
}