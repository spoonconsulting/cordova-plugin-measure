import UIKit
import SceneKit
import ARKit

@objc protocol ViewControllerDelegate: AnyObject {
    func allowMultiple() -> Bool
    func closeView()
    func onUpdateMeasure(nodeName: String)
    func sendResultAndCloseView(captureResult: [String: String])
}

final class ViewController: UIViewController {
    var sceneView: ARSCNView!
    var targetImageView: UIImageView!
    var loadingView: UIActivityIndicatorView!
    var messageLabel: UILabel!
    var meterButton: UIButton!
    var resetButton: UIButton!
    var captureButton: UIButton!
    var closeButton: UIButton!
    
    fileprivate lazy var session = ARSession()
    fileprivate lazy var sessionConfiguration = ARWorldTrackingConfiguration()
    fileprivate lazy var isMeasuring = false
    fileprivate lazy var vectorZero = SCNVector3()
    fileprivate lazy var startValue = SCNVector3()
    fileprivate lazy var endValue = SCNVector3()
    fileprivate lazy var lines: [Line] = []
    fileprivate var currentLine: Line?
    fileprivate lazy var unit: DistanceUnit = .centimeter
    
    func getMeasures() -> [String] {
            var list: [String] = [];

            for line in lines {
                list.append(line.getValue());
            }

            return list;
        }

    /// Delegate
    var delegate: ViewControllerDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
        setupConstraints()
        setupScene()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        UIApplication.shared.isIdleTimerDisabled = true
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        session.pause()
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        resetValues()
        isMeasuring = true
        targetImageView.image = UIImage(named: "targetGreen")

        if delegate?.allowMultiple() == false {
            for line in lines {
                line.removeFromParentNode()
            }
            lines.removeAll()
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        isMeasuring = false
        targetImageView.image = UIImage(named: "targetWhite")
        if let line = currentLine {
            lines.append(line)
            currentLine = nil
            
            delegate?.onUpdateMeasure(nodeName: line.getValue() ?? "")
        }
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
}

// MARK: - ARSCNViewDelegate

extension ViewController: ARSCNViewDelegate {
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        DispatchQueue.main.async { [weak self] in
            self?.detectObjects()
        }
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        messageLabel.text = "Error occurred"
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        messageLabel.text = "Interrupted"
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        messageLabel.text = "Interruption ended"
    }
}

// MARK: - Users Interactions

extension ViewController {
    @IBAction func meterButtonTapped(button: UIButton) {
        let alertVC = UIAlertController(title: "Settings", message: "Please select distance unit options", preferredStyle: .actionSheet)
        alertVC.addAction(UIAlertAction(title: DistanceUnit.centimeter.title, style: .default) { [weak self] _ in
            self?.unit = .centimeter
        })
        alertVC.addAction(UIAlertAction(title: DistanceUnit.inch.title, style: .default) { [weak self] _ in
            self?.unit = .inch
        })
        alertVC.addAction(UIAlertAction(title: DistanceUnit.meter.title, style: .default) { [weak self] _ in
            self?.unit = .meter
        })
        alertVC.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        present(alertVC, animated: true, completion: nil)
    }
    
    @IBAction func resetButtonTapped(button: UIButton) {
        for line in lines {
            line.removeFromParentNode()
        }
        lines.removeAll()
    }
    
    @IBAction func captureButtonTapped(button: UIButton) {
        let image = sceneView.snapshot();
        let documentsDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("cordova-measure")
        let uuid = NSUUID().uuidString
        let imageFile = documentsDirectory.appendingPathComponent(uuid + ".jpg")
        let result: [String: String]

        do {
            try FileManager.default.createDirectory(at: documentsDirectory, withIntermediateDirectories: true, attributes: nil)
            if let imageData = image.jpegData(compressionQuality: 0) {
                try imageData.write(to: imageFile)
                result = ["imagePath": imageFile.absoluteString, "message": "Snapshot saved successfully"]
            } else {
                result = ["message": "Failed to convert image to data"]
            }
        } catch {
            result = ["message": "Error saving snapshot"]
        }
        delegate?.sendResultAndCloseView(captureResult: result)
    }
    
    @IBAction func closeButtonTapped(button: UIButton) {
        delegate?.closeView();
    }
}

// MARK: - Private Methods

