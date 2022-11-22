// Created by Vinicius Krieger Granemann, 2022
//
// REFERENCE
// https://www.shadertoy.com/view/4tcGDr
// https://www.youtube.com/watch?v=Cp5WWtMoeKg
// https://github.com/SebLague/Ray-Marching
// https://iquilezles.org/articles/distfunctions/
// http://blog.hvidtfeldts.net/index.php/2011/09/distance-estimated-3d-fractals-v-the-mandelbulb-different-de-approximations/


const int MAX_MARCHING_STEPS = 20;
const float MIN_DIST = 0.01;
const float MAX_DIST = 1000.0;
const float EPSILON = 0.0001;
float Power = 9.0;
const int Iterations = 15;
const float Bailout = 2.0;


/**
 * Constructive solid geometry intersection operation on SDF-calculated distances.
 */
float intersectSDF(float distA, float distB) {
    return max(distA, distB);
}

/**
 * Constructive solid geometry union operation on SDF-calculated distances.
 */
float unionSmoothSDF(float distA, float distB, float k) {
    float h = max( k-abs(distA-distB) , 0.0 ) / k;
    return min(distA, distB) - h*h*h*k*1.0/6.0;
}

float unionSDF(float distA, float distB) {
    return min(distA, distB);
}


/**
 * Constructive solid geometry difference operation on SDF-calculated distances.
 */
float differenceSDF(float distA, float distB) {
    return max(distA, -distB);
}

float DE(vec3 pos) {
	vec3 z = pos;
	float dr = 1.0;
	float r = 0.0;
	for (int i = 0; i < Iterations ; i++) {
		r = length(z);
		if (r>Bailout) break;
		
		// convert to polar coordinates
		float theta = acos(z.z/r);
		float phi = atan(z.y,z.x);
		dr =  pow( r, Power-1.0)*Power*dr + 1.0;
		
		// scale and rotate the point
		float zr = pow( r,Power);
		theta = theta*Power;
		phi = phi*Power;
		
		// convert back to cartesian coordinates
		z = zr*vec3(sin(theta)*cos(phi), sin(phi)*sin(theta), cos(theta));
		z+=pos;
	}
	return 0.5*log(r)*r/dr;
}


float sdBox( vec3 p, vec3 b )
{
  vec3 q = abs(p) - b;
  return length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0);
}


float sphereSDF(vec3 p, float r, vec3 eye)
{
    vec3 dir = normalize(p - eye);
    return length(p - dir*r - eye);
}

float sphereSDFOrigin(vec3 p, float r)
{
    return length(p)-r;
}

float sceneSDF(vec3 eye, vec3 worldDir)
{
    float sphere1Radius = 1.0;
    
    float sphere2Radius = 0.75;
    vec3 sphere2Offset = vec3(sin(iTime * 0.4838) * 1.2, sin(iTime * 0.3234) *2.2, sin(iTime) * 3.0);
    
    float balls = sphereSDFOrigin(eye, sphere1Radius);
    balls = unionSmoothSDF(balls, sphereSDFOrigin(eye + sphere2Offset, sphere2Radius), 2.0);

    float box = sdBox(eye + vec3(0.0, 0.0, sin(iTime) * 3.0), vec3(0.5, 0.5, 0.5));

    //return min(sphereSDF(spherePos1, sphereRadius1, eye), sphereSDF(spherePos2, sphereRadius2, eye));
    //return unionSmoothSDF(balls, box, 2.0);
    
    return DE(worldDir + eye);

    //return boxSDF(eye, vec3(1.0, 0.5, 1.0)) * -1.0;
}

vec3 estimateNormal(vec3 p, vec3 worldDir) {
    return normalize(vec3(
        sceneSDF( vec3(p.x + EPSILON, p.y, p.z) - sceneSDF( vec3(p.x - EPSILON, p.y, p.z), worldDir ) , worldDir),
        sceneSDF( vec3(p.x, p.y + EPSILON, p.z) - sceneSDF( vec3(p.x, p.y - EPSILON, p.z), worldDir ), worldDir),
        sceneSDF( vec3(p.x, p.y, p.z + EPSILON) - sceneSDF(vec3(p.x, p.y, p.z - EPSILON), worldDir ), worldDir)
    ));
}


vec2 shortestDistanceToSurface(vec3 eye, vec3 marchingDir, float start, float end)
{
    float depth = start;
    for (int i = 0; i < MAX_MARCHING_STEPS; ++i)
    {
        float dist = sceneSDF(eye + depth * marchingDir, marchingDir);
        if (dist < EPSILON)
        {
            return vec2(depth, float(i));
        }
        
        depth += dist;
        
        if (depth > MAX_DIST)
        {
            return vec2(end, -1.0);
        }
    }
    return vec2(end, -1.0);
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
    Power = ((sin(iTime * 0.25) * 0.5 + 0.5) + 1.0) * 8.0;
    //Power = 8.0;
    //Power = iTime * -5.0;
    vec3 viewDir = rayDirection(45.0, iResolution.xy, fragCoord);
    vec3 eye = vec3(sin(iTime * 0.1) * 12.0, sin(iTime * 0.1) * 12.0, 2.0);
    
    mat3 viewToWorld = viewMatrix(eye, vec3(0.0, 0.0, 0.0), vec3(0.0, 1.0, 0.0));
    vec3 worldDir = viewToWorld * viewDir;

    vec2 data = shortestDistanceToSurface(eye, worldDir, MIN_DIST, MAX_DIST);
    float dist = data.x;
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
    
    vec3 p = eye + dist * worldDir;
    vec3 K_a = (estimateNormal(p, worldDir) + vec3(1.0)) / 2.0;

    float outline = data.y / 255.0 * 255.0;
    

    fragColor = vec4(K_a,1.0);

}