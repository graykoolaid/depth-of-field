//--------------------------------------------------------------------------------------
// File: Tutorial0510.fx
//
// Copyright (c) Microsoft Corporation. All rights reserved.
//--------------------------------------------------------------------------------------

//DEBUG
//fxc /Od /Zi /T fx_4_0 /Fo BasicHLSL10.fxo BasicHLSL10.fx

Texture2D txDiffuse0;
Texture2D txDiffuse1;
Texture2D shadowMap;
Texture2D renderTargetMap;
Texture2D velocityMap;


Texture2D shaderTextures[20];
int texSelect;

//--------------------------------------------------------------------------------------
// Constant Buffer Variables
//--------------------------------------------------------------------------------------
cbuffer cbNeverChanges
{
	float zNear;
	float zFar;
};
    
cbuffer cbChangeOnResize
{
    matrix Projection;
};
    
cbuffer cbChangesEveryFrame
{
    matrix World;
	float4 vLightDir[10];
	float4 vLightColor[10];
	float4 vOutputColor;
	int		texSelectIndex;
	matrix View;

	float4x4 lightViewProj;
	float4x4 lightView;

	matrix viewInvProj;
	matrix viewPrevInvProj;
	matrix ViewPrev;
};




SamplerState samLinear
{
    Filter = MIN_MAG_MIP_LINEAR;
    AddressU = Wrap;
    AddressV = Wrap;
};

SamplerState pointSampler
{
	Filter = MIN_MAG_MIP_POINT;
	AddressU = MIRROR;
	AddressV = MIRROR;
};

SamplerState clampSampler
{
	Filter = MIN_MAG_MIP_POINT;
	AddressU = CLAMP;
	AddressV = CLAMP;
};

//--------------------------------------------------------------------------------------
struct VS_INPUT
{
    float4 Pos		: POSITION;
	float4 Normal	: NORMAL;
	float2 Tex		: TEXCOORD;
	int TexNum	    : TEXNUM;
};

struct PS_INPUT
{
    float4 Pos		: SV_POSITION;
	float4 Normal	: NORMAL;
	float2 Tex		: TEXCOORD0;
	int TexNum      : TEXNUM;
	float4 lpos		: TEXCOORD1;
	float4 wpos		: TEXCOORD2;
	float depth		: DEPTH;
	float midDepth	: DEPTHMID;
};



PS_INPUT VS( VS_INPUT input )
{
	PS_INPUT output = (PS_INPUT)0;
	   
    output.Pos = mul( input.Pos, World );
    output.Pos = mul( output.Pos, View );
    output.Pos = mul( output.Pos, Projection );
    output.Normal = mul( input.Normal, World );
    output.Tex    = input.Tex;
	output.TexNum = input.TexNum;

	output.lpos = mul( mul(input.Pos, World), mul(lightView,Projection)  );
	//output.lpos = mul( mul(input.Pos, World), lightViewProj  );
	//output.lpos = mul( output.Pos, mul(View,lightViewProj)  );
	//output.lpos = mul( output.Pos, lightViewProj );
	//output.lpos = mul( mul(input.Pos, World), lightViewProj  );
	//output.wpos = input.Pos;
	output.wpos = mul( input.Pos, World );
	output.depth = ( output.Pos.z - zNear ) / ( zFar - zNear );

    return output;
}

float ambient = .3;
float diffuse = .6;
float SHADOW_VAL( PS_INPUT input)
{
 //re-homogenize position after interpolation
    input.lpos.xyz /= input.lpos.w;
 
	    if( input.lpos.x < -1.0f || input.lpos.x > 1.0f ||
        input.lpos.y < -1.0f || input.lpos.y > 1.0f ||
        input.lpos.z < 0.0f  || input.lpos.z > 1.0f ) return ambient;

    //transform clip space coords to texture space coords (-1:1 to 0:1)
    input.lpos.x = input.lpos.x/2 + 0.5;
    input.lpos.y = input.lpos.y/-2 + 0.5;
 
	input.lpos.z -= .0001;
//	input.lpos.z -= shadowMapBias;

    //sample shadow map - point sampler
	float shadowMapDepth = shadowMap.Sample(pointSampler, input.lpos.xy).r;

	//return float4( shadowMapDepth, shadowMapDepth, shadowMapDepth, 1.0 );

    //if clip space z value greater than shadow map value then pixel is in shadow
    if ( shadowMapDepth < input.lpos.z) return ambient;
 
    //otherwise calculate ilumination at fragment
    float3 L = normalize((float3)vLightDir[0] - input.wpos.xyz);
    float ndotl = dot( normalize(input.Normal), L);
    return ambient + diffuse*ndotl;
}


