Shader "Custom/TranslucencyShader" {
		Properties {
		_MainTex ("Base (RGB)", 2D) = "white" {}
		_ColorTint ("Color", Color) = (1,1,1,1)
		_SpecColor ("Specular Color", Color) = (1,1,1,1)
		_BumpMap ("Normal Map", 2D) = "bump" {}
		_Roughness ("Roughness", Range(0,1)) = 0.5
        _Subsurface ("Subsurface", Range(0,1)) = 0.5
        //Translucency
        _Thickness ("Thickness (R)", 2D) = "white" {}
		_Power ("Power Factor", Range(0.1, 10.0)) = 1.0
		_Distortion ("Distortion", Range(0.0, 10.0)) = 0.0
		_Scale ("Scale Factor", Range(0.0, 10.0)) = 0.5
		_SubsurfaceColor ("Subsurface Color", Color) = (1, 1, 1, 1)
        _Ambient ("Ambient", Color) = (1, 1, 1, 1)
	}
	SubShader {
		Tags { "RenderType"="Opaque" }
		LOD 200
		
		CGPROGRAM
		#pragma surface surf CookTorrance fullforwardshadows
		#pragma target 3.0

		struct Input {
			float2 uv_MainTex;
		};

		sampler2D _MainTex;
        sampler2D _BumpMap;
		float _Roughness;
        float _Subsurface;
		float4 _ColorTint;
        //Translucency
        sampler2D _Thickness;
        float _Power;
        float _Distortion;
        float _Scale;
        float4 _SubsurfaceColor;

        #define PI 3.14159265358979323846f

		UNITY_INSTANCING_CBUFFER_START(Props)
		UNITY_INSTANCING_CBUFFER_END

        struct SurfaceOutputCustom {
			float3 Albedo;
			float3 Normal;
			float3 Emission;
            float Thickness;
			float Alpha;
		};

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

            return saturate(lerp(diffuse, ss, _Subsurface) * (1/PI) * albedo);
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
			D = alphaSqr / (PI * sqr(denom));

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

        inline void LightingCookTorrance_GI (
			SurfaceOutputCustom s,
			UnityGIInput data,
			inout UnityGI gi)
		{
			gi = UnityGlobalIllumination (data, 1.0, s.Normal);
		}

        inline float4 LightingCookTorrance (SurfaceOutputCustom s, float3 viewDir, UnityGI gi){
            UnityLight light = gi.light;

			viewDir = normalize ( viewDir );
			float3 lightDir = normalize ( light.dir );
			s.Normal = normalize( s.Normal );
			
			float3 halfV = normalize(lightDir+viewDir);
			float NdotL = saturate( dot( s.Normal, lightDir ));
			float NdotH = saturate( dot( s.Normal, halfV ));
			float NdotV = saturate( dot( s.Normal, viewDir ));
			float VdotH = saturate( dot( viewDir, halfV ));
            float LdotH = saturate( dot( lightDir, halfV ));

            //Translucency

            float3 translucencyLightDir = lightDir + s.Normal * _Distortion;
            float translucencyDot = pow(saturate(dot(viewDir, -translucencyLightDir)), _Power) * _Scale;
            float3 translucency = translucencyDot * s.Thickness * _SubsurfaceColor;

			float3 diff = DisneyDiff(s.Albedo, NdotL,  NdotV, LdotH, _Roughness) + translucency;
			float3 spec = CookTorranceSpec(NdotL, LdotH, NdotH, NdotV, _Roughness, _SpecColor);
			float3 firstLayer = ( diff + spec * _SpecColor) * light.color;
            float4 c = float4(firstLayer, s.Alpha);

			#ifdef UNITY_LIGHT_FUNCTION_APPLY_INDIRECT
				c.rgb += s.Albedo * gi.indirect.diffuse;
			#endif
			
            return c;
		}

		void surf (Input IN, inout SurfaceOutputCustom o) {
			float4 c = tex2D (_MainTex, IN.uv_MainTex) * _ColorTint;
			o.Albedo = c.rgb;
            o.Thickness = tex2D (_Thickness, IN.uv_MainTex).r;
			o.Normal = UnpackNormal( tex2D ( _BumpMap, IN.uv_MainTex ) );
			o.Alpha = c.a;
		}
		ENDCG
	}
	FallBack "Diffuse"
}
