Shader "LwyShaders/BaseWater"
{
    Properties
    {


        [Space(20)][Header(base settings)]
        _BaseMap ("Texture", 2D) = "white" { }
        _BaseColor ("baseColor", color) = (0, 0, 0, 1)
        _normalMap ("_normalMap", 2D) = "bump" { }
        _waterDepthMin ("waterDepthMin", Range(0, 1)) = 0.1
        _waterDepthMax ("waterDepthMax", Range(0, 1)) = 0.1
        _specPower ("specPower", float) = 8
        _specColor ("spec Color", color) = (0,0,0,1)
        // [Toggle(_VERTEX_COLORS)] _VertexColors ("Vertex Colors", Float) = 0
        _NormalStength ("Normal stength", Range(-1, 1)) = 0.1
        _DistortionStength ("DistortionStength", Range(-1, 1)) = 0.1
        _FlowMap ("Flow map", 2D) = "Black" { }
        _FlowSpeed ("Flow Speed", float) = 0.1
        _FlowSpeed2 ("Flow Speed", float) = 0.2
        IOR("IOR", float) = 1
        _FresnelPower ("Fresnel Power", float) = 3

        _cartoonSpecularMap("Specular Map", 2D) = "Black" {}
        _cartoonSpecularMask("Specular Mask", 2D) = "Black" {}
        _cartoonSpecularPower("Cartoon Specular Power",Float) = 1

    }

    SubShader
    {

        Tags { "Queue" = "Transparent" "RenderType" = "Transparent" "IgnoreProjector" = "True" "RenderPipeline" = "UniversalPipeline" }

        pass
        {
            Name "ScreenDistortion"
            Tags { "LightMode" = "UniversalForward" }
            
            Cull back
            // ZTest off
            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite off


            HLSLPROGRAM

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            #pragma target 4.5

            #pragma vertex vert
            #pragma fragment frag

            #pragma multi_compile_fog

            // #pragma multi_compile  _MAIN_LIGHT_SHADOWS
            // #pragma multi_compile  _MAIN_LIGHT_SHADOWS_CASCADE
            // #pragma multi_compile  _SHADOWS_SOFT

            #pragma shader_feature _ENABLENORMALMAP
            #pragma shader_feature _VERTEX_COLORS

            CBUFFER_START(UnityPerMaterial)

                float4 _BaseMap_ST;
                float4 _MainTex_ST;
                float4 _normalMap_ST;
                float4 _cartoonSpecularMap_ST, _cartoonSpecularMask_ST;
                half4 _BaseColor, _specColor;
                float _NormalStength;
                half _waterDepthMin, _waterDepthMax, c, _specPower, _DistortionStength, _FlowSpeed, _FlowSpeed2 , IOR, _FresnelPower,_cartoonSpecularPower;

            CBUFFER_END

            TEXTURE2D(_BaseMap); SAMPLER(sampler_BaseMap);
            TEXTURE2D(_cartoonSpecularMap); SAMPLER(sampler_cartoonSpecularMap);
            TEXTURE2D(_cartoonSpecularMask); SAMPLER(sampler_cartoonSpecularMask);
            TEXTURE2D(_CameraOpaqueTexture); SAMPLER(sampler_CameraOpaqueTexture);
            TEXTURE2D(_CameraDepthTexture); SAMPLER(sampler_CameraDepthTexture);
            TEXTURE2D(_normalMap); SAMPLER(sampler_normalMap);
            TEXTURE2D(_FlowMap); SAMPLER(sampler_FlowMap);

            struct a2v
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float4 tangentOS : TANGENT;
                float4 texcoord : TEXCOORD0;
                float flipbookBlend : TEXCOORD1;

                // #if  _VERTEX_COLORS
                float4 color : COLOR;
                // #endif

                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct v2f
            {
                float4 positionCS : SV_POSITION;
                float3 positionWS : TEXCOORD0;
                // float3 positionVS : TEXCOORD4;
                float2 uv : TEXCOORD1;
                float4 positionSS : TEXCOORD2;
                float3 tangentWS : TEXCOORD3;
                float3 bitangentWS : TEXCOORD4;
                float3 normalWS : TEXCOORD5;


                #if  _VERTEX_COLORS
                    float4 color : VAR_COLOR;
                #endif
                // float fogCoord : TEXCOORD2;

            };

            v2f vert(a2v input)
            {
                v2f o;

                o.positionCS = TransformObjectToHClip(input.positionOS);
                o.positionWS = TransformObjectToWorld(input.positionOS.xyz);
                o.normalWS = TransformObjectToWorldNormal(input.normalOS.xyz, true);
                o.tangentWS = TransformObjectToWorldDir(input.tangentOS);
                // o.positionVS = TransformWorldToView(TransformObjectToWorld(input.positionOS.xyz));
                // normalVS = TransformWorldToViewDir(normalWS, true);

                o.bitangentWS = normalize(cross(o.normalWS, o.tangentWS) * input.tangentOS.w);

                // //recive shadow
                // o.shadowCoord = TransformWorldToShadowCoord(o.positionWS); do not cuculate this in vert, could cause glitch problem.
                
                o.uv = TRANSFORM_TEX(input.texcoord, _BaseMap);

                #if _VERTEX_COLORS
                    o.color = input.color;
                #endif

                o.positionSS = ComputeScreenPos(o.positionCS);

                return o;
            }

            half4 frag(v2f input) : SV_TARGET
            {

                // float3 positionVS = TransformWorldToView(input.positionWS);

                float2 srcPos = input.positionSS.xy / input.positionSS.w;

                //initialize main light
                Light MainLight = GetMainLight(TransformWorldToShadowCoord(input.positionWS));
                half3 LightDir = normalize(half3(MainLight.direction));
                half3 LightColor = MainLight.color.rgb;

                //flow map

                float T1 = frac(_Time.y * _FlowSpeed);
                float T2 = frac(_Time.y * _FlowSpeed2) + 0.5;

                half2 flowMap = SAMPLE_TEXTURE2D(_FlowMap, sampler_FlowMap, input.uv).xy;
                half2 flowMap2 = SAMPLE_TEXTURE2D(_FlowMap, sampler_FlowMap, input.uv).xy;

                flowMap *= T1;
                flowMap2 *= T2;

                float lerpWeight = abs((T1 - 0.5) * 2);

                half2 lerpFlowMap = lerp(flowMap, flowMap2, lerpWeight);


                half4 normalMap = SAMPLE_TEXTURE2D(_normalMap, sampler_normalMap, input.uv*_normalMap_ST.xy + T1);
                half4 normalMap2 = SAMPLE_TEXTURE2D(_normalMap, sampler_normalMap, input.uv*_normalMap_ST.xy + T2);

                normalMap = (normalMap + normalMap2) / 2;
                half3 bump = UnpackNormalScale(normalMap, _NormalStength);
                // half2 bump2 = UnpackNormalScale(normalMap, _NormalStength).rg;
                half2 opaqueDistortion = UnpackNormalmapRGorAG(normalMap, _DistortionStength).rg;

                float3x3 TBN = {
                    input.bitangentWS, input.tangentWS, input.normalWS
                };
                bump.z = pow(1 - pow(bump.x, 2) - pow(bump.y, 2), 0.5);
                input.normalWS = mul(bump, TBN);

                // float2 temp = DecodeNormal(distortionMap, 1);

                //Phong
                float3 viewDir = normalize(_WorldSpaceCameraPos.xyz - input.positionWS.xyz);
                float3 reflectDir = normalize(reflect(MainLight.direction, input.normalWS));
                float phong = pow(saturate(dot(viewDir, -reflectDir)), _specPower);


                half4 difusse = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv);
                half4 screenOpaqueColor = SAMPLE_TEXTURE2D(_CameraOpaqueTexture, sampler_CameraOpaqueTexture, srcPos.xy + opaqueDistortion);

                //under water depth effect
                half screenDepthColor = SAMPLE_TEXTURE2D_X(_CameraDepthTexture, sampler_CameraDepthTexture, srcPos.xy).r;

                screenDepthColor = LinearEyeDepth(screenDepthColor, _ZBufferParams);
                float surfaceDepth = UNITY_Z_0_FAR_FROM_CLIPSPACE(input.positionSS.z);
                half waterDepth = screenDepthColor - surfaceDepth;
                waterDepth = saturate(waterDepth);

                waterDepth = smoothstep(_waterDepthMin, _waterDepthMax, waterDepth);


                // cartoon speculer
                half4 cartoonSpecular = SAMPLE_TEXTURE2D(_cartoonSpecularMap, sampler_cartoonSpecularMap, input.uv * _cartoonSpecularMap_ST.xy + T1);
                half4 cartoonSpecularMask = SAMPLE_TEXTURE2D(_cartoonSpecularMask, sampler_cartoonSpecularMask, input.uv * _cartoonSpecularMask_ST.yx + T2);
                cartoonSpecular = smoothstep(0.1,0.8,cartoonSpecular);
                cartoonSpecularMask = smoothstep(0,1,cartoonSpecularMask);
                

                //frenel rim
                float4 fresnelRim = pow(1 - saturate(dot(normalize(input.normalWS), viewDir)), _FresnelPower);
                float4 finalFresnelRim = smoothstep(0,1,fresnelRim);
                finalFresnelRim *=  fresnelRim ;
                finalFresnelRim *= _specColor;

                float4 color = difusse * _BaseColor ;

                //recive shadow

                color *= screenOpaqueColor * waterDepth +  finalFresnelRim + cartoonSpecular*cartoonSpecularMask*_cartoonSpecularPower;
                color.a = _BaseColor.a;
                // clip(color.a - 0.01);

                return color;
            }

            ENDHLSL
        }
    }
}
