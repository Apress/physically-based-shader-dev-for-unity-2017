#ifndef UNITY_OVERWRITE_LIGHTING_INCLUDED
#define UNITY_OVERWRITE_LIGHTING_INCLUDED

#include "UnityStandardBRDF.cginc"

#define UNITY_BRDF_PBS BRDF1_Unity_PBSC


// CUSTOM

float sqr(float value) 
{
    return value * value;
}

float SchlickFresnel(float value)
{
    float m = clamp(1 - value, 0, 1);
    return pow(m, 5);
}

float G1 (float k, float x)
{
        return x / (x * (1 - k) + k);
}

//Disney Diffuse 
inline float3 DisneyDiff(float3 albedo, float NdotL, float NdotV, float LdotH, float roughness){
    float albedoLuminosity = 0.3 * albedo.r 
                            + 0.6 * albedo.g  
                            + 0.1 * albedo.b; // luminance approx.

    float3 albedoTint = albedoLuminosity > 0 ? 
                        albedo/albedoLuminosity : 
                        float3(1,1,1); // normalize lum. to isolate hue+sat
    
    float fresnelL = SchlickFresnel(NdotL);
    float fresnelV = SchlickFresnel(NdotV);

    float fresnelDiffuse = 0.5 + 2 * sqr(LdotH) * roughness;

    float diffuse = albedoTint 
                    * lerp(1.0, fresnelDiffuse, fresnelL) 
                    * lerp(1.0, fresnelDiffuse, fresnelV);

    float fresnelSubsurface90 = sqr(LdotH) * roughness;

    float fresnelSubsurface = lerp(1.0, fresnelSubsurface90, fresnelL) 
                            * lerp(1.0, fresnelSubsurface90, fresnelV);

    float ss = 1.25 * (fresnelSubsurface * (1 / (NdotL + NdotV) - 0.5) + 0.5);

    return saturate(lerp(diffuse, ss, _Subsurface) * (1/UNITY_PI) * albedo);
}


float3 FresnelSchlickFrostbite (float3 F0, float F90, float u)
{
    return F0 + (F90 - F0) * pow (1 - u, 5) ;
}

inline float DisneyFrostbiteDiff(float NdotL, float NdotV
                                , float LdotH, float roughness)
{
    float energyBias = lerp (0, 0.5, roughness) ;
    float energyFactor = lerp (1.0, 1.0/1.51, roughness ) ;
    float Fd90 = energyBias + 2.0 * sqr(LdotH) * roughness ;
    float3 F0 = float3 (1 , 1 , 1) ;
    float lightScatter = FresnelSchlickFrostbite (F0, Fd90, NdotL).r ;
    float viewScatter = FresnelSchlickFrostbite (F0, Fd90, NdotV).r ;
    return lightScatter * viewScatter * energyFactor;
}

//Cook-Torrance 
inline float3 CookTorranceSpec(float NdotL, float LdotH, float NdotH, float NdotV, float roughness, float F0){
    float alpha = sqr(roughness);
    float F, D, G;

    // D
    float alphaSqr = sqr(alpha);
    float denom = sqr(NdotH) * (alphaSqr - 1.0) + 1.0f;
    D = alphaSqr / (UNITY_PI * sqr(denom));

    // F
    float LdotH5 = SchlickFresnel(LdotH);
    F = F0 + (1.0 - F0) * LdotH5;

    // G
    float r = _Roughness + 1;
    float k = sqr(r) / 8;
    float g1L = G1(k, NdotL);
    float g1V = G1(k, NdotV);
    G = g1L * g1V;
    
    float specular = NdotL * D * F * G;
    return specular;
}


// BUILTIN
half4 BRDF1_Unity_PBSC (half3 diffColor, half3 specColor, half oneMinusReflectivity, half smoothness,
    half3 normal, half3 viewDir,
    UnityLight light, UnityIndirect gi)
{
    half3 halfDir = Unity_SafeNormalize (light.dir + viewDir);

#define UNITY_HANDLE_CORRECTLY_NEGATIVE_NDOTV 0

#if UNITY_HANDLE_CORRECTLY_NEGATIVE_NDOTV
    half shiftAmount = dot(normal, viewDir);
    normal = shiftAmount < 0.0f ? normal + viewDir * (-shiftAmount + 1e-5f) : normal;
    half nv = saturate(dot(normal, viewDir)); // TODO: this saturate should no be necessary here
#else
    half nv = abs(dot(normal, viewDir));    // This abs allow to limit artifact
#endif
    
    float VdotH = saturate( dot( viewDir, halfDir ));
    float LdotH = saturate( dot( light.dir, halfDir ));

    half nl = saturate(dot(normal, light.dir));
    half nh = saturate(dot(normal, halfDir));

    half lv = saturate(dot(light.dir, viewDir));
    half lh = saturate(dot(light.dir, halfDir));

    float3 diffuseTerm = DisneyDiff(diffColor, nl,  nv, LdotH, _Roughness);
    float3 specularTerm = CookTorranceSpec(nl, LdotH, nh, nv, _Roughness, _SpecColor);

#if defined(_SPECULARHIGHLIGHTS_OFF)
    specularTerm = 0.0;
#endif

    specularTerm *= any(specColor) ? 1.0 : 0.0;

    half grazingTerm = saturate(smoothness + (1-oneMinusReflectivity));
    half3 color =   diffColor * (gi.diffuse + light.color * diffuseTerm)
                    + specularTerm * light.color //* FresnelTerm (specColor, lh)
                    + gi.specular * FresnelLerp (specColor, grazingTerm, nv);

    return half4(color, 1);
}

half4 CustomDisneyCookTorrance_PBS ( half3 diffColor, half3 specColor, half oneMinusReflectivity
                                   , half smoothness, half3 normal, half3 viewDir
                                   , UnityLight light, UnityIndirect gi)
{
    viewDir = Unity_SafeNormalize ( viewDir );
    float3 lightDir = Unity_SafeNormalize ( light.dir );
    
    float3 halfV = Unity_SafeNormalize(lightDir+viewDir);
    float NdotL = saturate( dot( normal, lightDir ));
    float NdotH = saturate( dot( normal, halfV ));
    float NdotV = saturate( dot( normal, viewDir ));
    float VdotH = saturate( dot( viewDir, halfV ));
    float LdotH = saturate( dot( lightDir, halfV ));

    float3 diff = DisneyDiff(diffColor, NdotL,  NdotV, LdotH, _Roughness);
    float3 spec = CookTorranceSpec(NdotL, LdotH, NdotH, NdotV, _Roughness, _SpecColor);
    float3 firstLayer = ( diff + spec * _SpecColor) * light.color;
    float4 c = float4(firstLayer, 1);

    return c;
}


#endif