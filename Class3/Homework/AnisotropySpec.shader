Shader "Class3/AnisotropicSpec"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _DiffuseColor("Diffuse Color", Color) = (1.0, 1.0, 1.0, 1.0)
        _SpecColor("SpecColor Color", Color) = (1.0, 1.0, 1.0, 1.0)
        _SpecContrast("Specular Contrst", Range(1.0, 5.0)) = 2.0
        _SpecInt("Specular Intensity", Range(0.1, 2.0)) = 1.0
        _PrimaryShift("Primary Shift", Range(-1.0, 1.0)) = 0.0
    }
    SubShader
    {
        Tags
        {
            "RenderPipeline"="UniversalPipline"
        }
        LOD 100

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

        CBUFFER_START(UnityPerMaterial)
        half4 _DiffuseColor;
        half4 _SpecColor;
        float _SpecContrast;
        float _SpecInt;
        float _PrimaryShift;
        CBUFFER_END

        TEXTURE2D(_MainTex);
        SAMPLER(sampler_MainTex);
        float4 _MainTex_ST;

        struct Attributes
        {
            float4 posOS : POSITION;
            float2 uv : TEXCOORD0;
            float3 normalOS : NORMAL;
            float4 tangetOS : TANGENT;
        };

        struct Varyings
        {
            float4 posCS : SV_POSITION;
            float2 uv : TEXCOORD0;
            float3 normalWS : TEXCOORD1;
            float4 tangentWS : TEXCOORD2;
            float3 posWS : TEXCOORD3;
        };

        float3 CustomShiftTangent(float3 T, float3 N, float shiftValue)
        {
            float3 shiftedT = T + shiftValue * N;
            return normalize(shiftedT);
        }

        Varyings VertexProgram(Attributes vertexInput)
        {
            Varyings vertexOutput;
            vertexOutput.posCS = TransformObjectToHClip(vertexInput.posOS.xyz);
            vertexOutput.uv = TRANSFORM_TEX(vertexInput.uv, _MainTex);
            vertexOutput.normalWS = TransformObjectToWorldNormal(vertexInput.normalOS.xyz, true);
            float4 tangentWS = vertexInput.tangetOS;
            tangentWS.xyz = TransformObjectToWorldDir(vertexInput.tangetOS.xyz, true);
            vertexOutput.tangentWS = tangentWS;
            vertexOutput.posWS = TransformObjectToWorld(vertexInput.posOS.xyz);
            return vertexOutput;
        }

        half4 FragmentProgram(Varyings i) : SV_Target
        {
            Light mainLight = GetMainLight();
            half3 lightDir = mainLight.direction;
            //Diffuse Term
            half ndotl = dot(i.normalWS, lightDir);
            half4 diffuseCol = _DiffuseColor * max(0.0, ndotl);
            
            //Spec Term
            float3 viewDir = normalize(GetWorldSpaceViewDir(i.posWS));
            float3 halfDir = normalize(viewDir + lightDir);
            //Shift Tangent
            float shiftTex = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv).x;
            float3 tangent = CustomShiftTangent(i.tangentWS.xyz, i.normalWS, _PrimaryShift + shiftTex);
            float dotTH = dot(tangent, halfDir);
            float sinTH = sqrt(1 - dotTH * dotTH);
            float dirAtten = smoothstep(-1.0, 0.0, dotTH);
            float spec = dirAtten * pow(sinTH, 10 * _SpecContrast) * _SpecInt;
            half4 specCol = _SpecColor * spec;

            half4 finalCol = diffuseCol + specCol;
            
            return finalCol;
        }
        ENDHLSL

        Pass
        {
            HLSLPROGRAM
            #pragma vertex VertexProgram
            #pragma fragment FragmentProgram
            ENDHLSL
        }
    }
}