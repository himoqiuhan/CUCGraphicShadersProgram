Shader "Class3/Diffuse_CartoonRamp"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        [IntRange]_StepRange("Step Range", Range(1.0, 10.0)) = 1.0
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
        float _StepRange;
        CBUFFER_END

        TEXTURE2D(_MainTex);
        SAMPLER(sampler_MainTex);
        float4 _MainTex_ST;

        struct Attributes
        {
            float4 posOS : POSITION;
            float2 uv : TEXCOORD0;
            float3 normalOS : NORMAL;
        };

        struct Varyings
        {
            float4 posCS : SV_POSITION;
            float2 uv : TEXCOORD0;
            float3 normalWS : TEXCOORD1;
        };

        Varyings VertexProgram(Attributes vertexInput)
        {
            Varyings vertexOutput;
            vertexOutput.posCS = TransformObjectToHClip(vertexInput.posOS.xyz);
            vertexOutput.uv = TRANSFORM_TEX(vertexInput.uv, _MainTex);
            vertexOutput.normalWS = TransformObjectToWorldNormal(vertexInput.normalOS.xyz, true);
            return vertexOutput;
        }

        half4 FragmentProgram(Varyings i) : SV_Target
        {
            Light mainLight = GetMainLight();
            half3 lightDir = mainLight.direction;
            half ndotl = dot(i.normalWS, lightDir);

            half halfLambert = 0.5 * ndotl + 0.5;
            half2 rampUV = half2(halfLambert, 0.1);

            half4 rampTexCol = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, rampUV);

            return rampTexCol;
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