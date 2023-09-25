Shader "Class3/Blinn-PhongSpec"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Color("Diffuse Color", Color) = (1.0, 1.0, 1.0, 1.0)
        _SpecContrast("Specular Contrst", Range(1.0, 5.0)) = 2.0
        _SpecRange("Specular Range", Range(0.1, 5.0)) = 1.0
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
        half4 _Color;
        float _SpecContrast;
        float _SpecRange;
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
            float3 posWS : TEXCOORD2;
        };

        Varyings VertexProgram(Attributes vertexInput)
        {
            Varyings vertexOutput;
            vertexOutput.posCS = TransformObjectToHClip(vertexInput.posOS.xyz);
            vertexOutput.uv = TRANSFORM_TEX(vertexInput.uv, _MainTex);
            vertexOutput.normalWS = TransformObjectToWorldNormal(vertexInput.normalOS.xyz, true);
            vertexOutput.posWS = TransformObjectToWorld(vertexInput.posOS.xyz);
            return vertexOutput;
        }

        half4 FragmentProgram(Varyings i) : SV_Target
        {
            Light mainLight = GetMainLight();
            half3 lightDir = mainLight.direction;
            //Diffuse Term
            half ndotl = dot(i.normalWS, lightDir);
            half4 diffuseCol = _Color * max(0.0, ndotl);
            //Spec Term
            float3 viewDir = normalize(GetWorldSpaceViewDir(i.posWS));
            float3 halfDir = normalize(viewDir + lightDir);
            float hdotn = dot(halfDir, lightDir);
            float spec = pow(max(0.0, hdotn), 10 * _SpecContrast) * _SpecRange;

            return spec;

            return pow(0.5 * ndotl + 0.5, 2);
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