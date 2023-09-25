## 基础Cel-Shading

![效果](C:\Users\Qui Han\AppData\Roaming\Typora\typora-user-images\image-20230924154249854.png)

实现的效果：

- 二分着色：漫反射颜色、适度可控的阴影软硬区分、可控的阴影范围
- 卡通高光：高光颜色、二分的高光范围、高光强度、基于欧拉角的高光位置偏移
- 边缘光：边缘光颜色、边缘光范围
- 描边：描边颜色、描边粗细

### Diffuse

漫反射使用`smoothstep()`去基于Half-Lambert实现简单的可控软硬阴影的二分效果，本质上直接使用Lambert去作参数即可，但是为了能保证暴露出来的参数Shadow Range能被控制在0-1之间，怎么都需要有一个0.5*x+0.5的步骤，索性直接使用Half-Lambert了

```glsl
half halfLambert = 0.5 * ndotl + 0.5;
float shadowMask = smoothstep(halfLambert, halfLambert + _SmoothShadowRange * 0.01, _ShadowRange);
half4 diffuseCol = shadowMask * _BasicBaseColor * _ShadowInt + (1 - shadowMask) * _BasicBaseColor;
```

### Specular

高光使用Blinn-Phong模型进行计算。

为了控制高光点中心的位置偏移，使用三个参数作为欧拉角，去偏移世界空间中的半角向量方向，从而实现对高光点位置的控制。

为了实现卡通的二分效果，使用`step()`去对Blinn-Phong计算出来的结果进行二分处理，其中同样是为了把Specular Range参数在0-1之间，使用了一些数值对相关的项进行了调整。

最后得到的二分结果乘上了之前漫反射中计算出来的亮部遮罩，保证在暗部没有高光表现

```glsl
float3 viewDir = normalize(_WorldSpaceCameraPos.xyz - i.posWS.xyz);
half3 halfDir = normalize(viewDir.xyz + i.normalWS.xyz);
//Use Eula angle to offset the specular point
float alpha = _SpecOffsetWorldZRot;
float beta = _SpecOffsetWorldYRot;
float gamma = _SpecOffsetWorldXRot;
float3x3 Mat_Rotation = float3x3(cos(alpha)*cos(beta), cos(alpha)*sin(beta)*sin(gamma) - sin(alpha)*cos(gamma), cos(alpha)*sin(beta)*cos(gamma) + sin(alpha)*sin(gamma),
                sin(alpha)*cos(beta), cos(alpha)*cos(gamma) + sin(alpha)*sin(beta)*sin(gamma), sin(alpha)*sin(beta)*cos(gamma) - sin(gamma)*cos(alpha),
                -sin(beta), cos(beta)*sin(gamma), cos(beta)*cos(gamma));
halfDir = mul(Mat_Rotation, halfDir);
half specMask = step(0.99 + 0.01 * (1.0 - _SpecRange), pow(dot(halfDir, lightDir), 2.0)) * (1.0 - shadowMask);
half4 specColor = _BasicSpecColor * _SpecInt;
half4 diffSpecCol = specColor * specMask + (1.0 - specMask) * diffuseCol;
```

### Rim Light

边缘光实现的是屏幕空间等距边缘光，其原理是将模型在齐次裁剪空间下进行一定程度地沿法线的外扩，对比片元在外扩前后的深度值，如果深度值相差比较大，则判定该片元是边缘光区域，以此得到的边缘光遮罩。需要注意的一点是，如果模型会动（比如人物模型），需要在URP管线中设置Early Z为Force，以保证边缘光的质量。

```glsl
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
```

### Outline

描边使用的是Back-face描边技术，在另一个Pass中将模型沿着法线外扩一定大小进行渲染，并通过Cull Front让这个Pass只渲染模型的背面，以显示出原本非描边Pass的模型。外扩操作也是在齐次裁剪空间中完成的，由于后续透视除法的存在，描边的粗细会随着距离的远近而改变，可以通过一些参数控制描边大小的缩放比例（比如靠近后描边扩大的效果）。但是，因为是在齐次裁剪空间中完成的外扩，横纵外扩比率需要适配后续显示器屏幕映射时的比率，所以计算了一个`HdivV`去平衡横纵比例关系。

```glsl
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
```



## Kajiya-Kai头发渲染

