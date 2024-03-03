/*
 See the LICENSE.txt file for this sample’s licensing information.

 Abstract:
 The root view controller that provides a button to start and stop recording, and which displays the speech recognition results.
 */

import UIKit
import Speech
import Combine
import AVFAudio

public class ViewController: UIViewController, SFSpeechRecognizerDelegate {
    var recentCleaves: [Bool] = []
    var lastThreeCleaves: [Bool] { recentCleaves.suffix(3) }

    lazy var lineSpaceStyle: NSMutableParagraphStyle = {
        let lineSpaceStyle = NSMutableParagraphStyle()
        lineSpaceStyle.lineSpacing = 16
        return lineSpaceStyle
    }()

    // 装飾する内容
    var attributes: [NSAttributedString.Key : Any] = [:]

    let viewModel = ViewModel()
    private var cancellables: Set<AnyCancellable> = []

    private(set) var effectSoundPlayer = AVAudioPlayer()

    // MARK: Properties

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "ja_JP"))!

    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?

    private var recognitionTask: SFSpeechRecognitionTask?

    private let audioEngine = AVAudioEngine()

    @IBOutlet weak var textView: UILabel!

    @IBOutlet weak var imageView: UIImageView!

    @IBOutlet var recordButton: UIButton! {
        didSet {
            recordButton.layer.cornerRadius = 40
        }
    }

    // MARK: Custom LM Support

    @available(iOS 17, *)
    private var lmConfiguration: SFSpeechLanguageModel.Configuration {
        let outputDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let dynamicLanguageModel = outputDir.appendingPathComponent("LM")
        let dynamicVocabulary = outputDir.appendingPathComponent("Vocab")
        return SFSpeechLanguageModel.Configuration(languageModel: dynamicLanguageModel, vocabulary: dynamicVocabulary)
    }

    // MARK: UIViewController

    public override func viewDidLoad() {
        super.viewDidLoad()

        // Disable the record buttons until authorization has been granted.
        recordButton.isEnabled = false

        addObserver()

        attributes = [
            .font : UIFont.boldSystemFont(ofSize: 40.0),
            .foregroundColor : UIColor.black,
            .paragraphStyle: lineSpaceStyle
        ]

        textView.attributedText = NSAttributedString(string: "ぶった斬りサムライでござる。", attributes: attributes)
    }

    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Configure the SFSpeechRecognizer object already
        // stored in a local member variable.
        speechRecognizer.delegate = self

        // Make the authorization request.
        SFSpeechRecognizer.requestAuthorization { authStatus in

            // Divert to the app's main thread so that the UI
            // can be updated.
            OperationQueue.main.addOperation {
                switch authStatus {
                case .authorized:
                    if #available(iOS 17, *) {
                        Task.detached {
                            do {
                                let assetPath = Bundle.main.path(forResource: "CustomLMData", ofType: "bin", inDirectory: "customlm/en_US")!
                                let assetUrl = URL(fileURLWithPath: assetPath)
                                try await SFSpeechLanguageModel.prepareCustomLanguageModel(for: assetUrl,
                                                                                           clientIdentifier: "com.apple.SpokenWord",
                                                                                           configuration: self.lmConfiguration)
                            } catch {
                                NSLog("Failed to prepare custom LM: \(error.localizedDescription)")
                            }
                            await MainActor.run { self.recordButton.isEnabled = true }
                        }
                    } else {
                        self.recordButton.isEnabled = true
                    }
                case .denied:
                    self.recordButton.isEnabled = false
                    self.recordButton.setTitle("User denied access to speech recognition", for: .disabled)

                case .restricted:
                    self.recordButton.isEnabled = false
                    self.recordButton.setTitle("Speech recognition restricted on this device", for: .disabled)

                case .notDetermined:
                    self.recordButton.isEnabled = false
                    self.recordButton.setTitle("Speech recognition not yet authorized", for: .disabled)

                default:
                    self.recordButton.isEnabled = false
                }
            }
        }
    }

    private func startRecording() throws {
        // Cancel the previous task if it's running.
        if let recognitionTask = recognitionTask {
            recognitionTask.cancel()
            self.recognitionTask = nil
        }

        // Configure the audio session for the app.
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        let inputNode = audioEngine.inputNode

        // Create and configure the speech recognition request.
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { fatalError("Unable to created a SFSpeechAudioBufferRecognitionRequest object") }
        recognitionRequest.shouldReportPartialResults = false
        recognitionRequest.addsPunctuation = true
        // Keep speech recognition data on device
        if #available(iOS 13, *) {
            recognitionRequest.requiresOnDeviceRecognition = true
            if #available(iOS 17, *) {
                recognitionRequest.customizedLanguageModel = self.lmConfiguration
            }
        }

        // Create a recognition task for the speech recognition session.
        // Keep a reference to the task so that it can be canceled.
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { result, error in
            var isFinal = false

            if let result = result {
                // Update the text view with the results.
                self.viewModel.postSpeechText(text: result.bestTranscription.formattedString)
                isFinal = result.isFinal
            }

            if error != nil || isFinal {
                // Stop recognizing speech if there is a problem.
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)

                self.recognitionRequest = nil
                self.recognitionTask = nil

                self.recordButton.isEnabled = true
                self.recordButton.setTitle("サムライを召喚", for: [])
            }
        }

        // Configure the microphone input.
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
            self.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        // Let the user know to start talking.
        textView.attributedText = NSAttributedString(string: "会議は始まったでござる。", attributes: attributes)
    }

    // MARK: SFSpeechRecognizerDelegate

    public func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        if available {
            recordButton.isEnabled = true
            recordButton.setTitle("サムライを召喚", for: [])
        } else {
            recordButton.isEnabled = false
            recordButton.setTitle("Recognition Not Available", for: .disabled)
        }
    }

    // MARK: Interface Builder actions

    @IBAction func recordButtonTapped() {
        if audioEngine.isRunning {
            audioEngine.stop()
            recognitionRequest?.endAudio()
            recordButton.isEnabled = false
            recordButton.setTitle("サムライを召喚", for: [])
            textView.attributedText = NSAttributedString(string: "ぶった斬りサムライでござる。", attributes: attributes)
            cancellables.forEach { $0.cancel() }
        } else {
            do {
                try startRecording()
                recordButton.setTitle("会議中", for: [])
            } catch {
                recordButton.setTitle("Recording Not Available", for: [])
            }
        }
    }

    func playEffectSound(soundFile: SoundFile) {
        guard let url = Bundle.main.url(forResource: soundFile.rawValue, withExtension: "mp3") else { return }
        do {
            effectSoundPlayer = try .init(contentsOf: url)
            effectSoundPlayer.play()
        }
        catch {
            // no-ops
        }
    }
}

