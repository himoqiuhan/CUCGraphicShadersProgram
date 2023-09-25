Shader "Class2/CustomTerrain"
{
    Properties
    {
        _GrassTex("Grass Texture", 2D) = "white"{}
        _SandsTex("Sands Texture", 2D) = "white"{}
        _HeightMap("Height Texture", 2D) = "white"{}
        _BumpTex("Bump Texture", 2D) = "white"{}
        _BumpIntensity("Bump Intensity", Range(0.0, 1.0)) = 0.0
        
        _Center("Center", Vector) = (200, 0, 200, 0)
        _Radius("Radius", Float) = 100.0
        _RadiusColor("Radius Color", Color) = (1,0,0,1)
        _RaduisWidth("Radius Width" ,Range(0.1, 5.0)) = 1.0
    }

    Subshader
    {
        Tags { "Queue" = "Geometry-100" "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" "UniversalMaterialType" = "Lit" "IgnoreProjector" = "False" "TerrainCompatible" = "True"}
        LOD 100

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
        CBUFFER_START(UnityPerMaterial)
        float4 _Center;
        float _Radius;
        half4 _RadiusColor;
        float _RaduisWidth;
        float _BumpIntensity;
        CBUFFER_END

        TEXTURE2D(_GrassTex);
        SAMPLER(sampler_GrassTex);
        float4 _GrassTex_ST;
        TEXTURE2D(_SandsTex);
        SAMPLER(sampler_SandsTex);
        TEXTURE2D(_HeightMap);
        SAMPLER(sampler_HeightMap);
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

        Varyings TerrainVertex(Attributes vertexInput)
        {
            Varyings VertexOutput;
            VertexOutput.posCS = TransformObjectToHClip(vertexInput.posOS.xyz);
            VertexOutput.uv = TRANSFORM_TEX(vertexInput.uv, _GrassTex);
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

        half4 TerrainFragment(Varyings i) : SV_Target
        {
            float3 posWS = float3(i.T2W0.w, i.T2W1.w, i.T2W2.w);
            //Normal
            float3 normalTS = UnpackNormal(SAMPLE_TEXTURE2D(_BumpTex, sampler_BumpTex, i.uv));
            normalTS = float3(1.0 - normalTS.x, 1.0 - normalTS.y, 1.0 - normalTS.z);
            float3 normalWS = normalize(float3(dot(i.T2W0.xyz, normalTS), dot(i.T2W1.xyz, normalTS), dot(i.T2W2.xyz, normalTS))) * _BumpIntensity;
            //Lighting
            Light mainLight = GetMainLight();
            half3 lightDir = mainLight.direction;
            half halfLambert = pow(dot(lightDir, normalWS), 2);

            //Shading
            half height = SAMPLE_TEXTURE2D(_HeightMap, sampler_HeightMap, i.uv);
            height = pow(saturate(height * 6.0), 5.0);
            float heightMask1 = smoothstep(0.0, 0.5, height);
            float heightMask2 = smoothstep(0.95, 1.0, height);

            half4 grassTexCol = SAMPLE_TEXTURE2D(_GrassTex, sampler_GrassTex, i.uv);
            half4 sandsTexCol = SAMPLE_TEXTURE2D(_SandsTex, sampler_SandsTex, i.uv);
            half4 snowCol = half4(1.0, 1.0, 1.0, 1.0);
            half4 albedo = halfLambert * lerp(lerp(grassTexCol, sandsTexCol, heightMask1),snowCol, heightMask2);

            // return albedo;
            
            //Ring Mask Handle
            float d = distance(_Center.xyz, posWS.xyz);
            float d2 = distance(_Center.xz, posWS.xz);
            float ringMask = saturate(step(_Radius, d) - step(_Radius + _RaduisWidth * d2 / d,d));

            // return ringMask;
            
            // return halfLambert;
            return half4(1.0,1.0,1.0,1.0) * ringMask + (1.0 - ringMask) * albedo;
            return half4(1.0, 1.0, 1.0, 1.0);
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
            #pragma vertex TerrainVertex
            #pragma fragment TerrainFragment
            ENDHLSL
        }
    }
}