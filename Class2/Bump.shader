Shader "Class2/Bump"
{
    Properties
    {
        _MainTex("Main Texture", 2D) = "white"{}
        _BumpTex("Bump Texture", 2D) = "white"{}
        _BumpIntensity("Refrection Amount", Range(0.0, 1.0)) = 0.0
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
        float _BumpIntensity;
        CBUFFER_END

        TEXTURE2D(_MainTex);
        SAMPLER(sampler_MainTex);
        float4 _MainTex_ST;
        TEXTURE2D(_BumpTex);
        SAMPLER(sampler_BumpTex);

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
            float4 T2W0 : TEXCOORD1;
            float4 T2W1 : TEXCOORD2;
            float4 T2W2 : TEXCOORD3;
        };

        Varyings WaterFlowVertex(Attributes vertexInput)
        {
            Varyings VertexOutput;
            VertexOutput.posCS = TransformObjectToHClip(vertexInput.posOS.xyz);
            VertexOutput.uv = TRANSFORM_TEX(vertexInput.uv, _MainTex);
            float3 posWS = TransformObjectToWorld(vertexInput.posOS.xyz);
            //TBN
            float3 normalWS = TransformObjectToWorldNormal(vertexInput.normalOS, true);
            float3 tangentWS = TransformObjectToWorldDir(vertexInput.tangentOS.xyz, true);
            float3 bitangentWS = cross(normalWS, tangentWS) * vertexInput.tangentOS.w;
            VertexOutput.T2W0 = float4(tangentWS.x, bitangentWS.x, normalWS.x, posWS.x);
            VertexOutput.T2W1 = float4(tangentWS.y, bitangentWS.y, normalWS.y, posWS.y);
            VertexOutput.T2W2 = float4(tangentWS.z, bitangentWS.z, normalWS.z, posWS.z);
            return VertexOutput;
        }

        half4 WaterFlowFragment(Varyings i) : SV_Target
        {
            float3 posWS = float3(i.T2W0.w, i.T2W1.w, i.T2W2.w);
            //Normal
            float3 normalTS = UnpackNormal(SAMPLE_TEXTURE2D(_BumpTex, sampler_BumpTex, i.uv));
            float3 normalWS = normalize(float3(dot(i.T2W0.xyz, normalTS), dot(i.T2W1.xyz, normalTS), dot(i.T2W2.xyz, normalTS))) * _BumpIntensity;
            //Lighting
            Light mainLight = GetMainLight();
            half3 lightDir = mainLight.direction;
            half lambert = max(0.0, dot(normalWS, lightDir));
            return lambert;
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