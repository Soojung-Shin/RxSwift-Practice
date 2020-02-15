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

import UIKit
import Photos
import RxSwift

class PhotosViewController: UICollectionViewController {
  
  // MARK: public properties
  
  // MARK: private properties
  
  //선택된 사진을 방출하는 subject. 다른 클래스에서 next이벤트 등을 처리할 수 없도록 private으로 설정해주었다.
  private let selectedPhotosSubject = PublishSubject<UIImage>()
  
  //다른 클래스에서 selectedPhotosSubject가 방출하는 이벤트를 구독할 수 있도록 Observable을 공개 유형으로 설정한다. (읽기 전용 Observable을 이렇게 처리해준듯?)
  //이 프로퍼티를 구독하면 메인 컨트롤러가 간섭없이(delegate 등의 패턴을 사용하지 않고!) photo sequence를 관찰(observe)할 수 있다.
  var selectedPhotos: Observable<UIImage> {
    //🤔 asObservable을 사용하는 이유는?!?!
    return selectedPhotosSubject.asObservable()
  }
  
  private lazy var photos = PhotosViewController.loadPhotos()
  private lazy var imageManager = PHCachingImageManager()
  
  private lazy var thumbnailSize: CGSize = {
    let cellSize = (self.collectionViewLayout as! UICollectionViewFlowLayout).itemSize
    return CGSize(width: cellSize.width * UIScreen.main.scale,
                  height: cellSize.height * UIScreen.main.scale)
  }()
  
  static func loadPhotos() -> PHFetchResult<PHAsset> {
    let allPhotosOptions = PHFetchOptions()
    allPhotosOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
    return PHAsset.fetchAssets(with: allPhotosOptions)
  }
  
  // MARK: View Controller
  override func viewDidLoad() {
    super.viewDidLoad()
    
  }
  
  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    
    selectedPhotosSubject.onCompleted()
  }
  
  // MARK: UICollectionView
  
  override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
    return photos.count
  }
  
  override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
    
    let asset = photos.object(at: indexPath.item)
    let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Cell", for: indexPath) as! PhotoCell
    
    cell.representedAssetIdentifier = asset.localIdentifier
    imageManager.requestImage(for: asset, targetSize: thumbnailSize, contentMode: .aspectFill, options: nil, resultHandler: { image, _ in
      if cell.representedAssetIdentifier == asset.localIdentifier {
        cell.imageView.image = image
      }
    })
    
    return cell
  }
  
  override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    let asset = photos.object(at: indexPath.item)
    
    if let cell = collectionView.cellForItem(at: indexPath) as? PhotoCell {
      cell.flash()
    }
    
    //imageManager.requestImage(...)는 각 크기마다 해당 클로저를 한 번씩 호출한다.
    //하나의 이미지를 선택해도 여러번 호출됨.
    //아 그래서 내부에서 low level quality면 추가안하고, full version이면 추가하는구만.
    imageManager.requestImage(for: asset, targetSize: view.frame.size, contentMode: .aspectFill, options: nil, resultHandler: { [weak self] image, info in
      guard let image = image, let info = info else { return }
      
      //info 딕셔너리에서 PHImageResultIsDegradedKey키를 사용해서 해당 이미지가 썸네일인지 full version인지 확인한다.
      if let isThumbnail = info[PHImageResultIsDegradedKey as NSString] as? Bool, !isThumbnail {
        self?.selectedPhotosSubject.onNext(image)
      }
    })
  }
}
