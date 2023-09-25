Shader "Class2/HeightBlend"
{
    Properties
    {
        _Height("Sands Height", Range(0.0, 1.2)) = 0.0
        _Layer1Tex("Layer1 Texture", 2D) = "white"{}
        _Layer2Tex("Layer2 Texture", 2D) = "white"{}
    }

    Subshader
    {
        Tags
        {
            "RenderPipeline"="UniversalPipeline"
        }
        LOD 100

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
        CBUFFER_START(UnityPerMaterial)
        float _Height;
        CBUFFER_END

        float4 _Layer1Tex_ST;
        TEXTURE2D(_Layer1Tex);
        SAMPLER(sampler_Layer1Tex);
        TEXTURE2D(_Layer2Tex);
        SAMPLER(sampler_Layer2Tex);
        
        struct Attributes
        {
            float4 posOS : POSITION;
            float3 normalOS : NORMAL;
            float2 uv : TEXCOORD0;
        };

        struct Varyings
        {
            float4 posCS : SV_POSITION;
            float3 posWS : TEXCOORD0;
            float3 normalWS : TEXCOORD1;
            float2 uv : TEXCOORD2;
        };

        Varyings TransparentVertex(Attributes vertexInput)
        {
            Varyings VertexOutput;
            VertexOutput.posCS = TransformObjectToHClip(vertexInput.posOS.xyz);
            VertexOutput.posWS = TransformObjectToWorld(vertexInput.posOS.xyz);
            VertexOutput.normalWS = TransformObjectToWorldNormal(vertexInput.normalOS, true);
            VertexOutput.uv = TRANSFORM_TEX(vertexInput.uv, _Layer1Tex);
            return VertexOutput;
        }

        half4 TransparentFragment(Varyings i) : SV_Target
        {
            _Height = _Height + 0.5 * (sin(_Time.y)+1.5);
            half4 Layer1TexCol = SAMPLE_TEXTURE2D(_Layer1Tex, sampler_Layer1Tex, i.uv);
            half Layer1Height = Layer1TexCol.a;
            half4 Layer1Col = half4(Layer1TexCol.rgb, 1.0);
            
            half4 Layer2TexCol = SAMPLE_TEXTURE2D(_Layer2Tex, sampler_Layer2Tex, i.uv);
            half Layer2Height = Layer2TexCol.a;
            half4 Layer2Col = half4(Layer2TexCol.rgb, 1.0);
                        
            return (Layer1Height + _Height - 0.6) > Layer2Height ? Layer1Col : lerp(Layer2Col, Layer1Col, 0.3 * (Layer2Height + _Height));
        }
        ENDHLSL

        Pass
        {
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