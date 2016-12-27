//
//  Mesh.swift
//  MetalModel
//
//  Created by M.Ike on 2015/12/30.
//  Copyright © 2015年 M.Ike. All rights reserved.
//

import UIKit
import MetalKit

/* シェーダとやりとりする用 */
struct VertexUniforms {
    var projectionView: float4x4
    var normal: float4x4
}

struct MaterialColor {
    var emissive: float4
    var diffuse: float4
    var specular: float4
}

// MARK: -
class Mesh {
    // Indices for buffer bind points.
    enum Buffer: Int {
        case meshVertex = 0
        case frameUniform = 1
        case materialUniform = 2
        var index: Int { return self.rawValue }
    }
    
    let mesh: MTKMesh
    let submeshes: [Submesh]
    
    init(mtkMesh: MTKMesh, mdlMesh: MDLMesh, device: MTLDevice) {
        mesh = mtkMesh
        
        submeshes = mdlMesh.submeshes?.enumerated().flatMap {
            guard let sub = $0.1 as? MDLSubmesh else { return nil }
            return Submesh(mtkSubmesh: mtkMesh.submeshes[$0.0], mdlSubmesh: sub, device: device)
            } ?? []
    }
    
    func render(encoder: MTLRenderCommandEncoder) {
        mesh.vertexBuffers.enumerated().forEach {
            encoder.setVertexBuffer($0.1.buffer, offset: $0.1.offset, at: $0.0)
        }
        
        submeshes.forEach { $0.render(encoder: encoder) }
    }
}

class Submesh {
    let materialUniforms: MTLBuffer
    let submesh: MTKSubmesh
    var diffuseTexture: MTLTexture? = nil
    
    init(mtkSubmesh: MTKSubmesh, mdlSubmesh: MDLSubmesh, device: MTLDevice) {
        materialUniforms = device.makeBuffer(length: MemoryLayout<MaterialColor>.size, options: MTLResourceOptions())
        submesh = mtkSubmesh
        
        guard let material = mdlSubmesh.material  else { return }
        
        var uniforms = materialUniforms.contents().assumingMemoryBound(to: MaterialColor.self).pointee
        for i in 0 ..< material.count {
            guard let property = material[i] else { continue }
            
            switch (property.name, property.type) {
            case ("baseColorMap", .string):
                guard let path = property.stringValue else { continue }
                let url = URL(fileURLWithPath: path)
                let loader = MTKTextureLoader(device: device)
                diffuseTexture = try? loader.newTexture(withContentsOf: url, options: nil)
                
            case ("specularColor", .float4):
                uniforms.specular = property.float4Value
            case ("specularColor", .float3):
                let col = property.float3Value
                uniforms.specular = float4(col.x, col.y, col.z, 1)
                
            case ("emission", .float4):
                uniforms.emissive = property.float4Value
            case ("emission", .float3):
                let col = property.float3Value
                uniforms.emissive = float4(col.x, col.y, col.z, 1)
                
            default: continue
                
            }
        }
    }
    
    func render(encoder: MTLRenderCommandEncoder) {
        // Set material values and textures.
        if let tex = diffuseTexture {
            encoder.setFragmentTexture(tex, at: 0)
        }
        encoder.setFragmentBuffer(materialUniforms, offset: 0, at: Mesh.Buffer.materialUniform.index)
        encoder.setVertexBuffer(materialUniforms, offset: 0, at: Mesh.Buffer.materialUniform.index)
        
        // Draw the submesh.
        encoder.drawIndexedPrimitives(type: submesh.primitiveType,
                                      indexCount: submesh.indexCount,
                                      indexType: submesh.indexType,
                                      indexBuffer: submesh.indexBuffer.buffer,
                                      indexBufferOffset: submesh.indexBuffer.offset)
    }
}
