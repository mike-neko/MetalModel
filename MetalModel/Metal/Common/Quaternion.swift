//
//  Quaternion.swift
//  MetalModel
//
//  Created by M.Ike on 2015/12/30.
//  Copyright © 2015年 M.Ike. All rights reserved.
//

import UIKit
import simd

/* クォータニオン周りのユーティリティ */
class Quaternion {
    // 正規化
    static func normalize(_ q: float4) -> float4 {
        let mag = sqrt(q.x * q.x + q.y * q.y + q.z * q.z + q.w * q.w)
        if mag > 0 {
            return float4(q.x / mag, q.y / mag, q.z / mag, q.w / mag)
        }
        return q
    }
    
    // クォータニオンを行列へ変換
    static func toMatrix(_ q: float4) -> float4x4 {
        let nor = q.x * q.x + q.y * q.y + q.z * q.z + q.w + q.w
        let s = (nor > 0) ? 2 / nor : 0
        
        let xx = q.x * q.x * s
        let yy = q.y * q.y * s
        let zz = q.z * q.z * s
        let xy = q.x * q.y * s
        let xz = q.x * q.z * s
        let yz = q.y * q.z * s
        let wx = q.w * q.x * s
        let wy = q.w * q.y * s
        let wz = q.w * q.z * s
        
        return float4x4([
            float4(
                1 - (yy + zz),
                xy + wz,
                xz - wy,
                0),
            float4(
                xy - wz,
                1 - (xx + zz),
                yz + wx,
                0),
            float4(
                xz + wy,
                yz - wx,
                1 - (xx + yy),
                0),
            float4(0, 0, 0, 1)])
    }
    
    // オイラー角（degree）をクォータニオンへ変換
    static func fromEuler(x: Float, y: Float, z: Float) -> float4 {
        let pi = Float(M_PI) / 180 / 2
        let pitch = x * pi
        let yaw = y * pi
        let roll = z * pi
        
        let sin_p = sin(pitch)
        let sin_y = sin(yaw)
        let sin_r = sin(roll)
        let cos_p = cos(pitch)
        let cos_y = cos(yaw)
        let cos_r = cos(roll)
        
        let q = float4(
            x: sin_r * cos_p * cos_y - cos_r * sin_p * sin_y,
            y: cos_r * sin_p * cos_y + sin_r * cos_p * sin_y,
            z: cos_r * cos_p * sin_y + sin_r * sin_p * cos_y,
            w: cos_r * cos_p * cos_y + sin_r * sin_p * sin_y)
        return Quaternion.normalize(q)
    }
}
