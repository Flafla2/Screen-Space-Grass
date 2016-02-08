Shader "Hidden/SSG"
{
	Properties
	{
		_MainTex("", any) = "" {}
	}

	SubShader
	{
		// No culling or depth
		Cull Off ZWrite Off ZTest Always

		Pass
		{
			CGPROGRAM
			#pragma target 3.0
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
				float2 wpos : TEXCOORD0; // windowspace position / uv (range 0 - 1)
				float4 pos : SV_POSITION; // viewspace position - NOT worldspace!!
			};
			
			uniform sampler2D _MainTex;
			uniform sampler2D _CameraDepthTexture;
			// Rendered depth of the grass without any occluding elements.  This is compared to the depth
			// buffer to see if anything is in front of the grass.  Normally we would use the stencil buffer
			// but we can't because Unity takes control of stenciling in deferred rendering.
			uniform sampler2D _ReferenceDepth;
			// Normalized up vector of the camera with respect to viewspace.  In other words, this accounts
			// for the roll of the camera.
			uniform float4 up_vec;

			v2f vert(appdata v)
			{
				v2f o;
				o.pos = mul(UNITY_MATRIX_MVP, v.vertex);
				o.wpos = v.uv;
				return o;
			}

			// Transfers val from the range val0->val1 to the range res0->res1
			float blend(float val, float val0, float val1, float res0, float res1) {
				if (val <= val0)
					return res0;
				if (val >= val1)
					return res1;

				return res0 + (val - val0) * (res1 - res0) / (val1 - val0);
			}

			fixed4 frag (v2f i) : SV_Target
			{
				float2 dpos = i.wpos;
#if UNITY_UV_STARTS_AT_TOP
				dpos.y = 1 - dpos.y;
#endif
				float depth = LinearEyeDepth(tex2D(_CameraDepthTexture, dpos).r);
				fixed4 backcolor = tex2D(_MainTex, i.wpos);

				float depth_ref = LinearEyeDepth(tex2D(_ReferenceDepth, dpos).r);
				if (depth < depth_ref)
					return backcolor;

				bool isgreen =	backcolor.g > backcolor.r + 0.01 &&
								backcolor.g > backcolor.b + 0.01;

				if (isgreen) {
					fixed4 color = fixed4(0, 0, 0, 0);

					float2 p = i.wpos;

					float d = blend(depth, 0, 500, 100, 500);
					float dclose = blend(depth, 0, 20, 30, 1);

					d *= dclose;

					p.y += p.x * 1009 + p.x * 1259 + p.x * 2713;
					p.y += _Time.y * 0.004; // wind

					float yoffset = frac(p.y * d) / d;
					float2 uvoffset = i.wpos.xy - up_vec.xy * yoffset;
#if UNITY_UV_STARTS_AT_TOP
					float2 uvoffset_d = dpos.xy + up_vec.xy * yoffset;
#else
					float2 uvoffset_d = uvoffset;
#endif


					color = tex2D(_MainTex, uvoffset);
					float depth2 = LinearEyeDepth(tex2D(_CameraDepthTexture, uvoffset_d).r);
					if (depth2 < depth)
						return backcolor;
					return lerp(backcolor, color, saturate(1 - yoffset * d / 3.8));
				}

				return backcolor;
			}
			ENDCG
		}
	}

		Fallback Off
}
