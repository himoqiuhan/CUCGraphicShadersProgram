Shader "Class2/BasicTessellation"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        [IntRange]_TessellationGrade("Tessellation Grade", Range(1,32)) = 1.0
    }
    SubShader
    {
        Tags
        {
            "RenderType"="Opaque"
        }
        LOD 100

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

        CBUFFER_START(UnityPerMaterial)
        float _TessellationGrade;
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
        };

        //大部分结构与Attributes相同，只是 POSITION语义换为了 INTERNALTESSPOS
        struct ControlPoint
        {
            float4 posOS : INTERNALTESSPOS;
            float3 normalOS : NORMAL;
            float2 uv : TEXCOORD0;
        };

        //用于确定细分三角形方式，GPU使用了4个细分Fractor ：面片每个边缘各有一个Fractor，以及内部的一个Fractor
        //三个边缘Fractor必须作为具有SV_TessFactor语义的float数组传递，内部Factor使用SV_InsideTessFactor语义
        struct TessellationFactors
        {
            float edge[3] : SV_TESSFACTOR;
            float inside : SV_INSIDETESSFACTOR;
        };

        //Vertex Shader，功能只是将OS空间下的各个数据传递给曲面细分阶段
        ControlPoint BeforeTessVertProgram(Attributes v)
        {
            ControlPoint o;
            o.posOS = v.posOS;
            o.normalOS = v.normalOS;
            o.uv = v.uv;
            return o;
        }

        //发挥正式功能的Vertex Shader（也就是常见的Vertex Shader功能），在Domain Shader中被调用，对最终获得的细分后的顶点数据进行坐标转换
        Varyings AfterTessVertProgram(Attributes vertexInput)
        {
            Varyings vertexOutput;
            vertexOutput.posCS = TransformObjectToHClip(vertexInput.posOS.xyz);
            vertexOutput.uv = TRANSFORM_TEX(vertexInput.uv, _MainTex);
            vertexOutput.normalWS = TransformObjectToWorldDir(vertexInput.normalOS.xyz);
            return vertexOutput;
        }

        //PatchConstantFunction函数会决定Patch属性如何细分，所以这个函数每个Patch都会被调用一次
        //所以其中对细分Fractor进行控制
        TessellationFactors MyPatchConstantFunction(InputPatch<ControlPoint, 3> patch)
        {
            TessellationFactors o;
            o.edge[0] = _TessellationGrade;
            o.edge[1] = _TessellationGrade;
            o.edge[2] = _TessellationGrade;
            o.inside = _TessellationGrade;
            return o;
        }

        //Hull Shader确定细分的方式
        [domain("tri")] //正在处理三角形
        [outputcontrolpoints(3)] //每个patch输出3个控制点
        [patchconstantfunc("MyPatchConstantFunction")] //调用Patch Constant Function来得到细分的参数
        [partitioning("fractional_odd")] //定义细分边的规则，equal_spacing,fractional_odd,fractional_even
        [outputtopology("triangle_cw")] //按照顺时针的方式创建三角形
        ControlPoint HullProgram(InputPatch<ControlPoint, 3> patch, uint id : SV_OutputControlPointID)
        {
            return patch[id];
        }

        //Hull Shader只是用于确定如何细分Patch，由Domain Shader来评估结果并生成最终的三角形顶点
        //Hull Shader虽然不会产生任何新的顶点，但是他会为这些顶点提供重心坐标，也就是Domain Shader中的SV_DomainLocation语义
        //也正因为由Domain Shader生成最终的顶点，所以需要在Domain Shader的最后对顶点进行空间的变换
        [domain("tri")] //与Hull Shader相同
        Varyings DomainProgram(TessellationFactors factors, OutputPatch<ControlPoint, 3> patch,
                               float3 bary : SV_DOMAINLOCATION)
        {
            Attributes v;
            //使用三角形重心坐标得到每一个细分顶点的属性，通过宏定义让代码简洁
            #define DomainInterpolate(fieldName) v.fieldName = \
                patch[0].fieldName * bary.x + \
                patch[1].fieldName * bary.y + \
                patch[2].fieldName * bary.z;

            v.posOS = DomainInterpolate(posOS);
            v.normalOS = DomainInterpolate(normalOS);
            v.uv = DomainInterpolate(uv);

            //进行顶点的空间变换
            Varyings o = AfterTessVertProgram(v);
            return o;
        }

        half4 FragmentProgram(Varyings i) : SV_Target
        {
            return half4(1.0, 1.0, 1.0, 1.0);
        }
        ENDHLSL

        Pass
        {
            HLSLPROGRAM
            #pragma target 4.6
            #pragma vertex BeforeTessVertProgram
            #pragma hull HullProgram
            #pragma domain DomainProgram
            #pragma fragment FragmentProgram
            ENDHLSL
        }

    }
}