Shader "Class3/CelShading"
{
    Properties
    {
        [Header(Diffuse)]
        _BasicBaseColor("Base Color", Color) = (1.0, 1.0, 1.0, 1.0)
        _ShadowInt("Shadow Brightness Falloff", Range(0.1, 1.0)) = 0.8
        _ShadowRange("Shadow Range", Range(0.0, 1.0)) = 0.8
        _SmoothShadowRange("Smooth Shadow Range", Range(0.0, 0.2)) = 0.0

        [Header(Specular)]
        _BasicSpecColor("Specular Color", Color) = (1.0, 1.0, 1.0, 1.0)
        _SpecRange("Specular Range", Range(0.0, 1.0)) = 0.5
        _SpecInt("Specular Intensity", Range(0.5, 1.0)) = 0.75
        _SpecOffsetWorldXRot("Specular Point X-axis Rotation", Range(0.0, 1.0)) = 0.0
        _SpecOffsetWorldYRot("Specular Point Y-axis Rotation", Range(0.0, 1.0)) = 0.0
        _SpecOffsetWorldZRot("Specular Point Z-axis Rotation", Range(0.0, 1.0)) = 0.0

        [Header(Rim Light)]
        _RimLightColor("Rim Light Color", Color) = (1.0, 1.0, 1.0, 1.0)
        _RimLightWidth("Rim Light Width", Range(0.0, 1.0)) = 0.5

        [Header(Outline)]
        _OutlineColor("Outline Color", Color) = (0.0, 0.0, 0.0, 1.0)
        _OutlineWidth("Outline Width", Range(0.0, 1.0)) = 0.5
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
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

        CBUFFER_START(UnityPerMaterial)
        half4 _BasicBaseColor;
        float _ShadowInt;
        float _ShadowRange;
        float _SmoothShadowRange;

        float _SpecRange;
        float _SpecInt;
        half4 _BasicSpecColor;
        float _SpecOffsetWorldXRot;
        float _SpecOffsetWorldYRot;
        float _SpecOffsetWorldZRot;

        half4 _RimLightColor;
        float _RimLightWidth;

        half4 _OutlineColor;
        float _OutlineWidth;
        CBUFFER_END

        struct BaseAttributes
        {
            float4 posOS : POSITION;
            float3 normalOS : NORMAL;
        };

        struct BaseVaryings
        {
            float4 posCS : SV_POSITION;
            float3 posWS : TEXCOORD0;
            float3 normalWS : TEXCOORD1;
        };

        struct OutlineAttributes
        {
            float4 posOS : POSITION;
            float3 normalOS : NORMAL;
            float4 tangentOS : TANGENT;
        };

        struct OutlineVaryings
        {
            float4 posCS : SV_POSITION;
        };

        BaseVaryings BaseVertexProgram(BaseAttributes vertexInput)
        {
            BaseVaryings vertexOutput;
            vertexOutput.posCS = TransformObjectToHClip(vertexInput.posOS.xyz);
            vertexOutput.posWS = TransformObjectToWorld(vertexInput.posOS.xyz);
            vertexOutput.normalWS = TransformObjectToWorldNormal(vertexInput.normalOS.xyz, true);
            return vertexOutput;
        }

        half4 BaseFragmentProgram(BaseVaryings i) : SV_Target
        {
            Light mainLight = GetMainLight();
            half3 lightDir = mainLight.direction;
            half ndotl = dot(i.normalWS, lightDir);

            //Diffuse
            half halfLambert = 0.5 * ndotl + 0.5;
            float shadowMask = smoothstep(halfLambert, halfLambert + _SmoothShadowRange * 0.01, _ShadowRange);
            half4 diffuseCol = shadowMask * _BasicBaseColor * _ShadowInt + (1 - shadowMask) * _BasicBaseColor;

            //Blinn-Phong Specular
            float3 viewDir = normalize(_WorldSpaceCameraPos.xyz - i.posWS.xyz);
            half3 halfDir = normalize(viewDir.xyz + i.normalWS.xyz);
            //Use Eula angle to offset the specular point
            float alpha = _SpecOffsetWorldZRot;
            float beta = _SpecOffsetWorldYRot;
            float gamma = _SpecOffsetWorldXRot;
            float3x3 Mat_Rotation = float3x3(cos(alpha) * cos(beta),
                                             cos(alpha) * sin(beta) * sin(gamma) - sin(alpha) * cos(gamma),
                                             cos(alpha) * sin(beta) * cos(gamma) + sin(alpha) * sin(gamma),
                                             sin(alpha) * cos(beta),
                                             cos(alpha) * cos(gamma) + sin(alpha) * sin(beta) * sin(gamma),
                                             sin(alpha) * sin(beta) * cos(gamma) - sin(gamma) * cos(alpha),
                                             -sin(beta), cos(beta) * sin(gamma), cos(beta) * cos(gamma));
            halfDir = mul(Mat_Rotation, halfDir);
            half specMask = step(0.99 + 0.01 * (1.0 - _SpecRange), pow(dot(halfDir, lightDir), 2.0)) * (1.0 -
                shadowMask);
            half4 specColor = _BasicSpecColor * _SpecInt;
            half4 diffSpecCol = specColor * specMask + (1.0 - specMask) * diffuseCol;

            //Rim Light -- Screen space equivalence distance rim light
            float4 posCS = TransformWorldToHClip(i.posWS);
            //Get original depth
            float4 orgPosCS = float4(posCS.xy, 0.0, posCS.w);
            float4 orgScreenPos = ComputeScreenPos(orgPosCS);
            float2 orgVPCoord = orgScreenPos.xy / orgScreenPos.w;
            float orgDepth = SampleSceneDepth(orgVPCoord);
            float orgLinearDepth = LinearEyeDepth(orgDepth, _ZBufferParams);
            //Get offset depth
            float3 normalCS = TransformWorldToHClipDir(i.normalWS, true);
            float4 rimOffsetPosCS = float4(normalCS.xy * _RimLightWidth * 0.03 + posCS.xy, 0.0, posCS.w);
            float4 rimOffsetScreenPos = ComputeScreenPos(rimOffsetPosCS);
            float2 offsetVPCoord = rimOffsetScreenPos.xy / rimOffsetScreenPos.w;
            float offsetDepth = SampleSceneDepth(offsetVPCoord);
            float offsetLinearDepth = LinearEyeDepth(offsetDepth, _ZBufferParams);
            float depthDiff = offsetLinearDepth - orgLinearDepth;
            float rimLightMask = step(0.9, depthDiff) * (1 - shadowMask);

            half4 finalCol = _RimLightColor * rimLightMask + (1.0 - rimLightMask) * diffSpecCol;

            return finalCol;
        }

        OutlineVaryings OutlineVertexProgram(OutlineAttributes vertexInput)
        {
            OutlineVaryings vertexOutput;
            float4 posCS = vertexOutput.posCS = TransformObjectToHClip(vertexInput.posOS.xyz);
            float3 normalWS = TransformObjectToWorldNormal(vertexInput.normalOS.xyz, true);
            float3 nomralCS = TransformWorldToHClipDir(normalWS, true);
            float HdivV = _ScreenParams.x / _ScreenParams.y;

            float2 offset = float2(nomralCS.x, nomralCS.y * HdivV) * _OutlineWidth * 0.05;
            posCS.xy += offset;
            vertexOutput.posCS = posCS;
            return vertexOutput;
        }

        half4 OutlineFragmentProgram(OutlineVaryings i) : SV_Target
        {
            return _OutlineColor;
        }
        ENDHLSL

        Pass
        {
            Tags
            {
                "LightMode"="UniversalForward"
            }
            HLSLPROGRAM
            #pragma vertex BaseVertexProgram
            #pragma fragment BaseFragmentProgram
            ENDHLSL
        }

        Pass
        {
            NAME "OUTLINE_BACKFACE"

            Cull Front
            Tags
            {
                "LightMode" = "SRPDefaultUnlit"
            }
            HLSLPROGRAM
            #pragma vertex OutlineVertexProgram
            #pragma fragment OutlineFragmentProgram
            ENDHLSL
        }

        Pass
        {
            Name "DEPTH_ONLY"
            Tags
            {
                "LightMode" = "DepthOnly"
            }

            ZWrite On
            ColorMask 0
            Cull off

            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            #pragma vertex DepthOnlyVertex
            #pragma fragment DepthOnlyFragment

            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/DepthOnlyPass.hlsl"
            ENDHLSL
        }
    }
}