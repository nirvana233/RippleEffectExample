Shader "Hidden/Ripple Effect"
{
    Properties
    {
        _MainTex("Base", 2D) = "white" {}
        _GradTex("Gradient", 2D) = "white" {}
        _Reflection("Reflection Color", Color) = (0, 0, 0, 0)
        _Params1("Parameters 1", Vector) = (1, 1, 0.8, 0)
        _Params2("Parameters 2", Vector) = (1, 1, 1, 0)
        _Drop1("Drop 1", Vector) = (0.49, 0.5, 0, 0)
        _Drop2("Drop 2", Vector) = (0.50, 0.5, 0, 0)
        _Drop3("Drop 3", Vector) = (0.51, 0.5, 0, 0)
		_SeaLevel("SeaVevel", Float) = -1.0
    }
    CGINCLUDE
    #include "UnityCG.cginc"

    sampler2D _MainTex;//输入源图像
    float2 _MainTex_TexelSize;
    sampler2D _GradTex;//涟漪振幅
    half4 _Reflection;
    float4 _Params1;    // [ aspect, 1, scale, 0 ]
    float4 _Params2;    // [ 1, 1/aspect, refraction, reflection ]
    float3 _Drop1;//涟漪1
    float3 _Drop2;//涟漪2
    float3 _Drop3;//涟漪3
	float _SeaLevel;

	//position,乘以宽高比率后的uv（当前片元对应的UV）； origin，乘以宽高比后的初始点（0.5，0.5）* （aspect，1）；time，过去了的时间
	//水波速度快指的是采样曲线变化快，同样的曲线，采样快的先变化完，感觉就是波纹速度快了
    float wave(float2 position, float2 origin, float time) //当前点位置, 出发点位置, 时间
    {
        float d = length(position - origin); //计算当前点到出发点的距离
        float t = time - d * _Params1.z; //计算已扩散时间	 _Params1.z：1/speed	 时间刚开始的时候，越近的越先出现波纹
		if (_SeaLevel > 0 && position.y > _SeaLevel)// 超过海平面则不再扩散
		{
			return 0;
		}
		return (tex2D(_GradTex, float2(t, 0)).a - 0.5f) * 2; //在波形曲线上得到振幅(-1,1)	 
    }			   
    float allwave(float2 position)// 计算当前点在三个涟漪下的共同作用效果（因为涟漪之间可能相交）
    {
		return
			wave(position, _Drop1.xy, _Drop1.z) +
			wave(position, _Drop2.xy, _Drop2.z) +
			wave(position, _Drop3.xy, _Drop3.z);
    }
	//伪代码 [RippleEffect.shader]  
    half4 frag(v2f_img i) : SV_Target
    {
        const float2 dx = float2(0.01f, 0);//delta x	 波纹宽度大小，强度！！！！！！！！！！！！！！
        const float2 dy = float2(0, 0.01f);// delta y
        float2 p = i.uv * _Params1.xy;//根据比例变换uv   //根据相机比例变换当前点的UV坐标 _Params1	==  c.aspect, 1, 1 / waveSpeed, 0
        float w = allwave(p);//振幅，用振幅来对当前点做UV上面的偏移，即可产生涟漪效果
        float2 dw = float2(allwave(p + dx) - w, allwave(p + dy) - w);//xy上振幅
        float2 duv = dw * _Params2.xy * 0.2f * _Params2.z; //uv上振幅	  --_Params2.xy == 1, 1 / c.aspect ，refractionStrength，reflectionStrength
        half4 c = tex2D(_MainTex, i.uv + duv);//在原图上做偏移
        float fr = pow(length(dw) * 3 * _Params2.w, 3);
        return lerp(c, _Reflection, fr);//lerp来实现反射效果,优化表现
    }
    ENDCG
    SubShader
    {
        Pass
        {
            ZTest Always Cull Off ZWrite Off
            Fog { Mode off }
            CGPROGRAM
            #pragma fragmentoption ARB_precision_hint_fastest 
            #pragma target 3.0
            #pragma vertex vert_img
            #pragma fragment frag
            ENDCG
        }
    } 
}
