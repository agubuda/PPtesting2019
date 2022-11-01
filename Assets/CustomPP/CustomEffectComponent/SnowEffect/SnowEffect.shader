Shader "Hidden/Custom/SnowEffect"
{
    Properties
    {
        _MainTex ("Main Texture", 2D) = "white" { }
        _EffectTex ("Effect Texture", 2d) = "white" { }
        _FlowMap ("FlowMap", 2d) = "white" { }
        _FlowMapIntensity ("Flow Map Intensity", float) = 0.01
        _MaskMap ("MaskMap", 2d) = "white" { }
        _MaskController ("mask controller", vector) = (0, 1, 0, 1)
        _FogDensity ("Fog density", float) = 1
        _SnowSpeed ("Snow speed", float) = 5
        _FogSpeed ("Fog speed", float) = 3
    }
    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" }
        
        Pass
        {
            HLSLPROGRAM
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"
            
            #pragma vertex vert
            #pragma fragment frag
            
            TEXTURE2D(_MainTex);
            TEXTURE2D(_EffectTex);
            TEXTURE2D(_MaskMap);
            TEXTURE2D(_FlowMap);
            SAMPLER(sampler_MainTex);
            SAMPLER(sampler_EffectTex);
            SAMPLER(sampler_MaskMap);
            SAMPLER(sampler_FlowMap);

            TEXTURE2D_X_FLOAT(_CameraDepthAttachment);
            TEXTURE2D(_CameraColorTexture);
            SAMPLER(sampler_CameraDepthAttachment);
            SAMPLER(sampler_CameraColorTexture);
            // SAMPLER()
            
            float _Intensity, _SnowSpeed, _FogSpeed, _FlowMapIntensity;
            half4 _MaskController;
            float4 _OverlayColor;
            float4 _EffectTex_ST;
            float4 _MaskMap_ST;
            float _FogDensity;
            // float4 _CameraDepthAttachment_ST;
            
            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
                uint vertexID : SV_VERTEXID;
            };

            struct Varyings
            {
                float2 uv : TEXCOORD0;
                float2 uv2 : TEXCOORD1;
                float4 positionSS : TEXCOORD2;
                float4 vertex : SV_POSITION;
                float2 scrPos : TEXCOORD3;
                UNITY_VERTEX_OUTPUT_STEREO
            };
            
            
            Varyings vert(Attributes input)
            {
                Varyings output = (Varyings)0;
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

                VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
                output.vertex = vertexInput.positionCS;
                output.uv = input.uv;
                output.positionSS = ComputeScreenPos(vertexInput.positionCS);
                output.scrPos = output.positionSS.xy / output.positionSS.w;
                output.uv2 = output.scrPos;
                output.uv = output.scrPos;

                return output;
            }
            
            float4 frag(Varyings input) : SV_Target
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
                

                // int2 positionSS  = input.uv * _ScreenSize.xy;

                // input.uv.x *= unity_DeltaTime.w;
                float4 color = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv);
                float4 color_temp = SAMPLE_TEXTURE2D(_CameraColorTexture, sampler_CameraColorTexture, input.scrPos);

                float4 FlowMap = SAMPLE_TEXTURE2D(_FlowMap, sampler_FlowMap, input.scrPos);
                // input.scrPos += FlowMap.xy * _Time.y *0.1;
                float4 test = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.scrPos);



                input.uv2 = (input.uv2.xy * _MaskMap_ST.xy * 1 + _EffectTex_ST.w + (_EffectTex_ST.zw + frac(_Time.y / _SnowSpeed)));

                float4 Mask = SAMPLE_TEXTURE2D(_MaskMap, sampler_MaskMap, input.uv2);
                float4 Mask2 = SAMPLE_TEXTURE2D(_MaskMap, sampler_MaskMap, input.uv2);


                input.uv = (input.uv.xy * _EffectTex_ST.xy * (1 + Mask * 0.02) + float2(_EffectTex_ST.z + frac(_Time.y / _FogSpeed), _EffectTex_ST.w + frac(_Time.y / _FogSpeed)));

                float T = frac(_Time.y* 0.1);
                float T1 = frac(_Time.y*0.1 + 0.5);

                float2 Flow1 = input.uv - FlowMap * _FlowMapIntensity * T;
                float2 Flow2 = input.uv - FlowMap * _FlowMapIntensity * T1 ;

                float lerpWeight = abs((T - 0.5) * 2);


                float4 _EffectColor = SAMPLE_TEXTURE2D(_EffectTex, sampler_EffectTex, input.uv);
                float4 _EffectColor2 = SAMPLE_TEXTURE2D(_EffectTex, sampler_EffectTex, Flow2);
                // float4 _EffectColor = lerp(_EffectColor1,_EffectColor2,lerpWeight);

                float Depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthAttachment, sampler_CameraDepthAttachment, input.scrPos);
                // Depth = smoothstep(0.1,0.12, Depth);
                float linearDepth = LinearEyeDepth(Depth, _ZBufferParams);


                // return lerp(color, _EffectColor, _Intensity);
                Mask2 = smoothstep(_MaskController.x, _MaskController.y, Mask);
                // _EffectColor =saturate(_EffectColor) *  (1-Mask.a);
                _EffectColor = pow(smoothstep(_MaskController.z, _MaskController.w, _EffectColor), 8);
                _EffectColor *= (1 - Mask2.a);

                color = color + _EffectColor * 0.8 + Mask.a * _FogDensity ;


                return  color_temp - half4(1,0,0,0) ;
            }
            
            ENDHLSL
        }
    }
    FallBack "Diffuse"
}