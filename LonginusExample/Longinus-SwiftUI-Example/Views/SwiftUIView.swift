//
//  SwiftUIView.swift
//  Longinus-SwiftUI-Example
//
//  Created by Qitao Yang on 2020/8/30.
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
    

import SwiftUI
import struct Longinus.LGImage

struct SwiftUIView : View {

    @State private var index = 0
    @State var progressValue: Float = 0.0

    var body: some View {
        VStack {
            LGImage(source: URL(string: "https://github.com/KittenYang/Template-Image-Set/blob/master/Landscape/landscape-\(index).jpg?raw=true"), placeholder: {
                    Image(systemName: "arrow.2.circlepath")
				.font(.largeTitle) },options: [.imageWithFadeAnimation])
                .onProgress(progress: { (data, expectedSize, _) in
                    DispatchQueue.main.async {
                        self.progressValue = Float((data?.count ?? 0) / expectedSize)
                    }
                    print("Downloaded: \(data?.count ?? 0)/\(expectedSize)")
                })
                .onCompletion(completion: { (image, data, error, cacheType) in
                    if let error = error {
                        print(error)
                    }
                    if let _ = image {
                        print("成功显示！")
                        self.progressValue = 1.0
                    }
                })
                .resizable()
                .cancelOnDisappear(true)
                .aspectRatio(contentMode: .fill)
                .frame(width: 300, height: 300)
                .cornerRadius(20)
                .shadow(radius: 5)
            ProgressBar(value: self.$progressValue).frame(height: 14).padding()
            Button(action: {
                self.index = (self.index + 1) % 7
                self.progressValue = 0.0
            }) { Text("Next Image") }
            
        }.navigationBarTitle(Text("Basic Image"), displayMode: .inline)
    }
}

#if DEBUG
struct SwiftUIView_Previews : PreviewProvider {
    static var previews: some View {
        SwiftUIView()
    }
}
#endif
