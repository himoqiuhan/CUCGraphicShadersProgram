
//Reference: https://web.engr.oregonstate.edu/~mjb/cs519/Projects/Papers/HairRendering.pdf

Shader "Class3/Kajiya-KayHair"
{
    Properties
    {
        [Header(Diffuse)]
        _DiffuseColor("Diffuse Color", Color) = (1.0, 1.0, 1.0, 1.0)
        _DiffuseInt("Diffuse Intensity", Range(0.5, 1.0)) = 1.0
        [Space(20)]
        [Header(Specular)]
        _MainShiftTex("Main Shift Texture", 2D) = "white" {}
        [NoScaleOffset]_ShiftNoiseTex("Shift Noise Texture", 2D) = "white"{}
        _SpecInt("Specular Intensity", Range(0.1, 2.0)) = 1.0
        [Header(Primary Specular)]
        _SpecColor1("Primary SpecColor Color", Color) = (1.0, 1.0, 1.0, 1.0)
        _PrimaryShift("Primary Hair Shift", Range(-1.0, 1.0)) = 0.0
        _SpecContrast1("Primary Specular Contrst", Range(1.0, 5.0)) = 2.0
        [Header(Secondary Specular)]
        _SpecColor2("Secondary SpecColor Color", Color) = (1.0, 1.0, 1.0, 1.0)
        _SecondaryShift("Secondary Hair Shift", Range(-1.0, 1.0)) = 0.0
        _SpecContrast2("Secondary Specular Contrst", Range(1.0, 5.0)) = 2.0
        
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
        half4 _SpecColor1;
        half4 _SpecColor2;
        float _DiffuseInt;
        float _SpecContrast1;
        float _SpecContrast2;
        float _SpecInt;
        float _PrimaryShift;
        float _SecondaryShift;
        CBUFFER_END

        TEXTURE2D(_MainShiftTex);
        SAMPLER(sampler_MainShiftTex);
        float4 _MainShiftTex_ST;
        TEXTURE2D(_ShiftNoiseTex);
        SAMPLER(sampler_ShiftNoiseTex);

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

        float StrandSpecular(float3 T, float3 H, float exponent)
        {
            float TdotH = dot(T, H);
            float sinTH = sqrt(1.0 - TdotH * TdotH);
            float dirAtten = smoothstep(-1.0, 0.0, TdotH);
            return dirAtten * pow(sinTH, 10*exponent);
        }

        Varyings VertexProgram(Attributes vertexInput)
        {
            Varyings vertexOutput;
            vertexOutput.posCS = TransformObjectToHClip(vertexInput.posOS.xyz);
            vertexOutput.uv = TRANSFORM_TEX(vertexInput.uv, _MainShiftTex);
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
            float3 viewDir = normalize(GetWorldSpaceViewDir(i.posWS));
            float3 halfDir = normalize(lightDir + viewDir);

            //Lambert Diffuse
            float LdotN = dot(lightDir, i.normalWS);
            float diffuse = 0.5 * LdotN + 0.5;
            half4 diffuseCol = _DiffuseColor * diffuse;
            float3 bitangent = normalize(cross(i.normalWS.xyz, i.tangentWS.xyz) * i.tangentWS.w);
            
            //Anisotropic Specular
            float shiftTexValue = SAMPLE_TEXTURE2D(_MainShiftTex, sampler_MainShiftTex, i.uv);
            float3 primaryTangent = CustomShiftTangent(bitangent.xyz, i.normalWS, shiftTexValue + _PrimaryShift);
            float3 secondaryTangent = CustomShiftTangent(bitangent.xyz, i.normalWS, shiftTexValue + _SecondaryShift);
            //Primary Specular
            float primarySpec = StrandSpecular(primaryTangent, halfDir, _SpecContrast1);
            half4 primarySpecCol = primarySpec * _SpecColor1;
            //Secondary Specular
            float secondarySpec = StrandSpecular(secondaryTangent, halfDir, _SpecContrast2);
            float secondaruSpecMask = SAMPLE_TEXTURE2D(_ShiftNoiseTex, sampler_ShiftNoiseTex, i.uv);
            secondarySpec *= secondaruSpecMask;
            half4 secondarySpecCol = secondarySpec * _SpecColor2;
            //Final Blending
            float dirAtten = smoothstep(-1.0, 0.0, dot(bitangent, halfDir));
            float specMask = smoothstep(0.25, 0.75, diffuse);
            half4 finalSpecCol = (primarySpecCol + secondarySpecCol) * specMask * dirAtten;            

            half4 finalCol = diffuseCol * _DiffuseInt + finalSpecCol * _SpecInt;
            
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