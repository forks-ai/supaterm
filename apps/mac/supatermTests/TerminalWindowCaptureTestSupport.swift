import AppKit

func makeCaptureImage(width: Int, height: Int) -> CGImage? {
  guard
    let context = CGContext(
      data: nil,
      width: width,
      height: height,
      bitsPerComponent: 8,
      bytesPerRow: 0,
      space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )
  else { return nil }
  context.setFillColor(NSColor.red.cgColor)
  context.fill(CGRect(x: 0, y: 0, width: width, height: height))
  return context.makeImage()
}
