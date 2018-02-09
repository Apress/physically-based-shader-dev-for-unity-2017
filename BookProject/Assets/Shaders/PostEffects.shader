Shader "Hidden/PostEffects"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
        _ToneMapperExposure ("Tone Mapper Exposure", Range(0.0, 10.0)) = 2 
	}
	SubShader
	{
		Pass
		{
			name "Invert"
			Cull Off ZWrite Off ZTest Always Lighting Off
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			
			#include "UnityCG.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2f
			{
				float2 uv : TEXCOORD0;
				float4 vertex : SV_POSITION;
			};

			v2f vert (appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = v.uv;
				return o;
			}
			
			sampler2D _MainTex;

			fixed4 frag (v2f i) : SV_Target
			{
				fixed4 col = tex2D(_MainTex, i.uv);
				// just invert the colors
				col = 1 - col;
				return col;
			}
			ENDCG
		}
		Pass
		{
			name "DebugDepth"
			Cull Off ZWrite Off ZTest Always Lighting Off
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			
			#include "UnityCG.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2f
			{
				float2 uv : TEXCOORD0;
				float4 vertex : SV_POSITION;
			};

			v2f vert (appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = v.uv;
				return o;
			}
			
			sampler2D _CameraDepthTexture;

			fixed4 frag (v2f i) : SV_Target
			{
				fixed depth = UNITY_SAMPLE_DEPTH( tex2D(_CameraDepthTexture, i.uv) );
				fixed4 col = fixed4(depth,depth,depth, 1.0);
				return col;
			}
			ENDCG
		}
        Pass
		{
			name "Linear"
			Cull Off ZWrite Off ZTest Always Lighting Off
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			
			#include "UnityCG.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2f
			{
				float2 uv : TEXCOORD0;
				float4 vertex : SV_POSITION;
			};

			v2f vert (appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = v.uv;
				return o;
			}

			sampler2D _MainTex;

			fixed4 frag (v2f i) : SV_Target
			{
				fixed4 col = pow(tex2D( _MainTex, i.uv ), 2.2);
                col = 1 - col;
				return pow(col, 1/2.2);
			}
			ENDCG
		}
        Pass
		{
			name "ToneMapping"
			Cull Off ZWrite Off ZTest Always Lighting Off
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			
			#include "UnityCG.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2f
			{
				float2 uv : TEXCOORD0;
				float4 vertex : SV_POSITION;
			};

			v2f vert (appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = v.uv;
				return o;
			}
			
			sampler2D _MainTex;
            float _ToneMapperExposure;

            float3 hableOperator(float3 col)
            {
                float A = 0.15;
                float B = 0.50;
                float C = 0.10;
                float D = 0.20;
                float E = 0.02;
                float F = 0.30;
                return ((col * (col * A + B * C) + D * E) / (col * (col * A + B) + D * F)) - E / F;
            }

			fixed4 frag (v2f i) : SV_Target
			{
				float4 col = tex2D(_MainTex, i.uv);
                float3 toneMapped = col * _ToneMapperExposure * 4;
                toneMapped = hableOperator(toneMapped) / hableOperator(11.2);
		     	return float4(toneMapped, 1.0); 
			}
			ENDCG 
		}
	}
}
