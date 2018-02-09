Shader "Custom/DisneyBRDF" {
	Properties {
		_Color          ("Color", Color)                 = (1,1,1,1)
		_MainTex        ("Albedo (RGB)", 2D)             = "white" {}
        _BumpMap        ("Normal Map", 2D)               = "bump" {}
		_Subsurface     ("Subsurface", Range(0,1))       = 0.5
		_Metallic       ("Metallic", Range(0,1))         = 0.5
		_Specular       ("Specular", Range(0,1))         = 0.5
        _SpecColor      ("Specular Tint", Color)         = (1,1,1,1)
        _Roughness      ("Roughness", Range(0,1))        = 0.5
        _Anisotropic    ("Anisotropic", Range(0,1))      = 0.5
        _Sheen          ("Sheen", Range(0,1))            = 0.5
        _SheenTint      ("Sheen Tint", Range(0,1))       = 0.5
        _Clearcoat      ("Clearcoat", Range(0,1))        = 0.5
        _ClearcoatGloss ("Clearcoat Gloss", Range(0,1))  = 0.5
	}
	SubShader {
		Tags { "RenderType"="Opaque" }
		LOD 200
		
		CGPROGRAM
		#pragma surface surf DisneyBRDF fullforwardshadows
		#pragma target 5.0

		struct SurfaceOutputDisney
		{
		    float3 Albedo;
		    float3 Normal;      // tangent space normal, if written
		    float3 Emission;
		    float Alpha;        // alpha for transparencies
		};

		fixed4 _Color;
		sampler2D _MainTex;
        sampler2D _BumpMap;
		float _Subsurface;
		float _Metallic;
		float _Specular;
        float _Roughness;
        float _Anisotropic;
        float _Sheen;
        float _SheenTint;
        float _Clearcoat;
        float _ClearcoatGloss;

		struct Input {
			float2 uv_MainTex;
		};

		UNITY_INSTANCING_CBUFFER_START(Props)
		UNITY_INSTANCING_CBUFFER_END

        #define PI 3.14159265358979323846f

		float sqr(float x) { return x*x; }

		float SchlickFresnel(float u)
		{
		    float m = clamp(1 - u, 0, 1);
		    return pow(m, 5);
		}

		float GTR1(float NdotH, float a)
		{
		    if (a >= 1) return 1/PI;
		    float a2 = a * a;
		    float t = 1 + (a2 - 1) * NdotH * NdotH;
		    return (a2 - 1) / (PI * log(a2) * t);
		}

		float GTR2(float NdotH, float a)
		{
		    float a2 = a*a;
		    float t = 1 + (a2-1) * NdotH * NdotH;
		    return a2 / (3.14159265359 * t * t);
		}


        float GTR2_aniso(float NdotH, float HdotX, float HdotY, float ax, float ay)
        {
            return 1 / (3.14159265359 * ax*ay * sqr( sqr(HdotX/ax) + sqr(HdotY/ay) + NdotH*NdotH ));
        }

		float smithG_GGX(float NdotV, float alphaG)
		{
		    float a = alphaG * alphaG;
		    float b = NdotV * NdotV;
		    return 1 / (NdotV + sqrt(a + b - a*b));
		}

        float smithG_GGX_aniso(float NdotV, float VdotX, float VdotY, float ax, float ay)
        {
            return 1 / (NdotV + sqrt( sqr(VdotX*ax) + sqr(VdotY*ay) + sqr(NdotV) ));
        }

		inline void LightingDisneyBRDF_GI (
			SurfaceOutputDisney s,
			UnityGIInput data,
			inout UnityGI gi)
		{
			gi = UnityGlobalIllumination (data, 1.0, s.Normal);
		}

		inline fixed4 LightingDisneyBRDF (SurfaceOutputDisney s, float3 viewDir, UnityGI gi)
		{
			UnityLight light = gi.light;

			float nl = max(0.0f, dot(s.Normal, light.dir));
		    float nv = max(0.0f, dot(s.Normal, viewDir));

		    float3 h = normalize(light.dir + viewDir);
		    float nh = dot(s.Normal, h);
		    float lh = dot(light.dir, h);

            fixed3 epsilon1 = fixed3(1,0,0);
		    fixed3 tangent1 = normalize( cross(s.Normal, epsilon1) );
		    fixed3 bitangent1 = normalize( cross(s.Normal, tangent1 ));            

		    float albedoLuminosity = 0.3 * s.Albedo.r + 0.6 * s.Albedo.g  + 0.1 * s.Albedo.b; // luminance approx.
		    float3 albedoTint = albedoLuminosity > 0 ? s.Albedo/albedoLuminosity : float3(1,1,1); // normalize lum. to isolate hue+sat
            float3 tintChoice = lerp(float3(1,1,1), albedoTint, _SpecColor.rgb);

		    float3 specColor = lerp(_Specular * 0.08 * tintChoice, s.Albedo, _Metallic);
		    float sheenColor = lerp(float3(1,1,1), albedoTint, _SheenTint);

		    // Diffuse fresnel - go from 1 at normal incidence to .5 at grazing
		    // and lerp in diffuse retro-reflection based on roughness
		    float fresnelL = SchlickFresnel(nl);
            float fresnelV = SchlickFresnel(nv);
		    float fresnelDiffuse = 0.5 + 2 * lh*lh * _Roughness;
		    float diffuse = albedoTint * lerp(1.0, fresnelDiffuse, fresnelL) * lerp(1.0, fresnelDiffuse, fresnelV);

		    // Based on Hanrahan-Krueger brdf approximation of isotropic bssrdf
		    // 1.25 scale is used to (roughly) preserve albedo
		    // Fss90 used to "flatten" retroreflection based on roughness
            float fresnelSubsurfaceNinety = lh * lh * _Roughness;
		    float fresnelSubsurface = lerp(1.0, fresnelSubsurfaceNinety, fresnelL) 
                                    * lerp(1.0, fresnelSubsurfaceNinety, fresnelV);
		    float ss = 1.25 * (fresnelSubsurface * (1 / (nl + nv) - 0.5) + 0.5); // 

		    // specular
            //float roughg = sqr(s.Roughness*.5+.5);
            float aspect = sqrt( 1 - _Anisotropic * 0.9 );
            float ax = max(0.001, sqr(_Roughness) / aspect );
            float ay = max(0.001, sqr(_Roughness) * aspect);
		    float Ds = GTR2_aniso(nh, dot(h, tangent1), dot(h, bitangent1), ax, ay);//GTR2(nh,roughg);
		    float FH = SchlickFresnel(lh);
		    float3 Fs = lerp(specColor, float3(1,1,1), FH);
            float Gs;
            Gs  = smithG_GGX_aniso(nl, dot(light.dir, tangent1), dot(light.dir, bitangent1), ax, ay);
            Gs *= smithG_GGX_aniso(nv, dot(viewDir, tangent1), dot(viewDir, bitangent1), ax, ay);
            //float Gs = smithG_GGX(nl, roughg) * smithG_GGX(nl, roughg);

		    // sheen
		    float3 Fsheen = FH * _Sheen * sheenColor;

		    // clearcoat (ior = 1.5 -> F0 = 0.04)
		    float Dr = GTR1(nh, lerp(0.1, 0.001, _ClearcoatGloss));
		    float Fr = lerp(0.04, 1.0, FH);
		    float Gr = smithG_GGX(nl, 0.25) * smithG_GGX(nv, 0.25);

            float3 met = ((1/PI) * lerp(diffuse, ss, _Subsurface) * s.Albedo + Fsheen) * (1 - _Metallic);
            float3 terms = Gs*Fs*Ds; 
            float3 cc = 0.25 * _Clearcoat * Gr * Fr * Dr;

		    float3 finalColor = saturate(met + terms + cc);

			fixed4 c;
			c.rgb = finalColor;
			c.a = s.Alpha; 

			#ifdef UNITY_LIGHT_FUNCTION_APPLY_INDIRECT
				c.rgb += s.Albedo * gi.indirect.diffuse;
			#endif

			return c;
		} 

		void surf (Input IN, inout SurfaceOutputDisney o) {
			fixed4 c = tex2D (_MainTex, IN.uv_MainTex) * _Color;
			o.Albedo = c.rgb;
            o.Normal = UnpackNormal( tex2D ( _BumpMap, IN.uv_MainTex ) );
			o.Alpha = c.a;
		}
		ENDCG
	}
	FallBack "Diffuse"
}
