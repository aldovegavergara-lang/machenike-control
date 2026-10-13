import Foundation

/// Synthetic protocol data only. Never use these fixtures to write a real keyboard.
enum TestFixtures {
    static func keys()->[UInt8] {
        var b=[UInt8](repeating:0,count:1032)
        b.replaceSubrange(0..<8,with:[6,0x84,0xd4,0,0x84,0,0,0])
        func entry(_ i:Int,_ e:[UInt8]) {b.replaceSubrange((8+i*4)..<(12+i*4),with:e)}
        for (key,index) in OnboardKeys.physicalIndices where key<=255 {entry(index,[0,0,0,UInt8(key)])}
        // Reserve the 30 factory pairs with synthetic, non-personal records.
        for pair in 0..<30 {entry(84+pair,[2,0,0,UInt8(pair)]);entry(132+pair,[0,0,0,UInt8(4+pair)]);entry(180+pair,[0,0,0,UInt8(4+pair)])}
        entry(7,[2,0,0,0]);entry(132,[0,0,0,0x1e]);entry(180,[0,0,0,0x3a])
        entry(9,[2,0,0,17]);entry(149,[0,0,0,4]);entry(197,[0,0,0,0x50])
        return b
    }
    static func config()->[UInt8] {
        var b=[UInt8](repeating:0,count:1032)
        b.replaceSubrange(0..<8,with:[6,0x83,0xb6,0,0,0,0,0]);b[14]=0x5a;b[15]=0xa5;b[28]=0x55;b[29]=0x55
        b[21]=1;b[38]=0;b[39]=0x34;b[500]=0xaa
        return b
    }
    static func palette()->[UInt8] {
        var b=[UInt8](repeating:0,count:1032);b.replaceSubrange(0..<8,with:[6,8,0xb8,0,0x40,0,0,0]);b[29]=255;b[501]=0xaa;return b
    }
}
