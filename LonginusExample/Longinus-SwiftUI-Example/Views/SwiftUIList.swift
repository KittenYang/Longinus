//
//  SwiftUIList.swift
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
import class Longinus.LonginusManager

struct SwiftUIList : View {

    let index = 0 ..< 20

    var body: some View {
        List(index) { i in
            ListCell(index: i)
        }.navigationBarTitle(Text("SwiftUI List"), displayMode: .inline)
    }

    struct ListCell: View {

        @State var done = false

        var alreadyCached: Bool {
            LonginusManager.shared.imageCacher?.isCached(forKey: url.absoluteString).0 ?? false
        }

        let index: Int
        var url: URL {
            URL(string: "https://github.com/KittenYang/Template-Image-Set/blob/master/Landscape/landscape-\(index % 7).jpg?raw=true")!
        }

        var body: some View {
            HStack(alignment: .center) {
                Spacer()
                LGImage(source: url, placeholder: {
                    HStack {
                        Image(systemName: "arrow.2.circlepath.circle")
                            .resizable()
                            .frame(width: 50, height: 50)
                            .padding(10)
                        Text("Loading...").font(.title)
                    }
                    .foregroundColor(.gray)
                }, isLoaded: $done)
                    .onProgress(progress: { (data, expectedSize, _) in
                        print("Downloaded: \(data?.count ?? 0)/\(expectedSize)")
                    })
                    .onCompletion(completion: { (image, data, error, cacheType) in
                        if let error = error {
                            print("Error \(self.index): \(error)")
                        }
                        if let _ = image {
                            print("Success: \(self.index) - \(cacheType)")
                            print("成功显示！")
                        }
                    })
                    .resizable()
                    .cancelOnDisappear(true)
                    .aspectRatio(contentMode: .fit)
                    .cornerRadius(20)
                    .frame(width: 300, height: 300)
                    .opacity(done || alreadyCached ? 1.0 : 0.3)
                    .animation(.linear(duration: 0.4))
                Spacer()
            }.padding(.vertical, 12)
        }

    }
}

#if DEBUG
struct SwiftUIList_Previews : PreviewProvider {
    static var previews: some View {
        SwiftUIList()
    }
}
#endif
