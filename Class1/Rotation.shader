Shader "Class1/Rotation"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _RotateIntensity("Rotate Amount", Range(-10.0, 10.0)) = 0.0
        _RotateSpeed("Rotate Speed", Range(1.0, 10.0)) = 1.0
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline"="UniversalPipeline"}
        LOD 100
        
        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            CBUFFER_START(UnityPerMaterial)
            float _RotateIntensity;
            float _RotateSpeed;
            CBUFFER_END
            
            float4 _MainTex_ST;
            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);

            struct Attributes
            {
                float2 uv : TEXCOORD0;
                float4 posOS : POSITION;
            };

            struct Varyings
            {
                float2 uv : TEXCOORD0;
                float4 posCS : SV_POSITION;
            };

            Varyings RotationVertex(Attributes vertexInput)
            {
                Varyings vertexOutput;
                vertexOutput.posCS = TransformObjectToHClip(vertexInput.posOS.xyz);
                vertexOutput.uv = TRANSFORM_TEX(vertexInput.uv, _MainTex);
                return vertexOutput;
            }

            half4 RotationFragment(Varyings i) : SV_Target
            {
                float2 center = float2(0.5, 0.5);
                float len = length(i.uv - center);
                float2 tempUV = i.uv - center;
                float theta = _RotateIntensity * sin(_Time.y * 0.1 * _RotateSpeed) * len;
                float sinx = sin(theta);
                float cosx = cos(theta);
                float2x2 rotationMat = float2x2(cosx, sinx, -sinx, cosx);
                tempUV = mul(rotationMat, tempUV);
                tempUV += center;
                half4 col = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, tempUV);
                return col;
            }
        ENDHLSL

        Pass
        {
            Tags{"LightMode"="UniversalForward"}
            HLSLPROGRAM
            #pragma vertex RotationVertex
            #pragma fragment RotationFragment
            ENDHLSL
        }
    }
}
