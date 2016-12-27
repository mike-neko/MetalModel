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
class MeshRender: RenderType {
    private enum VertexAttribute: Int {
        case position = 0
        case normal = 1
        case texcoord = 2
        var index: Int { return self.rawValue }
    }
    
    private let render: Render
    private var pipelineState: MTLRenderPipelineState!
    private var depthState: MTLDepthStencilState!
    
    // Meshes
    private var meshes: [Mesh] = []
    private var frameUniformBuffers: [MTLBuffer] = []
    
    // Uniforms
    var modelMatrix = float4x4(matrix_identity_float4x4)
    
    required init(render: Render) {
        self.render = render
    }
    
    func setup(vertexShaderName: String, fragmentShaderName: String, model: String) -> Bool {
        let device = render.device
        let library = render.library
        guard let mtkView = render.view else { return false }
        
        guard let vertex = library.makeFunction(name: vertexShaderName) else { return false }
        guard let fragment = library.makeFunction(name: fragmentShaderName) else { return false }
        
        let vertexDescriptor = MTLVertexDescriptor()
        // Positions.
        guard let pos = vertexDescriptor.attributes[VertexAttribute.position.index] else { return false }
        pos.format = .float3
        pos.offset = 0
        pos.bufferIndex = Mesh.Buffer.meshVertex.index
        
        // Normals.
        guard let normal = vertexDescriptor.attributes[VertexAttribute.normal.index] else { return false }
        normal.format = .float3
        normal.offset = 12
        normal.bufferIndex = Mesh.Buffer.meshVertex.index
        
        // Texture coordinates.
        guard let tex = vertexDescriptor.attributes[VertexAttribute.texcoord.index] else { return false }
        tex.format = .half2
        tex.offset = 24
        tex.bufferIndex = Mesh.Buffer.meshVertex.index
        
        // Single interleaved buffer.
        guard let layout = vertexDescriptor.layouts[Mesh.Buffer.meshVertex.index] else { return false }
        layout.stride = 28
        layout.stepRate = 1
        layout.stepFunction = .perVertex
        
        // Create a reusable pipeline state
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.label = "MeshPipeLine"
        pipelineDescriptor.sampleCount = mtkView.sampleCount
        pipelineDescriptor.vertexFunction = vertex
        pipelineDescriptor.fragmentFunction = fragment
        pipelineDescriptor.vertexDescriptor = vertexDescriptor
        pipelineDescriptor.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat
        pipelineDescriptor.depthAttachmentPixelFormat = mtkView.depthStencilPixelFormat
        pipelineDescriptor.stencilAttachmentPixelFormat = mtkView.depthStencilPixelFormat
        
        do {
            pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            return false
        }
        
        let depthDescriptor = MTLDepthStencilDescriptor()
        depthDescriptor.depthCompareFunction = .less
        depthDescriptor.isDepthWriteEnabled = true
        depthState = device.makeDepthStencilState(descriptor: depthDescriptor)
        
        let modelDescriptor = MTKModelIOVertexDescriptorFromMetal(vertexDescriptor)
        let mdlAttrs = modelDescriptor.attributes
        (mdlAttrs[VertexAttribute.position.index] as? MDLVertexAttribute)?.name = MDLVertexAttributePosition
        (mdlAttrs[VertexAttribute.normal.index] as? MDLVertexAttribute)?.name = MDLVertexAttributeNormal
        (mdlAttrs[VertexAttribute.texcoord.index] as? MDLVertexAttribute)?.name = MDLVertexAttributeTextureCoordinate
        
        let bufAllocator = MTKMeshBufferAllocator(device: device)
        guard let url = Bundle.main.url(forResource: model, withExtension: nil) else { return false }
        let asset = MDLAsset(url: url, vertexDescriptor: modelDescriptor, bufferAllocator: bufAllocator)
        
        // Create MetalKit meshes.
        let mtkMeshes: [MTKMesh]
        var mdlArray: NSArray?
        do {
            mtkMeshes = try MTKMesh.newMeshes(from: asset, device: device, sourceMeshes: &mdlArray)
        } catch {
            return false
        }
        
        // Create our array of App-Specific mesh wrapper objects.
        meshes = mtkMeshes.enumerated().flatMap {
            guard let mdl = mdlArray?[$0.0] as? MDLMesh else { return nil }
            return Mesh(mtkMesh: $0.1, mdlMesh: mdl, device: device)
        }
        
        // Create a uniform buffer that we'll dynamicall update each frame.
        frameUniformBuffers = [Int](0..<Render.bufferCount).map { _ in
            device.makeBuffer(length: MemoryLayout<VertexUniforms>.size, options: MTLResourceOptions())
        }
        
        return true
    }
    
    func update() {
        let p = frameUniformBuffers[render.activeBufferNumber].contents().assumingMemoryBound(to: VertexUniforms.self)
        var uni = p.pointee
        let mat = render.cameraMatrix * modelMatrix
        uni.projectionView = render.projectionMatrix * mat
        uni.normal = mat.inverse.transpose
        p.pointee = uni
    }
    
    func render(encoder renderEncoder: MTLRenderCommandEncoder) {
        renderEncoder.pushDebugGroup("Render Meshes")
        
        // Set context state.
        renderEncoder.setDepthStencilState(depthState)
        renderEncoder.setRenderPipelineState(pipelineState)
        
        // Set the our per frame uniforms.
        renderEncoder.setVertexBuffer(frameUniformBuffers[render.activeBufferNumber],
                                      offset: 0,
                                      at: Mesh.Buffer.frameUniform.index)
        
        // Render each of our meshes.
        meshes.forEach { mesh in mesh.render(encoder: renderEncoder) }
        
        renderEncoder.popDebugGroup()
    }
}

