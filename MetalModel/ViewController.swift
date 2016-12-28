//
//  ViewController.swift
//  MetalModel
//
//  Created by M.Ike on 2015/12/30.
//  Copyright © 2015年 M.ike. All rights reserved.
//

import UIKit
import MetalKit

class ViewController: UIViewController {
    @IBOutlet private weak var metalView: MTKView!
    
    private var render: Render!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        // Metalの初期設定
        guard setupMetal() else { assert(false) }
        // 描画するものの初期設定
        guard loadAssets() else { assert(false) }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: -
    
    private func setupMetal() -> Bool {
        render = Render(view: metalView)
        guard render != nil else { return false }
        
        /* MTKViewの初期設定 */
        metalView.sampleCount = 1
        metalView.depthStencilPixelFormat = .invalid
        
        metalView.colorPixelFormat = .bgra8Unorm
        metalView.clearColor = MTLClearColorMake(0.1, 0.1, 0.1, 1)
        
        // compute shader利用時はfalse
        metalView.framebufferOnly = true
        
        return true
    }
    
    private func loadAssets() -> Bool {
        /* モデルの設定 */
        let obj = MeshRender(render: render)
        // シェーダとobjファイルを指定
        guard obj.setup(vertexShaderName: "noLightVertex",
                        fragmentShaderName: "noLightFragment",
                        model: "Assets/realship/realship.obj")
            else { return false }
        obj.preUpdate = { render in
            let q = Quaternion.fromEuler(x: Float(render.deltaTime * 100))
            obj.modelMatrix = obj.modelMatrix * Quaternion.toMatrix(q)
        }
        
        // 描画対象として追加
        render.renderTargets.append(obj)
        
        // 位置を調整
        obj.modelMatrix = Matrix.translation(x: 0, y: 2.25, z: 2)
            * Quaternion.toMatrix(Quaternion.fromEuler(x: 0, y: 180, z: 0))
        // カメラ位置を調整
        render.cameraMatrix = Matrix.translation(x: 0, y: -2, z: 6)
        
        return true
    }
}