float4 PS( PS_INPUT input) : SV_Target
{
	float4 LightColor = 0;

	float4 textureFinal = float4( 1.0,1.0,1.0,1.0 );
        
    //do NdotL lighting for 2 lights
    for(int i=0; i<4; i++)
    {
        LightColor += saturate( dot( (float3)vLightDir[i],input.Normal) * vLightColor[i]);
    }

	LightColor.a = 1.0;

	if( texSelect == input.TexNum)
		return float4( 0.0, 1.0, 0.0, 0.0 );


	if( texSelect == -2 )
		textureFinal = float4( 0.0, (1.0 -( (float)input.TexNum * .10)), 0.0, 1.0 );

		int texnum = input.TexNum;
		
	//quick hack to make to expand it to large values. change 10 if more than 10 tex on an object
	for( int i = 0; i < 10; i++ )
	{
		if( i == input.TexNum )
		{
			textureFinal = shaderTextures[i].Sample( samLinear, input.Tex )*LightColor;
		}
	}

	clip( textureFinal.a - .5f );


	float shadow = SHADOW_VAL( input );

	float4 finalColor = textureFinal * shadow;
	//if this is white you got issues
	finalColor.a = input.depth;
	return finalColor;
	//return float4(shadow, shadow, shadow, 1.0) * shadow;
	//return float4( 1.0, 1.0, 1.0, 1.0 );

}

//------------------------------------------------------
// Render ShadowMap
//-----------------------------------------------------
PS_INPUT ShadowMapVS( VS_INPUT input )
{
	PS_INPUT output = (PS_INPUT)0;
	   
	output.Pos = mul( input.Pos, World  );
	output.Pos = mul( output.Pos, lightView );
	output.Pos = mul( output.Pos, lightViewProj );
    output.Normal = mul( input.Normal, World );
    output.Tex    = input.Tex;
	output.TexNum = input.TexNum;
	//return input.Pos.z;
    return output;
}

void ShadowMapPS( PS_INPUT input ) //: SV_Depth
{
	//float depth = input.Pos.z / input.Pos.w;
	//clip( shaderTextures[1].Sample( samLinear, input.Tex ) - .2);
	for( int i = 0; i < 10; i++ )
	{
		if( i == input.TexNum )
		{
			clip( shaderTextures[i].Sample( samLinear, input.Tex ) - .3 );
		}
	}
}


PS_INPUT ViewWindowVS( VS_INPUT input )
{
	PS_INPUT output = (PS_INPUT)0;
	   
    output.Pos = mul( input.Pos, World );
    output.Pos = mul( output.Pos, View );
    output.Pos = mul( output.Pos, Projection );
    output.Normal = mul( input.Normal, World );
    output.Tex    = input.Tex;
   // output.Tex.x    = -input.Tex.x;
    output.Tex.y    = -input.Tex.y ;
	output.TexNum = input.TexNum;

	output.lpos = mul( mul(input.Pos, World), mul(View,Projection)  );
	//output.lpos = mul( mul(input.Pos, World), lightViewProj  );
	//output.lpos = mul( output.Pos, mul(View,lightViewProj)  );
	//output.lpos = mul( output.Pos, lightViewProj );
	//output.lpos = mul( mul(input.Pos, World), lightViewProj  );
	//output.wpos = input.Pos;
	output.wpos = mul( input.Pos, World );

	//output.ViewProjInvMat = mul( View, Projection );


    return output;
}




float SHADOW_VAL2( PS_INPUT input)
{
 //re-homogenize position after interpolation
    input.lpos.xyz /= input.lpos.w;
 
    //transform clip space coords to texture space coords (-1:1 to 0:1)
    input.lpos.x = input.lpos.x/2 + 0.5;
    input.lpos.y = input.lpos.y/-2 + 0.5;
 
    //sample shadow map - point sampler
	float shadowMapDepth = velocityMap.Sample(pointSampler, input.lpos.xy).r;
	return shadowMapDepth;
}



float4 ViewWindowPS( PS_INPUT input) : SV_Target
{
	// Debug Values Shows either the render texture or the velocity map
	float shadow = SHADOW_VAL2( input );
	//return float4( shadow, shadow, shadow, 1.0 );
	//return renderTargetMap.Sample( samLinear, input.Tex );
	float2 texCoords = input.Tex;
	// Get the depth buffer value at this pixel.  
	//float zOverW = velocityMap.Sample(pointSampler, float2(input.Tex.x, input.Tex.y) ).r;  
	float zOverW = velocityMap.Sample(samLinear, input.Tex).r;  
	//float zOverW = shadow;
	// H is the viewport position at this pixel in the range -1 to 1.  
	float4 H = float4(input.Tex.x * 2 - 1, (1 - input.Tex.y) * 2 - 1,  zOverW, 1);  
	//float4 H = float4(input.Tex.x , (1 - input.Tex.y) ,  zOverW, 1);  
	// Transform by the view-projection inverse.  
	float4 D = mul(H, viewInvProj);  
	// Divide by w to get the world position.  
	float4 worldPos = D / D.w;  

	// Current viewport position  
	float4 currentPos = H;  
	// Use the world position, and transform by the previous view-  
	// projection matrix.  
//	float4 previousPos = mul(worldPos, viewPrevInvProj);  
	float4 previousPos = mul(worldPos, mul(ViewPrev, Projection) );  
	//float4 previousPos = mul(H, viewPrevInvProj);  
	// Convert to nonhomogeneous points [-1,1] by dividing by w.  
	previousPos /= previousPos.w;  
	// Use this frame's position and last frame's to compute the pixel  
	// velocity.  
	float2 velocity = (currentPos.xy - previousPos.xy)/2.f/8;  
	//float2 velocity = (-currentPos.xy + previousPos.xy)/2.f*10.; 
	//velocity.y = -velocity.y;
	//float2 velocity = (viewInvProj - viewPrevInvProj)/1000.f;  

	// Get the initial color at this pixel.  
	float4 color = renderTargetMap.Sample( samLinear, float2(texCoords.x, texCoords.y) );  
	texCoords += velocity;  
	//for(int i = 1; i < g_numSamples; ++i, input.Tex += velocity)  
	int samples = 5;
	for(int i = 1; i < samples; ++i, texCoords += velocity)  
	{  
		// Sample the color buffer along the velocity vector.  
		float4 currentColor = renderTargetMap.Sample( samLinear, float2(texCoords.x, texCoords.y) ); 
		// Add the current color to our color sum.  
		color += currentColor;  
	}  
	// Average all of the samples to get the final blur color.  
	//float4 finalColor = color / numSamples;  
	float4 finalColor = color / samples; 
	return finalColor;
}


