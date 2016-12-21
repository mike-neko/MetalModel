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
protocol RenderProtocol {
    // 1フレーム毎に呼ばれる（描画前）
    func update()
    // 描画時に呼ばれる
    func render(_ renderEncoder: MTLRenderCommandEncoder)
}

// GPGPU用のオブジェクトのプロトコル
protocol ComputeProtocol {
    // 1フレーム毎に呼ばれる（描画前）
    func compute(_ commandBuffer: MTLCommandBuffer)
    // 描画後に呼ばれる
    func postRender()
}


// MARK: -
class Render: NSObject, MTKViewDelegate {
    // バッファの数
    static let BufferCount = 3
    // デフォルトのカメラ
    let DefaultCameraFovY: Float = 75.0
    let DefaultCameraNearZ: Float = 0.1
    let DefaultCameraFarZ: Float = 100
    
    // Singleton
    static let current = Render()
    fileprivate(set) static var canUse = false

    // View
    weak var mtkView: MTKView! = nil
    fileprivate let semaphore = DispatchSemaphore(value: Render.BufferCount)
    fileprivate(set) var activeBufferNumber = 0
   
    // Renderer
    fileprivate(set) var device: MTLDevice!
    fileprivate(set) var commandQueue: MTLCommandQueue!
    fileprivate(set) var library: MTLLibrary!
    
    // Uniforms
    var projectionMatrix = float4x4(matrix_identity_float4x4)
    var cameraMatrix = float4x4(matrix_identity_float4x4)
    var viewportNear = 0.0
    var viewportFar = 1.0
    
    // Objects
    var computeTargets = [ComputeProtocol]()
    var renderTargets = [RenderProtocol]()
    
    override init() {
        Render.canUse = false

        /* Metalの初期設定 */
        guard let new_dev = MTLCreateSystemDefaultDevice() else { return }
        device = new_dev
        commandQueue = device.makeCommandQueue()
        guard let new_lib = device.newDefaultLibrary() else { return }
        library = new_lib
        
        Render.canUse = true
    }
    
    // MARK: - public
    func setupView(_ view: MTKView?) -> MTKView? {
        guard Render.canUse else { return nil }
        guard view != nil else { return nil }
        
        mtkView = view!
        mtkView.delegate = self
        mtkView.device = device
        
        return view
    }
    
    // MARK: - MTKViewDelegate
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        let aspect = Float(fabs(view.bounds.size.width / view.bounds.height))
        projectionMatrix = Matrix.perspective(
            fovY: DefaultCameraFovY, aspect: aspect, nearZ: DefaultCameraNearZ, farZ: DefaultCameraFarZ)
    }
    
    func draw(in view: MTKView) {
        autoreleasepool {
            semaphore.wait(timeout: DispatchTime.distantFuture)
            let commandBuffer = Render.current.commandQueue.makeCommandBuffer()
            
            compute(commandBuffer)
            update()

            guard let renderDescriptor = mtkView.currentRenderPassDescriptor  else { return }
            let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderDescriptor)
            renderEncoder.setViewport(MTLViewport(
                originX: 0, originY: 0,
                width: Double(mtkView.drawableSize.width), height: Double(mtkView.drawableSize.height),
                znear: viewportNear, zfar: viewportFar))
            
            render(renderEncoder)
            postRender()
            
            renderEncoder.endEncoding()

            let block_sema = semaphore
            commandBuffer.addCompletedHandler { buffer in
                block_sema.signal()
            }

            commandBuffer.present(mtkView.currentDrawable!)
            commandBuffer.commit()
            Render.current.activeBufferNumber = (Render.current.activeBufferNumber + 1) % Render.BufferCount
        }
    }

    // MARK: - private
    fileprivate func compute(_ commandBuffer: MTLCommandBuffer) {
        computeTargets.forEach { $0.compute(commandBuffer) }
    }
    
    fileprivate func update() {
        renderTargets.forEach { $0.update() }
    }
    
    fileprivate func render(_ renderEncoder: MTLRenderCommandEncoder) {
        renderTargets.forEach { $0.render(renderEncoder) }
    }

    fileprivate func postRender() {
        computeTargets.forEach { $0.postRender() }
    }
}
