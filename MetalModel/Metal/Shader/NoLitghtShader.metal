//
//  NoLitShader.metal
//  MetalModel
//
//  Created by M.Ike on 2015/12/30.
//  Copyright © 2015年 M.Ike. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

// ライティングなしでテクスチャ色をそのまま出力するシェーダ

struct VertexInput {
    float3      position    [[ attribute(0) ]];
    float3      normal      [[ attribute(1) ]];
    half2       texcoord    [[ attribute(2) ]];
};

struct VertexUniforms {
    float4x4    projectionView;
    float4x4    normal;
};

struct ShaderInOut {
    float4      position    [[ position ]];
    half2       texcoord;
};

vertex ShaderInOut noLightVertex(VertexInput in [[stage_in]],
                                 constant VertexUniforms& uniforms [[ buffer(1) ]]) {
    ShaderInOut out;
    out.position = uniforms.projectionView * float4(in.position, 1.0);
    out.texcoord = in.texcoord;
    return out;
}

fragment half4 noLightFragment(ShaderInOut in [[ stage_in ]],
                               texture2d<half>  diffuseTexture [[ texture(0) ]]) {
    constexpr sampler defaultSampler;
    half4 color =  diffuseTexture.sample(defaultSampler, float2(in.texcoord));
    return color;
}