![image-20230924163324504](http://qiuhanblog-imgsubmit.oss-cn-beijing.aliyuncs.com/img/image-20230924163324504.png)

实现的效果：

- 双层各向异性高光表现出的“天使轮”效果
- 两层天使轮各自独立，并且各自可以控制颜色、位置、强度

### Anisotropic

先说一说我对各向异性的理解

基于微表面模型来看，各向同性表面的微表面模型如下图所示，无论光滑还是粗糙的表面，每一个微表面的朝向都是相对要更随机的，最终从宏观视角看来，整个表面的法线可以统一视为一条垂直于平面的向量。

![各向同性表面](http://qiuhanblog-imgsubmit.oss-cn-beijing.aliyuncs.com/img/TA100T5110-23.png)

但是对于各向异性表面来说，它的每一个微表面的朝向，有着一定的分布趋势。假设我们取一个足够小的平面，这个平面表现出来的各向异性是单向的，此时将法线沿着x-z平面和y-z平面进行分解，各向异性平面表现出来的特征是，微表面在某一个平面上法线的加和方向，在不同的视角方向下趋于与平面垂直，而另一个平面上法线的加和方向，会随着视角的方向改变。这样带来的结果就是，各向异性表面有一种“抓痕”的感觉。

![各向异性表面及法线的分解](http://qiuhanblog-imgsubmit.oss-cn-beijing.aliyuncs.com/img/f4b770b774bacae9b89506a0fcb3356.jpg)

表现在计算上，各向异性表面的影响就是一个片元不单单有一个法线，意味着我们不能通过原本的法线来计算光照信息。由于漫反射表现出的是更低频的信息，所以可以继续使用原本的法线进行计算，但是对于高光这一高频信息的表现来说，就不能再使用原本的法线进行计算，就需要另辟蹊径。

因为各向异性表面有这样趋向于某个特定方向的“抓痕”，我们可以看出，一个顶点的法线虽然会随着视角改变，但它沿着抓痕方向的向量不会随着视角改变，也就是顶点的切线或副切线（具体要看划痕方向和模型信息，以下先统一说作切线）。所以我们就可以利用切线和视角向量来重构出该顶点随着视角方向而改变的法线。

重构的过程很简单，将切线和视角向量进行叉乘即可，但是如果是在使用Blinn-Phong模型计算高光，就有一些可采取的技巧。

![Kajiya-Kay Model中的发丝图片，有助于此处的理解](http://qiuhanblog-imgsubmit.oss-cn-beijing.aliyuncs.com/img/image-20230925083237708.png)

因为最终在计算各向异性表面的光照时，不管用是Phong模型还是Blin-Phong模型，切线、重构出来的法线、视角向量、光照方向向量四者是共面的，那么由视角向量和光照方向向量计算出来的半角向量也是在这个共面的平面内的。先如上图只看H在N和T之间的情况（也就是会看到高光的情况），可以发现T和H的夹角与N和H的夹角是互余的。而计算Blinn-Phong光照模型时，需要`dot(N, H)`，因为N和H都是长度为一的方向向量，所以点乘得到的结果其实是H和N之间夹角的余弦值，又因为互余，所以等于H和T之间夹角的正弦值。最终我们只需要计算`dot(H, T)`便可推出`dot(N, H)`，进而计算基于Blinn-Phong的各向异性表面光照模型



### Kajiya-Kay头发渲染模型

#### 高光表现原理

首先，因为头发的朝向具有相同的方向趋向，所以在宏观视角下，可以将不会大幅飘动的头发视作一个各向异性的平面，趋向的方向就是头发发丝的朝向。Kayjiya-Kay的头发渲染模型就以此为基础，将头发建模为一个几何体的各向异性的表面。

![将头发视为模型表面](http://qiuhanblog-imgsubmit.oss-cn-beijing.aliyuncs.com/img/image-20230925084607130.png)

但是只是看做一个简单的各向异性表面，看不出头发的特点，尤其是头发的高光区域。所以使用一张高度图去头发表面高低起伏的感觉。模拟的原理是用一张高度图模拟切线向内或外的偏移，通过影响半角向量和切线之间的夹角来模拟出头发表面凹凸不平的效果

![偏移切线模拟头发表面凹凸](http://qiuhanblog-imgsubmit.oss-cn-beijing.aliyuncs.com/img/image-20230925090552279.png)

然后再实际分析头发的高光区域可以看出，头发的高光可以大致分为两层：来自头发表层的强高光和偏向于发根的弱高光，所以在后续的计算模型中，也是分出了高频和低频两层去进行高光的渲染

![GDC 2004 - Hari Rendering and Shading](http://qiuhanblog-imgsubmit.oss-cn-beijing.aliyuncs.com/img/image-20230925085820284.png)

对于第一层，Kajiya-Kay模型中使用了一张频率更低的噪声图去偏移切线，表现整体的凹凸感。而对于第二层，使用的是一张频率更高的噪声图，去叠加额外的细节，并补充亮度没那么强的次高光区域。

![高频高度图](http://qiuhanblog-imgsubmit.oss-cn-beijing.aliyuncs.com/img/image-20230925091139296.png)

![低频高度图](http://qiuhanblog-imgsubmit.oss-cn-beijing.aliyuncs.com/img/image-20230925091216870.png)

最终将两层叠加在一起，可以得到有“天使轮”和两层高光的头发高光模型

```glsl
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
```

#### 头发深度的处理

在最终的渲染中，由于需要开启Alpha Test，所以无法使用Early-Z，他们给出的解决方案是使用Prime Z Buffer，单独为Alpha Test的区域写入深度值。整体渲染分为了以下四个Pass：

- Pass 1：Prime Z Buffer，禁用Color Buffer的写入，只写入Alpha值
- Pass 2：渲染不透明区域
- Pass 3：渲染半透明区域的背面
- Pass 4：渲染半透明区域的正面

























































