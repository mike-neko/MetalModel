//
//  Mesh.swift
//  MetalModel
//
//  Created by M.Ike on 2015/12/30.
//  Copyright © 2015年 M.Ike. All rights reserved.
//

import UIKit
import MetalKit
// FIXME: comparison operators with optionals were removed from the Swift Standard Libary.
// Consider refactoring the code to use the non-optional operators.
fileprivate func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
    switch (lhs, rhs) {
    case let (l?, r?):
        return l < r
    case (nil, _?):
        return true
    default:
        return false
    }
}


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
        func index() -> Int { return self.rawValue }
    }
    
    let mesh: MTKMesh
    let submeshes: [Submesh]
    
    init(mtkMesh: MTKMesh, mdlMesh: MDLMesh, device: MTLDevice) {
        mesh = mtkMesh
        submeshes = (mdlMesh.submeshes?.enumerated().map {
            Submesh(mtkSubmesh: mtkMesh.submeshes[$0.0], mdlSubmesh: $0.1 as! MDLSubmesh, device: device)
            })!
    }
    
    func render(_ encoder: MTLRenderCommandEncoder) {
        for buffer in mesh.vertexBuffers.enumerated() {
            encoder.setVertexBuffer(buffer.1.buffer, offset: buffer.1.offset, at: buffer.0)
        }
        
        for sub in submeshes {
            sub.render(encoder)
        }
    }
}

class Submesh {
    let materialUniforms: MTLBuffer
    let submesh: MTKSubmesh
    var diffuseTexture: MTLTexture? = nil
    
    init(mtkSubmesh: MTKSubmesh, mdlSubmesh: MDLSubmesh, device: MTLDevice) {
        materialUniforms = device.makeBuffer(length: MemoryLayout<MaterialColor>.size, options: MTLResourceOptions())
        submesh = mtkSubmesh
        
        
        var uniforms = materialUniforms.contents().assumingMemoryBound(to: MaterialColor.self).pointee
        for i in 0..<(mdlSubmesh.material?.count ?? 0) {
            if let property = mdlSubmesh.material![i] {
                switch property.name {
                case "baseColorMap":
                    if property.type == .string {
                        let url = URL(fileURLWithPath: property.stringValue!)
                        let loader = MTKTextureLoader(device: device)
                        do {
                            diffuseTexture = try loader.newTexture(withContentsOf: url, options: nil)
                        } catch {
                            diffuseTexture = nil
                        }
                    }
                case "specularColor":
                    switch property.type {
                    case .float4:
                        uniforms.specular = property.float4Value
                    case .float3:
                        let col = property.float3Value
                        uniforms.specular = float4([col.x, col.y, col.z, 1])
                    default: break
                    }
                case "emission":
                    switch property.type {
                    case .float4:
                        uniforms.emissive = property.float4Value
                    case .float3:
                        let col = property.float3Value
                        uniforms.emissive = float4([col.x, col.y, col.z, 1])
                    default: break
                    }
                default: break
                }
            }
        }
    }
    
    func render(_ encoder: MTLRenderCommandEncoder) {
        // Set material values and textures.
        if let tex = diffuseTexture {
            encoder.setFragmentTexture(tex, at: 0)
        }
        encoder.setFragmentBuffer(materialUniforms, offset: 0, at: Mesh.Buffer.materialUniform.index())
        encoder.setVertexBuffer(materialUniforms, offset: 0, at: Mesh.Buffer.materialUniform.index())
        
        // Draw the submesh.
        encoder.drawIndexedPrimitives(type: submesh.primitiveType, indexCount: submesh.indexCount, indexType: submesh.indexType, indexBuffer: submesh.indexBuffer.buffer, indexBufferOffset: submesh.indexBuffer.offset)
    }
}
