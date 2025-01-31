/// Copyright (c) 2019 Razeware LLC
///
/// Permission is hereby granted, free of charge, to any person obtaining a copy
/// of this software and associated documentation files (the "Software"), to deal
/// in the Software without restriction, including without limitation the rights
/// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
/// copies of the Software, and to permit persons to whom the Software is
/// furnished to do so, subject to the following conditions:
///
/// The above copyright notice and this permission notice shall be included in
/// all copies or substantial portions of the Software.
///
/// Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
/// distribute, sublicense, create a derivative work, and/or sell copies of the
/// Software in any work that is designed, intended, or marketed for pedagogical or
/// instructional purposes related to programming, coding, application development,
/// or information technology.  Permission for such use, copying, modification,
/// merger, publication, distribution, sublicensing, creation of derivative works,
/// or sale is expressly withheld.
///
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
/// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
/// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
/// THE SOFTWARE.

import Foundation
import UIKit
import Photos
import RxSwift

//PHPhotoLibrary 자체에 reactive extension을 추가할 수도 있지만, 간단하게 하기 위해서 PhotoWriter 클래스를 만들어서 사진 저장 기능을 만들었다.
class PhotoWriter {
  enum Errors: Error {
    case couldNotSavePhoto
  }
  
  //파라미터로 받은 사진을 저장하고, 결과를 success/error 이벤트로 방출하는 Single 만들어 리턴하는 메소드.
  static func save(_ image: UIImage) -> Single<String> {
    return Single<String>.create { single in
      var savedAssetId: String?
      
      PHPhotoLibrary.shared().performChanges({
        //image를 photo asset에 저장한다.
        let request = PHAssetChangeRequest.creationRequestForAsset(from: image)
        //savedAssetId에 저장된 photo asset의 identifier를 할당해준다.
        savedAssetId = request.placeholderForCreatedAsset?.localIdentifier
      }, completionHandler: { success, error in
        
        DispatchQueue.main.async {
          if success, let id = savedAssetId {
            single(.success(id))
          } else {
            single(.error(error ?? Errors.couldNotSavePhoto))
          }
        }
      })
      
      return Disposables.create()
    }
  }
}
