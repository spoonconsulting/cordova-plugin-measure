import SceneKit

@objc(HWPMeasurePlugin) class MeasurePlugin : CDVPlugin {
    var allowMultiplePoints: Bool!;

    var measureListenerCallbackId: String!
    var finishListenerCallbackId: String!
    var captureAndFinishListenerCallbackId: String!
    
    var myViewController: ViewController!
    
    @objc func addARView(_ command: CDVInvokedUrlCommand) {
        DispatchQueue.global(qos: .utility).async {
            // Initialize the ViewController without using storyboard
            let myViewController = ViewController()
            self.myViewController = myViewController
            self.myViewController.delegate = self

            DispatchQueue.main.async {
                let options = command.arguments[0] as! NSMutableDictionary
                let multiplePointsEnabled = options.object(forKey: "allowMultiplePoints") as! Bool
                self.allowMultiplePoints = multiplePointsEnabled
                self.setcaptureAndFinishListenerCallbackId(command)

                guard let superview = self.webView.superview else { return }
                superview.insertSubview(self.myViewController.view, aboveSubview: self.webView)
            }
        }
    }
}
