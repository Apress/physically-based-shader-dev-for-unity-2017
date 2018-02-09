Shader "Custom/AshikhminShirley" {
	Properties {
		_Color ("Color", Color) = (1,1,1,1)
		_MainTex ("Albedo (RGB)", 2D) = "white" {}
        _SpecColor ("Specular Color", Color) = (1,1,1,1) 
        _Rs ("Rs", Range(0, 1)) = 0.1
        _Rd ("Rd", Range(0, 1)) = 1
		_nu ("nu", Range(1, 1000)) = 100
        _nv ("nv", Range(1, 1000)) = 100
	}
	SubShader {
		Tags { "RenderType"="Opaque" }
		LOD 200
		
		CGPROGRAM
		#pragma surface surf AshikhminShirley fullforwardshadows
		#pragma target 3.0

		sampler2D _MainTex;

		struct Input {
			float2 uv_MainTex;
		};

		float4 _Color;
        float _Rd;
		float _Rs;
        float _nu;
        float _nv;

        #define PI 3.14159265358979323846f

        inline void LightingAshikhminShirley_GI (
			SurfaceOutput s,
			UnityGIInput data,
			inout UnityGI gi)
		{
			gi = UnityGlobalIllumination (data, 1.0, s.Normal);
		}

        float Fresnel(float f0, float u)
        {
            // from Schlick
            return f0 + (1-f0) * pow(1-u, 5);
        }


        float sqr( float x )
        {
            return x*x;
        }

        inline float4 LightingAshikhminShirley  (SurfaceOutput s, half3 viewDir, UnityGI gi)
        {
            UnityLight light = gi.light;

			viewDir = normalize ( viewDir );
			float3 lightDir = normalize ( light.dir );
			s.Normal = normalize( s.Normal );

			float3 halfV = normalize(lightDir+viewDir);

            float3 epsilon1 = float3(1,0,0);
		    float3 tangent1 = normalize( cross(s.Normal, epsilon1) );
		    float3 bitangent1 = normalize( cross(s.Normal, tangent1 ));

            float HdotV = saturate( dot(halfV, viewDir) );
            float HdotX = saturate( dot(halfV, tangent1) );
            float HdotY = saturate( dot(halfV, bitangent1) );
            float NdotH = saturate( dot(s.Normal, halfV) );
            float NdotV = saturate( dot(s.Normal, viewDir) );
            float NdotL = saturate( dot(s.Normal, lightDir) );
            
            float nl = max(0.0f, dot(s.Normal, light.dir));
			float3 diff = nl * s.Albedo.rgb * light.color;

            float F = Fresnel(_Rs, HdotV);
            float norm_s = sqrt((_nu + 1) * (_nu + 1)) / (8 * PI);
            float n = _nu;
            float rho_s = norm_s * F * pow(max(NdotH, 0), n) / (HdotV * max(NdotV, NdotL));

            float rho_d = 28 / (23 * PI) * _Rd * (1 - pow(1 - NdotV/2, 5)) * (1 - pow( 1-NdotL / 2, 5));
            float3 spec = (rho_s + rho_d) * _SpecColor * light.color;

			float3 firstLayer = diff + spec;

            #ifdef UNITY_LIGHT_FUNCTION_APPLY_INDIRECT
				firstLayer.rgb += s.Albedo * gi.indirect.diffuse;
			#endif

			return float4(saturate(firstLayer), 1);
		}
        
		UNITY_INSTANCING_CBUFFER_START(Props)
		UNITY_INSTANCING_CBUFFER_END

		void surf (Input IN, inout SurfaceOutput o) {
			// Albedo comes from a texture tinted by color
			float4 c = tex2D (_MainTex, IN.uv_MainTex) * _Color;
			o.Albedo = c.rgb;
			o.Alpha = c.a;
		}
		ENDCG
	}
	FallBack "Diffuse"
}
