//
//  Render.swift
//  MetalModel
//
//  Created by M.Ike on 2015/12/30.
//  Copyright © 2015年 M.Ike. All rights reserved.
//

import UIKit
import MetalKit

// MARK: - Protocol

// 描画用のオブジェクトのプロトコル
protocol RenderType {
    // 初期化
    init(render: Render)
    
    // update前のコールバック
    var preUpdate: ((Render) -> Void)? { get set }

    // 1フレーム毎に呼ばれる（描画前）
    func update()
    // 描画時に呼ばれる
    func render(encoder: MTLRenderCommandEncoder)
}

// GPGPU用のオブジェクトのプロトコル
protocol ComputeType {
    // 1フレーム毎に呼ばれる（描画前）
    func compute(commandBuffer: MTLCommandBuffer)
    // 描画後に呼ばれる
    func postRender()
}


// MARK: -
class Render: NSObject, MTKViewDelegate {
    // バッファの数
    static var bufferCount = 3
    // デフォルトのカメラ
    struct DefaultCamera {
        static var fovY = Float(75.0)
        static var nearZ = Float(0.1)
        static var farZ = Float(100)
    }
    
    // View
    private(set) weak var view: MTKView!
    
    private let semaphore: DispatchSemaphore
    private(set) var activeBufferNumber = 0
    
    // Renderer
    private(set) var device: MTLDevice
    private(set) var commandQueue: MTLCommandQueue
    private(set) var library: MTLLibrary
    
    // Uniforms
    var projectionMatrix = float4x4(matrix_identity_float4x4)
    var cameraMatrix = float4x4(matrix_identity_float4x4)
    var viewportNear = 0.0
    var viewportFar = 1.0
    
    // Time
    private var lastTime: Date
    private(set) var deltaTime = TimeInterval(0)
    
    // Objects
    var computeTargets = [ComputeType]()
    var renderTargets = [RenderType]()
    
    init?(view: MTKView) {
        /* Metalの初期設定 */
        self.view = view
        self.semaphore = DispatchSemaphore(value: Render.bufferCount)
        
        guard let device = MTLCreateSystemDefaultDevice() else { return nil }
        self.device = device
        self.commandQueue = device.makeCommandQueue()
        
        guard let new_lib = device.newDefaultLibrary() else { return nil }
        self.library = new_lib
        
        self.lastTime = Date()
        
        super.init()
        
        self.view.device = device
        self.view.delegate = self
    }
    
    // MARK: - MTKViewDelegate
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        projectionMatrix = Matrix.perspective(fovY: DefaultCamera.fovY,
                                              aspect: Float(fabs(view.bounds.size.width / view.bounds.height)),
                                              nearZ: DefaultCamera.nearZ,
                                              farZ: DefaultCamera.farZ)
    }
    
    func draw(in view: MTKView) {
        autoreleasepool {
            guard let drawable = view.currentDrawable else { return }
            guard let renderDescriptor = view.currentRenderPassDescriptor  else { return }
            
            deltaTime = Date().timeIntervalSince(lastTime)
            lastTime = Date()

            let _ = semaphore.wait(timeout: DispatchTime.distantFuture)
            let commandBuffer = commandQueue.makeCommandBuffer()
            
            compute(commandBuffer: commandBuffer)
            preUpdate()
            update()
            
            let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderDescriptor)
            renderEncoder.setViewport(MTLViewport(
                originX: 0, originY: 0,
                width: Double(view.drawableSize.width), height: Double(view.drawableSize.height),
                znear: viewportNear, zfar: viewportFar))
            
            render(encoder: renderEncoder)
            postRender()
            
            renderEncoder.endEncoding()
            
            let block_sema = semaphore
            commandBuffer.addCompletedHandler { _ in
                block_sema.signal()
            }
            
            commandBuffer.present(drawable)
            commandBuffer.commit()
            activeBufferNumber = (activeBufferNumber + 1) % Render.bufferCount
        }
    }
    
    // MARK: - private
    private func compute(commandBuffer: MTLCommandBuffer) {
        computeTargets.forEach { $0.compute(commandBuffer: commandBuffer) }
    }
    
    private func preUpdate() {
        renderTargets.forEach { $0.preUpdate?(self) }
    }
    
    private func update() {
        renderTargets.forEach { $0.update() }
    }
    
    private func render(encoder: MTLRenderCommandEncoder) {
        renderTargets.forEach { $0.render(encoder: encoder) }
    }
    
    private func postRender() {
        computeTargets.forEach { $0.postRender() }
    }
}
