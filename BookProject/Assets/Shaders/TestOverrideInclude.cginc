#ifndef UNITY_OVERWRITE_LIGHTING_INCLUDED
#define UNITY_OVERWRITE_LIGHTING_INCLUDED

#include "UnityStandardBRDF.cginc"

#define UNITY_BRDF_PBS TestBRDF_PBS

half4 TestBRDF_PBS ( half3 diffColor, half3 specColor, half oneMinusReflectivity
               , half smoothness, half3 normal, half3 viewDir
               , UnityLight light, UnityIndirect gi)
{
    return half4(1, 0, 0, 1);
}

#endif