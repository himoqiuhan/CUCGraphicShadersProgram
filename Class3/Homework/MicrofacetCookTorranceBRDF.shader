
//Reference:

Shader "Class3/MicrofacetCookTorranceBRDF"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _DiffuseCol("Diffuse Color", Color) = (1.0, 1.0, 1.0, 1.0)
        _SpecColor("Specular Color", Color) = (1.0, 1.0, 1.0, 1.0)
        _Metallic("Metallic", Range(0.0, 1.0)) = 0.0
        _Roughness("Roughness", Range(0.01, 1.0)) = 0.5
        _Fresnel("Fresnel", Range(0.0, 1.0)) = 0.0
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
        half4 _DiffuseCol;
        half4 _SpecColor;
        float _Roughness;
        float _Metallic;
        float _Fresnel;
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

        float NDF_GGX(float halfDir, float normalDir, float roughness)
        {
            float HdotN = max(0.0, dot(halfDir, normalDir));
            float d = HdotN * HdotN * (roughness * roughness - 1.0) + 1.0;
            return (roughness * roughness) / (PI * d * d);
        }

        float Geometry_SchlickGGX(float3 normalDir, float3 viewDir, float3 lightDir, float roughness)
        {
            float alpha = 0.25 * (roughness + 1) * (roughness + 1);
            float k = 0.5 * alpha;
            float NdotV = max(0.0, dot(normalDir, viewDir));
            float NdotL = max(0.0, dot(normalDir, lightDir));
            float G_v =  NdotV / (NdotV * (1 - k) + k);
            float G_l = NdotL / (NdotL * (1 - k) + k);
            return G_l * G_v;
        }

        float Fresnel_Schlick(float3 halfDir, float3 viewDir, float F0)
        {
            float3 HdotV = max(0.0, dot(halfDir, viewDir));
            return F0 + (1-F0)*pow(1 - HdotV, 5);
        }

        float CookTorranceBRDFSpecular(float3 normalDir, float3 viewDir, float3 lightDir, float roughness, float F0)
        {
            float3 halfDir = normalize(lightDir + viewDir);
            //Handle with F0
            F0 = _Metallic * (F0 * 0.5 + 0.5) + (1 - _Metallic) * (0.02 + 0.03 * F0);
            //Handle with DGF and CorrectionFactor
            float specular_D = NDF_GGX(halfDir, normalDir, roughness);
            float specular_G = Geometry_SchlickGGX(normalDir, viewDir, lightDir, roughness);
            float specular_F = Fresnel_Schlick(halfDir, viewDir, F0);
            float correctionFactor = 4 * max(0.0, dot(normalDir, lightDir)) * max(0.0, dot(normalDir, viewDir)) + 0.01;

            return specular_D * specular_G * specular_F / correctionFactor;
        }
        

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
            half3 lightDir = normalize(mainLight.direction);
            float ndotl = dot(i.normalWS, lightDir);
            //Diffuse
            float diffuse = pow(0.5 * ndotl + 0.5, 2);
            half4 diffuseCol = _DiffuseCol * diffuse;
            //Cook-Torrance BSDF Specular
            float3 viewDir = normalize(GetCameraPositionWS().xyz - i.posWS);
            float spec = CookTorranceBRDFSpecular(i.normalWS, viewDir, lightDir, _Roughness, _Fresnel);
            half4 specCol = _DiffuseCol * spec;
            
            return  specCol + diffuseCol;
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