float4 ViewWindowPS2( PS_INPUT input) : SV_Target
{
	//float4 color = renderTargetMap.Sample( samLinear, input.Tex );
	float4 color = velocityMap.Sample( samLinear, input.Tex );
	color.r = 2*zFar*zNear / (zFar + zNear - (zFar - zNear)*(2*color.r -1));
	//float midDepth =  renderTargetMap.Sample( samLinear, float2( .5, .5 ) ).w;
	
	float z_b = velocityMap.Sample( samLinear, float2( .5, .5 ) ).r;
	float midDepth = 2*zFar*zNear / (zFar + zNear - (zFar - zNear)*(2*z_b -1));
	float blurFactor = 1.0;

	float depthRange = .5 * (zFar - zNear );

	if( color.r > midDepth - depthRange && color.r < midDepth + depthRange )
	{
		color = renderTargetMap.Sample( samLinear, input.Tex );
		return color;
	}
	else
	{
		if( abs( midDepth + depthRange - color.r ) > abs( midDepth - depthRange - color.r ) )
			blurFactor =  ( ( midDepth - depthRange - color.r ) - zNear ) / ( zFar - zNear );
		else
			blurFactor =  ( ( midDepth + depthRange - color.r ) - zNear ) / ( zFar - zNear );

		blurFactor = abs( blurFactor );
			
	}
	color = renderTargetMap.Sample( samLinear, input.Tex );
	//return 0.0;
	float blur = .004;
	//blur = blur / blurFactor;
	color += renderTargetMap.Sample( samLinear, float2( input.Tex.x+blur, input.Tex.y ) );
	color += renderTargetMap.Sample( samLinear, float2( input.Tex.x-blur, input.Tex.y ) );
	color += renderTargetMap.Sample( samLinear, float2( input.Tex.x, input.Tex.y+blur ) );
	color += renderTargetMap.Sample( samLinear, float2( input.Tex.x, input.Tex.y-blur ) );

	color += renderTargetMap.Sample( samLinear, float2( input.Tex.x-blur, input.Tex.y-blur ) );
	color += renderTargetMap.Sample( samLinear, float2( input.Tex.x+blur, input.Tex.y-blur ) );
	color += renderTargetMap.Sample( samLinear, float2( input.Tex.x-blur, input.Tex.y+blur ) );
	color += renderTargetMap.Sample( samLinear, float2( input.Tex.x+blur, input.Tex.y+blur ) );

	color = color / 9;
	color.a = 1.0;

	//color = velocityMap.Sample( samLinear, input.Tex ).r;
	return color;
}


//--------------------------------------------------------------------------------------
technique10 Render
{
    pass P0
    {
        SetVertexShader( CompileShader( vs_4_0, VS() ) );
        SetGeometryShader( NULL );
        SetPixelShader( CompileShader( ps_4_0, PS() ) );
    }
}

//--------------------------------------------------------------------------------------
technique10 RenderShadowMap
{
    pass P0
    {
       // SetVertexShader( CompileShader( vs_4_0, ShadowMapVS() ) );
        SetVertexShader( CompileShader( vs_4_0, ShadowMapVS() ) );
        SetGeometryShader( NULL );
        SetPixelShader( NULL );
        SetPixelShader( CompileShader( ps_4_0, ShadowMapPS() ) );

    }
}

technique10 RenderVelocityMap
{
    pass P0
    {
       // SetVertexShader( CompileShader( vs_4_0, ShadowMapVS() ) );
        SetVertexShader( CompileShader( vs_4_0, VS() ) );
        SetGeometryShader( NULL );
        SetPixelShader( CompileShader( ps_4_0, ShadowMapPS() ) );
        //SetPixelShader( NULL );
    }
}

technique10 RenderViewWindow
{
    pass P0
    {
        SetVertexShader( CompileShader( vs_4_0, ViewWindowVS() ) );
        SetGeometryShader( NULL );
        SetPixelShader( CompileShader( ps_4_0, ViewWindowPS2() ) );
    }
}