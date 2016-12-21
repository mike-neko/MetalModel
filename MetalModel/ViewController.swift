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

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.

        // Metalの初期設定
        setup_metal()
        // 描画するものの初期設定
        load_assets()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: -

    fileprivate func setup_metal() {
        if let mtkView = Render.current.setupView(self.view as? MTKView) {
            /* MTKViewの初期設定 */
            mtkView.sampleCount = 1
            mtkView.depthStencilPixelFormat = .invalid
            
            mtkView.colorPixelFormat = .bgra8Unorm
            mtkView.clearColor = MTLClearColorMake(0.1, 0.1, 0.1, 1)
            
            // compute shader利用時はfalse
            mtkView.framebufferOnly = true
        } else {
            assert(false)
        }
    }
    
    fileprivate func load_assets() {
        /* モデルの設定 */
        let obj = MeshRender()
        // シェーダとobjファイルを指定
        guard obj.setup(vertexShaderName: "noLightVertex", fragmentShaderName: "noLightFragment",
            model: "Assets/realship/realship.obj") else { assert(false) }
        // 描画対象として追加
        Render.current.renderTargets.append(obj)
        
        // 位置を調整
        obj.modelMatrix = Matrix.translation(x: 0, y: 2, z: 2)
            * Quaternion.toMatrix(Quaternion.fromEuler(x: 270, y: 180, z: 0))

        // カメラ位置を調整
        Render.current.cameraMatrix = Matrix.translation(x: 0, y: -2, z: 6)
    }
}

