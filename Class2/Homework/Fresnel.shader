Shader "Class2/Fresnel"
{
    Properties
    {
        _TransparentThreshold("Transparent Treshold", Range(0.0, 5.0)) = 0.0
    }

    Subshader
    {
        Tags
        {
            "RenderPipeline"="UniversalPipeline"
            "Queue"="Transparent"
            "RenderType"="Transparent"
            "IgnoreProjector"="True"
        }
        LOD 100

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
        CBUFFER_START(UnityPerMaterial)
        float _TransparentThreshold;
        CBUFFER_END
        

        struct Attributes
        {
            float4 posOS : POSITION;
            float3 normalOS : NORMAL;
        };

        struct Varyings
        {
            float4 posCS : SV_POSITION;
            float3 posWS : TEXCOORD0;
            float3 normalWS : TEXCOORD1;
        };

        Varyings TransparentVertex(Attributes vertexInput)
        {
            Varyings VertexOutput;
            VertexOutput.posCS = TransformObjectToHClip(vertexInput.posOS.xyz);
            VertexOutput.posWS = TransformObjectToWorld(vertexInput.posOS.xyz);
            VertexOutput.normalWS = TransformObjectToWorldNormal(vertexInput.normalOS, true);
            return VertexOutput;
        }

        half4 TransparentFragment(Varyings i) : SV_Target
        {
            float3 viewDir = normalize(_WorldSpaceCameraPos.xyz - i.posWS);
            float alpha = 1.0 - pow(max(0.0, dot(viewDir, i.normalWS)), _TransparentThreshold);
            return half4(1.0, 1.0, 1.0, alpha);
        }
        ENDHLSL

        Pass
        {
            Blend SrcAlpha OneMinusSrcAlpha 
            Cull Back
            Tags
            {
                "LightMode"="UniversalForward"
            }
            HLSLPROGRAM
            #pragma vertex TransparentVertex
            #pragma fragment TransparentFragment
            ENDHLSL
        }
    }
}