extension ViewController {
    private func setupViews() {
        // Initialize and configure the ARSCNView
        sceneView = ARSCNView()
        sceneView.delegate = self
        sceneView.session = session
        view.addSubview(sceneView)
        
        // Initialize and configure the target image view
        targetImageView = UIImageView()
        targetImageView.isHidden = true
        targetImageView.image = UIImage(named: "targetWhite")
        view.addSubview(targetImageView)
        
        // Initialize and configure the loading view (Activity Indicator)
        loadingView = UIActivityIndicatorView(style: .large)
        loadingView.startAnimating()
        view.addSubview(loadingView)
        
        // Initialize and configure the message label
        messageLabel = UILabel()
        messageLabel.text = "Detecting the world…"
        messageLabel.textAlignment = .center
        messageLabel.textColor = .white
        view.addSubview(messageLabel)
        
        // Initialize and configure the meter image view
        meterButton = UIButton(type: .system)
        meterButton.setTitle("Meter", for: .normal)
        meterButton.addTarget(self, action: #selector(meterButtonTapped(button:)), for: .touchUpInside)
        meterButton.isHidden = true
        view.addSubview(meterButton)
        
        // Initialize and configure the reset button
        resetButton = UIButton(type: .system)
        resetButton.setTitle("Reset", for: .normal)
        resetButton.addTarget(self, action: #selector(resetButtonTapped(button:)), for: .touchUpInside)
        view.addSubview(resetButton)
        
        // Initialize and configure the done button
        captureButton = UIButton(type: .system)
        var config = UIButton.Configuration.filled()
        config.title = "Capture"
        config.baseForegroundColor = .white
        config.baseBackgroundColor = .systemBlue
        config.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 20, bottom: 10, trailing: 20)
        captureButton.configuration = config // Apply the configuration
        captureButton.addTarget(self, action: #selector(captureButtonTapped(button:)), for: .touchUpInside)
        view.addSubview(captureButton)
        
        // Initialize and configure the close button
        closeButton = UIButton(type: .system)
        closeButton.setTitle("Close", for: .normal)
        closeButton.addTarget(self, action: #selector(closeButtonTapped(button:)), for: .touchUpInside)
        view.addSubview(closeButton)
    }
    
    private func setupConstraints() {
        sceneView.translatesAutoresizingMaskIntoConstraints = false
        targetImageView.translatesAutoresizingMaskIntoConstraints = false
        loadingView.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        meterButton.translatesAutoresizingMaskIntoConstraints = false
        resetButton.translatesAutoresizingMaskIntoConstraints = false
        captureButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // Constraints for the ARSCNView
            sceneView.topAnchor.constraint(equalTo: view.topAnchor),
            sceneView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            sceneView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            sceneView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            // Constraints for the target image view
            targetImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            targetImageView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            targetImageView.widthAnchor.constraint(equalToConstant: 50),
            targetImageView.heightAnchor.constraint(equalToConstant: 50),
            
            // Constraints for the loading view
            loadingView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            
            // Constraints for the meter image view
            meterButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            meterButton.topAnchor.constraint(equalTo: view.topAnchor, constant: 40),
            meterButton.widthAnchor.constraint(equalToConstant: 50),
            meterButton.heightAnchor.constraint(equalToConstant: 50),
            
            // Constraints for the message label
            messageLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            messageLabel.topAnchor.constraint(equalTo: meterButton.bottomAnchor, constant: 16),
            
            // Constraints for the reset button
            resetButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            resetButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -32),
            
            // Constraints for the done button
            captureButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            captureButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -32),
            
            // Constraints for the close button
            closeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            closeButton.topAnchor.constraint(equalTo: view.topAnchor, constant: 40),
            closeButton.widthAnchor.constraint(equalToConstant: 50),
            closeButton.heightAnchor.constraint(equalToConstant: 50),
        ])
    }
    
    fileprivate func setupScene() {
        session.run(sessionConfiguration, options: [.resetTracking, .removeExistingAnchors])
        resetValues()
    }
    
    fileprivate func resetValues() {
        isMeasuring = false
        startValue = SCNVector3()
        endValue =  SCNVector3()
    }
    
    fileprivate func detectObjects() {
        guard let worldPosition = sceneView.realWorldVector(screenPosition: view.center) else { return }
        targetImageView.isHidden = false
        meterButton.isHidden = false
        if lines.isEmpty {
            messageLabel.text = "Hold screen & move your phone…"
        }
        loadingView.stopAnimating()
        if isMeasuring {
            if startValue == vectorZero {
                startValue = worldPosition
                currentLine = Line(sceneView: sceneView, startVector: startValue, unit: unit)
            }
            endValue = worldPosition
            currentLine?.update(to: endValue)
            messageLabel.text = currentLine?.distance(to: endValue) ?? "Calculating…"
        }
    }
}
