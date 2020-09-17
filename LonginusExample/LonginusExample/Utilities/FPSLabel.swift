//
//  FPSLabel.swift
//  Longinus_Example
//
//  Created by Qitao Yang on 2020/7/15.
//
//  Copyright (c) 2020 KittenYang <kittenyang@icloud.com>
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
    

import UIKit

/**
Show Screen FPS...

The maximum fps in OSX/iOS Simulator is 60.00.
The maximum fps on iPhone is 59.97.
The maxmium fps on iPad is 60.0.
*/
class FPSLabel: UILabel {
    
    private var _link: SafeDisplayLinkProxy?
    private var _count: Int = 0
    private var _lastTime: TimeInterval?
    private var _font: UIFont?
    private var _subFont: UIFont?
    
    private let fpsDefaultSize: CGSize = CGSize(width: 55, height: 20)
    
    override init(frame: CGRect) {
        var correctedFrame = frame
        if (frame.size.width == 0 && frame.size.height == 0) {
            correctedFrame.size = fpsDefaultSize;
        }
        super.init(frame: correctedFrame)
        
        self.layer.cornerRadius = 5
        self.clipsToBounds = true
        self.textAlignment = .center
        self.isUserInteractionEnabled = false
        self.backgroundColor = UIColor(white: 0.0, alpha: 0.7)
            
        _font = UIFont(name: "Menlo", size: 14.0)
        if _font != nil {
            _subFont = UIFont(name: "Menlo", size: 4.0)
        } else {
            _font = UIFont(name: "Courier", size: 14.0)
            _subFont = UIFont(name: "Courier", size: 4.0)
        }
        
        _link = SafeDisplayLinkProxy(handle: { [weak self] (displaylink) in
            if let link = displaylink {
                self?.tick(link: link)
            }
        })
    }
    
    deinit {
        _link?.invalidate()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        return fpsDefaultSize
    }
    private func tick(link: CADisplayLink) {
        if (_lastTime == 0) {
            _lastTime = link.timestamp
            return
        }
        
        _count += 1
        let delta = link.timestamp - (_lastTime ?? 0)
        if (delta < 1) {
            return
        }
        _lastTime = link.timestamp;
        let fps: CGFloat = CGFloat(_count) / CGFloat(delta);
        _count = 0
        
        let progress: CGFloat = fps / 60.0
        let color = UIColor(hue: 0.27 * (progress - 0.2), saturation: 1.0, brightness: 0.9, alpha: 1.0)
        
        let text = NSMutableAttributedString(string: "\(Int(round(fps))) FPS")
        text.addAttribute(NSAttributedString.Key.foregroundColor, value: color, range: NSRange(location: 0, length: text.length - 3))
        text.addAttribute(NSAttributedString.Key.foregroundColor, value: UIColor.white, range: NSRange(location: text.length - 3, length: 3))

        if let font = _font, let subFont = _subFont {
            text.addAttribute(NSAttributedString.Key.font, value: font, range: NSRange(location: 0, length: text.length))
            text.addAttribute(NSAttributedString.Key.font, value: subFont, range: NSRange(location: text.length - 4, length: 1))
        }
        self.attributedText = text;
    }
}
