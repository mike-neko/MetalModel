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
        case MeshVertex = 0
        case FrameUniform = 1
        case MaterialUniform = 2
        func index() -> Int { return self.rawValue }
    }
    
    let mesh: MTKMesh
    let submeshes: [Submesh]
    
    init(mtkMesh: MTKMesh, mdlMesh: MDLMesh, device: MTLDevice) {
        mesh = mtkMesh
        submeshes = mdlMesh.submeshes.enumerate().map {
            Submesh(mtkSubmesh: mtkMesh.submeshes[$0.0], mdlSubmesh: $0.1 as! MDLSubmesh, device: device)
        }
    }
    
    func render(encoder: MTLRenderCommandEncoder) {
        for vb in mesh.vertexBuffers.enumerate() {
            if let buffer: MTKMeshBuffer = vb.1 {
                encoder.setVertexBuffer(buffer.buffer, offset: buffer.offset, atIndex: vb.0)
            }
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
        materialUniforms = device.newBufferWithLength(sizeof(MaterialColor), options: .CPUCacheModeDefaultCache)
        submesh = mtkSubmesh
        
        var uniforms = UnsafePointer<MaterialColor>(materialUniforms.contents()).memory
        for var i = 0; i < mdlSubmesh.material?.count; i++ {
            if let property = mdlSubmesh.material![i] {
                switch property.name {
                case "baseColorMap":
                    if property.type == .String {
                        let url = NSURL(fileURLWithPath: property.stringValue!)
                        let loader = MTKTextureLoader(device: device)
                        do {
                            diffuseTexture = try loader.newTextureWithContentsOfURL(url, options: nil)
                        } catch {
                            diffuseTexture = nil
                        }
                    }
                case "specularColor":
                    switch property.type {
                    case .Float4:
                        uniforms.specular = property.float4Value
                    case .Float3:
                        let col = property.float3Value
                        uniforms.specular = float4([col.x, col.y, col.z, 1])
                    default: break
                    }
                case "emission":
                    switch property.type {
                    case .Float4:
                        uniforms.emissive = property.float4Value
                    case .Float3:
                        let col = property.float3Value
                        uniforms.emissive = float4([col.x, col.y, col.z, 1])
                    default: break
                    }
                default: break
                }
            }
        }
    }
    
    func render(encoder: MTLRenderCommandEncoder) {
        // Set material values and textures.
        if let tex = diffuseTexture {
            encoder.setFragmentTexture(tex, atIndex: 0)
        }
        encoder.setFragmentBuffer(materialUniforms, offset: 0, atIndex: Mesh.Buffer.MaterialUniform.index())
        encoder.setVertexBuffer(materialUniforms, offset: 0, atIndex: Mesh.Buffer.MaterialUniform.index())
        
        // Draw the submesh.
        encoder.drawIndexedPrimitives(submesh.primitiveType, indexCount: submesh.indexCount, indexType: submesh.indexType, indexBuffer: submesh.indexBuffer.buffer, indexBufferOffset: submesh.indexBuffer.offset)
    }
}
