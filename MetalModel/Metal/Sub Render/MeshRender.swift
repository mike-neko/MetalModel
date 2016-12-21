//
//  MeshRender.swift
//  MetalModel
//
//  Created by M.Ike on 2015/12/30.
//  Copyright © 2015年 M.Ike. All rights reserved.
//

import UIKit
import MetalKit

/* メッシュ描画用 */
class MeshRender: RenderProtocol {
    // Indices of vertex attribute in descriptor.
    enum VertexAttribute: Int {
        case position = 0
        case normal = 1
        case texcoord = 2
        func index() -> Int { return self.rawValue }
    }
    
    fileprivate var pipelineState: MTLRenderPipelineState! = nil
    fileprivate var depthState: MTLDepthStencilState! = nil
    
    // Meshes
    fileprivate var meshes: [Mesh]! = nil
    fileprivate var frameUniformBuffers: [MTLBuffer] = []
    
    // Uniforms
    var modelMatrix = float4x4(matrix_identity_float4x4)
    
    func setup(vertexShaderName: String, fragmentShaderName: String, model: String) -> Bool {
        let device = Render.current.device
        let mtkView = Render.current.mtkView
        let library = Render.current.library
        
        guard let vertex_pg = library?.makeFunction(name: vertexShaderName) else { return false }
        guard let fragment_pg = library?.makeFunction(name: fragmentShaderName) else { return false }
        
        let vertexDescriptor = MTLVertexDescriptor()
        // Positions.
        let attr_pos = vertexDescriptor.attributes[VertexAttribute.position.index()]
        attr_pos?.format = .float3
        attr_pos?.offset = 0
        attr_pos?.bufferIndex = Mesh.Buffer.meshVertex.index()
        
        // Normals.
        let attr_nor = vertexDescriptor.attributes[VertexAttribute.normal.index()]
        attr_nor?.format = .float3
        attr_nor?.offset = 12
        attr_nor?.bufferIndex = Mesh.Buffer.meshVertex.index()
        
        // Texture coordinates.
        let attr_tex = vertexDescriptor.attributes[VertexAttribute.texcoord.index()]
        attr_tex?.format = .half2
        attr_tex?.offset = 24
        attr_tex?.bufferIndex = Mesh.Buffer.meshVertex.index()
        
        // Single interleaved buffer.
        let layout = vertexDescriptor.layouts[Mesh.Buffer.meshVertex.index()]
        layout?.stride = 28;
        layout?.stepRate = 1;
        layout?.stepFunction = .perVertex
        
        // Create a reusable pipeline state
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.label = "MeshPipeLine"
        pipelineDescriptor.sampleCount = (mtkView?.sampleCount)!
        pipelineDescriptor.vertexFunction = vertex_pg
        pipelineDescriptor.fragmentFunction = fragment_pg
        pipelineDescriptor.vertexDescriptor = vertexDescriptor
        pipelineDescriptor.colorAttachments[0].pixelFormat = (mtkView?.colorPixelFormat)!
        pipelineDescriptor.depthAttachmentPixelFormat = (mtkView?.depthStencilPixelFormat)!
        pipelineDescriptor.stencilAttachmentPixelFormat = (mtkView?.depthStencilPixelFormat)!
        do {
            pipelineState = try device?.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            return false
        }
        
        let depthDescriptor = MTLDepthStencilDescriptor()
        depthDescriptor.depthCompareFunction = .less
        depthDescriptor.isDepthWriteEnabled = true
        depthState = device?.makeDepthStencilState(descriptor: depthDescriptor)
        
        let modelDescriptor = MTKModelIOVertexDescriptorFromMetal(vertexDescriptor)
        let mdl_attrs = modelDescriptor.attributes
        (mdl_attrs[VertexAttribute.position.index()] as! MDLVertexAttribute).name = MDLVertexAttributePosition
        (mdl_attrs[VertexAttribute.normal.index()] as! MDLVertexAttribute).name = MDLVertexAttributeNormal
        (mdl_attrs[VertexAttribute.texcoord.index()] as! MDLVertexAttribute).name = MDLVertexAttributeTextureCoordinate
        
        let bufAllocator = MTKMeshBufferAllocator(device: device!)
        guard let url = Bundle.main.url(forResource: model, withExtension: nil) else { return false }
        let asset = MDLAsset(url: url, vertexDescriptor: modelDescriptor, bufferAllocator: bufAllocator)
        
        // Create MetalKit meshes.
        let mtkMeshes: NSArray?
        var mdlMeshes: NSArray?
        do {
            mtkMeshes = try MTKMesh.newMeshes(from: asset, device: device!, sourceMeshes: &mdlMeshes) as NSArray?
        } catch {
            return false
        }
        
        // Create our array of App-Specific mesh wrapper objects.
        meshes = mtkMeshes?.enumerated().map {
            Mesh(mtkMesh: $0.1 as! MTKMesh, mdlMesh: mdlMeshes![$0.0] as! MDLMesh, device: device!)
        }
        
        // Create a uniform buffer that we'll dynamicall update each frame.
        for _ in 0..<Render.BufferCount {
            guard let buf = device?.makeBuffer(length: MemoryLayout<VertexUniforms>.size, options: MTLResourceOptions())else {
                return false
            }
            frameUniformBuffers.append(buf)
        }
        return true
    }
    
    func update() {
        let ren = Render.current
        
        let p = frameUniformBuffers[ren.activeBufferNumber].contents().assumingMemoryBound(to: VertexUniforms.self)
        var uni = p.pointee
        let mat = ren.cameraMatrix * modelMatrix
        uni.projectionView = ren.projectionMatrix * mat
        uni.normal = mat.inverse.transpose
        p.pointee = uni
    }
    
    func render(_ renderEncoder: MTLRenderCommandEncoder) {
        renderEncoder.pushDebugGroup("Render Meshes")
        
        // Set context state.
        renderEncoder.setDepthStencilState(depthState)
        renderEncoder.setRenderPipelineState(pipelineState)
        
        // Set the our per frame uniforms.
        renderEncoder.setVertexBuffer(
            frameUniformBuffers[Render.current.activeBufferNumber],
            offset: 0,
            at: Mesh.Buffer.frameUniform.index())
        
        // Render each of our meshes.
        meshes.forEach { mesh in mesh.render(renderEncoder) }
        
        renderEncoder.popDebugGroup()
    }
}