enum SoundFile: String {
    case cleaveEffectSound = "cleave_effect_sound"
    case cleaveEffectSoundMax = "cleave_effect_sound_max"

}

private extension ViewController {
    func addObserver() {
        viewModel.$result
            .sink(receiveValue: { result in
                guard let result = result else { return }
                self.recentCleaves.append(result.cleave)

                print("cleave: \(result.cleave)")
                print("Reason: \(result.reason)")

                let ngCount = self.lastThreeCleaves.filter({ $0 }).count
                print(ngCount)

                if ngCount >= 5 {
                    let text = "論点がズレているでござる！エンジニアが最高に幸せに感じる事を議論するでござる！！！！！！"
                    self.imageView.image = .init(named: "angry")
                    self.playEffectSound(soundFile: .cleaveEffectSoundMax)
                    self.textView.attributedText = NSAttributedString(string: text, attributes: self.attributes)
                } else if ngCount == 2 || ngCount == 3 || ngCount == 4 {
                    let text = result.reason
                    self.imageView.image = .init(named: "angry")
                    self.playEffectSound(soundFile: .cleaveEffectSound)
                    self.textView.attributedText = NSAttributedString(string: result.reason, attributes: self.attributes)
                } else if ngCount == 1 {
                    let text = "効率よく会議が進んでいる"
                    self.imageView.image = Bool.random() ? .init(named: "stare_openeyes") : .init(named: "stare_closeeyes")
                    self.textView.attributedText = NSAttributedString(string: text, attributes: self.attributes)
                } else if ngCount == 0 {
                    let text = "効率よく会議が進んでいる"
                    self.imageView.image = .init(named: "sleep")
                    self.textView.attributedText = NSAttributedString(string: text, attributes: self.attributes)
                }
//
//                if result.ngCase {
//                    self.imageView.image = .init(named: "angry")
//                    self.playEffectSound(soundFile: .cleaveEffectSound)
//                    self.textView.attributedText = NSAttributedString(string: result.reason, attributes: self.attributes)
//                } else {
//                    print("lastThreeCleaves: \(self.lastThreeCleaves)")
//                    self.imageView.image = Bool.random() ? .init(named: "stare_openeyes") : .init(named: "stare_closeeyes")
//                    self.textView.attributedText = NSAttributedString(string: "効率よく会議が進んでいる", attributes: self.attributes)
//                }
            }).store(in: &cancellables)
    }
}
