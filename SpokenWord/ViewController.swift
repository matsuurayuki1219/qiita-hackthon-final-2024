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

    let viewModel = ViewModel()
    private var cancellables: Set<AnyCancellable> = []

    private(set) var effectSoundPlayer = AVAudioPlayer()

    // MARK: Properties

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "ja_JP"))!

    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?

    private var recognitionTask: SFSpeechRecognitionTask?

    private let audioEngine = AVAudioEngine()

    @IBOutlet var textView: UITextView!
    
    @IBOutlet weak var imageView: UIImageView!

    @IBOutlet var recordButton: UIButton! {
        didSet {
            recordButton.layer.cornerRadius = 30
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
                self.recordButton.setTitle("侍をインバイトする", for: [])
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
        textView.text = "会議は始まった御座いる。"
    }

    // MARK: SFSpeechRecognizerDelegate

    public func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        if available {
            recordButton.isEnabled = true
            recordButton.setTitle("侍をインバイトする", for: [])
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
            recordButton.setTitle("Stopping", for: .disabled)
        } else {
            do {
                try startRecording()
                recordButton.setTitle("侍をインバイトする", for: [])
            } catch {
                recordButton.setTitle("Recording Not Available", for: [])
            }
        }
    }

    func playEffectSound() {
        guard let url = Bundle.main.url(forResource: "cleave_effect_sound", withExtension: "mp3") else { return }
        do {
            effectSoundPlayer = try .init(contentsOf: url)
            effectSoundPlayer.play()
        }
        catch {
            // no-ops
        }
    }
}


private extension ViewController {
    func addObserver() {
        viewModel.$result
            .sink(receiveValue: { result in
                if result?.cleave == true {
//                    self.textView.backgroundColor = .red
                    self.imageView.image = .init(named: "angry")
                    self.playEffectSound()
                    self.textView.text = result!.reason
                    print("Reason: \(result!.reason)")
                } else {
//                    self.textView.backgroundColor = .green
                    let openCloseEyes = Bool.random()
                    if openCloseEyes {
                        self.imageView.image = .init(named: "stare_openeyes")
                    }
                    else {
                        self.imageView.image = .init(named: "stare_closeeyes")
                    }

                    self.textView.text = "いいね。ひきつづける"
                }

            }).store(in: &cancellables)
    }
}
