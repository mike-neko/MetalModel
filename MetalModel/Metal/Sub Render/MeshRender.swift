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
        case Position = 0
        case Normal = 1
        case Texcoord = 2
        func index() -> Int { return self.rawValue }
    }

    private var pipelineState: MTLRenderPipelineState! = nil
    private var depthState: MTLDepthStencilState! = nil
   
    // Meshes
    private var meshes: [Mesh]! = nil
    private var frameUniformBuffers: [MTLBuffer] = []
    
    // Uniforms
    var modelMatrix = float4x4(matrix_identity_float4x4)
    
    func setup(vertexShaderName vertexShaderName: String, fragmentShaderName: String, model: String) -> Bool {
        let device = Render.current.device
        let mtkView = Render.current.mtkView
        let library = Render.current.library

        guard let vertex_pg = library.newFunctionWithName(vertexShaderName) else { return false }
        guard let fragment_pg = library.newFunctionWithName(fragmentShaderName) else { return false }
        
        let vertexDescriptor = MTLVertexDescriptor()
        // Positions.
        let attr_pos = vertexDescriptor.attributes[VertexAttribute.Position.index()]
        attr_pos.format = .Float3
        attr_pos.offset = 0
        attr_pos.bufferIndex = Mesh.Buffer.MeshVertex.index()
        
        // Normals.
        let attr_nor = vertexDescriptor.attributes[VertexAttribute.Normal.index()]
        attr_nor.format = .Float3
        attr_nor.offset = 12
        attr_nor.bufferIndex = Mesh.Buffer.MeshVertex.index()
        
        // Texture coordinates.
        let attr_tex = vertexDescriptor.attributes[VertexAttribute.Texcoord.index()]
        attr_tex.format = .Half2
        attr_tex.offset = 24
        attr_tex.bufferIndex = Mesh.Buffer.MeshVertex.index()
        
        // Single interleaved buffer.
        let layout = vertexDescriptor.layouts[Mesh.Buffer.MeshVertex.index()]
        layout.stride = 28;
        layout.stepRate = 1;
        layout.stepFunction = .PerVertex
        
        // Create a reusable pipeline state
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.label = "MeshPipeLine"
        pipelineDescriptor.sampleCount = mtkView.sampleCount
        pipelineDescriptor.vertexFunction = vertex_pg
        pipelineDescriptor.fragmentFunction = fragment_pg
        pipelineDescriptor.vertexDescriptor = vertexDescriptor
        pipelineDescriptor.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat
        pipelineDescriptor.depthAttachmentPixelFormat = mtkView.depthStencilPixelFormat
        pipelineDescriptor.stencilAttachmentPixelFormat = mtkView.depthStencilPixelFormat
        do {
            pipelineState = try device.newRenderPipelineStateWithDescriptor(pipelineDescriptor)
        } catch {
            return false
        }
        
        let depthDescriptor = MTLDepthStencilDescriptor()
        depthDescriptor.depthCompareFunction = .Less
        depthDescriptor.depthWriteEnabled = true
        depthState = device.newDepthStencilStateWithDescriptor(depthDescriptor)
        
        let modelDescriptor = MTKModelIOVertexDescriptorFromMetal(vertexDescriptor)
        let mdl_attrs = modelDescriptor.attributes
        (mdl_attrs[VertexAttribute.Position.index()] as! MDLVertexAttribute).name = MDLVertexAttributePosition
        (mdl_attrs[VertexAttribute.Normal.index()] as! MDLVertexAttribute).name = MDLVertexAttributeNormal
        (mdl_attrs[VertexAttribute.Texcoord.index()] as! MDLVertexAttribute).name = MDLVertexAttributeTextureCoordinate
        
        let bufAllocator = MTKMeshBufferAllocator(device: device)
        guard let url = NSBundle.mainBundle().URLForResource(model, withExtension: nil) else { return false }
        let asset = MDLAsset(URL: url, vertexDescriptor: modelDescriptor, bufferAllocator: bufAllocator)
        
        // Create MetalKit meshes.
        let mtkMeshes: NSArray?
        var mdlMeshes: NSArray?
        do {
            mtkMeshes = try MTKMesh.newMeshesFromAsset(asset, device: device, sourceMeshes: &mdlMeshes)
        } catch {
            return false
        }
        
        // Create our array of App-Specific mesh wrapper objects.
        meshes = mtkMeshes?.enumerate().map {
            Mesh(mtkMesh: $0.1 as! MTKMesh, mdlMesh: mdlMeshes![$0.0] as! MDLMesh, device: device)
        }
        
        // Create a uniform buffer that we'll dynamicall update each frame.
        for var i = 0; i < Render.BufferCount; i++ {
            frameUniformBuffers += [device.newBufferWithLength(sizeof(VertexUniforms), options: .CPUCacheModeDefaultCache)]
        }
        return true
    }
    
    func update() {
        let ren = Render.current
        
        let p = UnsafeMutablePointer<VertexUniforms>(frameUniformBuffers[ren.activeBufferNumber].contents())
        var uni = p.memory
        let mat = ren.cameraMatrix * modelMatrix
        uni.projectionView = ren.projectionMatrix * mat
        uni.normal = mat.inverse.transpose
        p.memory = uni
    }

    func render(renderEncoder: MTLRenderCommandEncoder) {
        renderEncoder.pushDebugGroup("Render Meshes")

        // Set context state.
        renderEncoder.setDepthStencilState(depthState)
        renderEncoder.setRenderPipelineState(pipelineState)
        
        // Set the our per frame uniforms.
        renderEncoder.setVertexBuffer(
            frameUniformBuffers[Render.current.activeBufferNumber],
            offset: 0,
            atIndex: Mesh.Buffer.FrameUniform.index())
        
        // Render each of our meshes.
        _ = meshes.map { mesh in mesh.render(renderEncoder) }

        renderEncoder.popDebugGroup()
    }
}

