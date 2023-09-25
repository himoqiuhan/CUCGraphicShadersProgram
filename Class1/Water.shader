Shader "Class1/Water"
{
    Properties
    {
        _MainTex("Main Texture", 2D) = "white"{}
        _WaterTex("Water Texture", 2D) = "white"{}
        _DisturbNoiseTex("Disturb Noise", 2D) = "white"{}
        _DisturbIntensity("Disturb Intensity", Range(0.0, 1.0)) = 0.0
        _refractionAmount("Refrection Amount", Range(0.0, 1.0)) = 0.0
        _FlowSpeed("Flow Speed", vector) = (0.0,0.0,0.0,0.0)
    }

    Subshader
    {
        Tags
        {
            "RenderType"="Opaque"
            "RenderPipeline"="UniversalPipeline"
        }
        LOD 100

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
        CBUFFER_START(UnityPerMaterial)
        float4 _FlowSpeed;
        float _DisturbIntensity;
        float _refractionAmount;
        CBUFFER_END

        TEXTURE2D(_MainTex);
        SAMPLER(sampler_MainTex);
        float4 _MainTex_ST;
        TEXTURE2D(_DisturbNoiseTex);
        SAMPLER(sampler_DisturbNoiseTex);
        TEXTURE2D(_WaterTex);
        SAMPLER(sampler_WaterTex);

        struct Attributes
        {
            float4 posOS : POSITION;
            float2 uv : TEXCOORD0;
            float3 normalOS : NORMAL;
            float4 tangentOS : TANGENT;
        };

        struct Varyings
        {
            float4 posCS : SV_POSITION;
            float2 uv : TEXCOORD0;
        };

        Varyings WaterFlowVertex(Attributes vertexInput)
        {
            Varyings VertexOutput;
            VertexOutput.posCS = TransformObjectToHClip(vertexInput.posOS.xyz);
            VertexOutput.uv = TRANSFORM_TEX(vertexInput.uv, _MainTex);

            return VertexOutput;
        }

        half4 WaterFlowFragment(Varyings i) : SV_Target
        {
            half2 flowUV = i.uv + _FlowSpeed.xy * _Time.y;
            half2 disturbTexCol = SAMPLE_TEXTURE2D(_DisturbNoiseTex, sampler_DisturbNoiseTex, flowUV).xy;
            half4 waterTexCol = SAMPLE_TEXTURE2D(_WaterTex, sampler_WaterTex, i.uv + disturbTexCol*_DisturbIntensity*0.1);
            half4 mainTexCol = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv + disturbTexCol*_DisturbIntensity*0.2);
           
            return lerp(waterTexCol, mainTexCol, _refractionAmount);
            
        }
        ENDHLSL

        Pass
        {
            Cull off
            Tags
            {
                "LightMode"="UniversalForward"
            }
            HLSLPROGRAM
            #pragma vertex WaterFlowVertex
            #pragma fragment WaterFlowFragment
            ENDHLSL
        }
    }
}