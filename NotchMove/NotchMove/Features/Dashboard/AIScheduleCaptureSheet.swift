//
//  AIScheduleCaptureSheet.swift
//  NotchMove
//
//  Created by Codex on 4/30/26.
//

import Combine
import SwiftUI

struct AIScheduleCaptureSheet: View {
    let languageManager: LanguageManager
    let assistantService: AIScheduleAssistantService
    @Bindable var scheduleStore: DailyScheduleStore
    @Bindable var aiPreferences: AIProviderPreferences
    let onOpenSettings: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var captureService = AudioCaptureService()
    @State private var phase: Phase = .ready
    @State private var recordingStartedAt: Date?
    @State private var elapsedSeconds: Int = 0
    @State private var transcriptText = ""
    @State private var drafts: [AIScheduleDraft] = []
    @State private var selectedDraftIDs = Set<AIScheduleDraft.ID>()
    @State private var questions: [String] = []
    @State private var warnings: [String] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            Divider()

            content

            Divider()

            footer
        }
        .padding(20)
        .frame(width: 660, height: 560)
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            guard case .recording = phase, let recordingStartedAt else { return }
            elapsedSeconds = Int(Date().timeIntervalSince(recordingStartedAt))
        }
        .onDisappear {
            captureService.cancelRecording()
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "mic")
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text("ai.capture.title")
                    .font(.headline)

                Text(LocalizedStringKey(phase.statusKey))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .ready:
            readyContent
        case .recording:
            recordingContent
        case .transcribing, .parsing:
            processingContent
        case .review:
            reviewContent
        case .error(let message):
            errorContent(message)
        }
    }

    private var readyContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            providerStatusBlock

            Button {
                startRecording()
            } label: {
                Label("ai.capture.start_recording", systemImage: "record.circle")
            }
            .buttonStyle(.borderedProminent)
            .disabled(!aiPreferences.isEnabled)

            if !aiPreferences.isEnabled {
                Text("ai.capture.disabled")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private var recordingContent: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.14))
                    .frame(width: 96, height: 96)

                Image(systemName: "waveform")
                    .font(.system(size: 34, weight: .medium))
                    .foregroundStyle(.red)
            }

            Text(timeString(elapsedSeconds))
                .font(.system(size: 24, weight: .semibold).monospacedDigit())

            Button {
                stopRecordingAndProcess()
            } label: {
                Label("ai.capture.stop_recording", systemImage: "stop.fill")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private var processingContent: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.large)

            Text(LocalizedStringKey(phase.statusKey))
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private var reviewContent: some View {
        Form {
            Section {
                providerStatusBlock
            } header: {
                Text("ai.capture.flow_status")
            }

            Section {
                Text(transcriptText)
                    .font(.callout)
                    .textSelection(.enabled)
            } header: {
                Text("ai.capture.transcript")
            }

            if !questions.isEmpty {
                Section {
                    ForEach(questions, id: \.self) { question in
                        Text(question)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("ai.capture.questions")
                }
            }

            if !warnings.isEmpty {
                Section {
                    ForEach(warnings, id: \.self) { warning in
                        Text(displayWarning(warning))
                            .foregroundStyle(.red)
                    }
                } header: {
                    Text("ai.capture.warnings")
                }
            }

            Section {
                if drafts.isEmpty {
                    Text("ai.capture.no_drafts")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach($drafts) { $draft in
                        draftRow($draft)
                    }
                }
            } header: {
                Text("ai.capture.drafts")
            }
        }
        .formStyle(.grouped)
    }

    private func draftRow(_ draft: Binding<AIScheduleDraft>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: selectedBinding(for: draft.wrappedValue.id)) {
                TextField("dashboard.field.title", text: draft.title)
                    .textFieldStyle(.roundedBorder)
            }

            HStack(spacing: 12) {
                compactDatePicker(
                    "dashboard.field.start_time",
                    selection: draft.startDate
                )

                compactDatePicker(
                    "dashboard.field.end_time",
                    selection: Binding(
                        get: { draft.wrappedValue.endDate ?? draft.wrappedValue.startDate.addingTimeInterval(60 * 60) },
                        set: { draft.wrappedValue.endDate = $0 }
                    )
                )
            }

            HStack(spacing: 16) {
                Toggle("dashboard.field.reminder_enabled", isOn: draft.isReminderEnabled)

                Stepper(value: draft.reminderLeadMinutes, in: 0...120, step: 5) {
                    Text(String(
                        format: languageManager.localizedString("dashboard.field.lead_minutes_format"),
                        draft.wrappedValue.reminderLeadMinutes
                    ))
                }
            }

            TextField("dashboard.field.notes", text: Binding(
                get: { draft.wrappedValue.notes ?? "" },
                set: { draft.wrappedValue.notes = $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
            ), axis: .vertical)
            .lineLimit(2...3)

            if let warning = draft.wrappedValue.warning, !warning.isEmpty {
                Text(displayWarning(warning))
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(.vertical, 8)
    }

    private func compactDatePicker(_ titleKey: LocalizedStringKey, selection: Binding<Date>) -> some View {
        HStack(spacing: 6) {
            Text(titleKey)
                .font(.caption)
                .foregroundStyle(.secondary)

            DatePicker(
                titleKey,
                selection: selection,
                displayedComponents: [.date, .hourAndMinute]
            )
            .labelsHidden()
        }
    }

    private var providerStatusBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(providerStatusText, systemImage: "point.3.connected.trianglepath.dotted")
                .font(.caption)
                .foregroundStyle(.secondary)

            Label(privacyStatusText, systemImage: "lock")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func errorContent(_ message: String) -> some View {
        VStack(alignment: .center, spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.red)

            Text(message)
                .font(.callout)
                .multilineTextAlignment(.center)
                .textSelection(.enabled)

            HStack {
                Button {
                    reset()
                } label: {
                    Text("ai.capture.try_again")
                }

                Button {
                    onOpenSettings()
                    dismiss()
                } label: {
                    Text("ai.settings.open")
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private var footer: some View {
        HStack {
            Button("cancel") {
                dismiss()
            }

            Spacer()

            Button {
                onOpenSettings()
                dismiss()
            } label: {
                Text("ai.settings.open")
            }

            Button {
                addSelectedDrafts()
            } label: {
                Text("ai.capture.add_selected")
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canAddSelectedDrafts)
            .opacity(phase == .review ? 1 : 0)
        }
    }

    private var canAddSelectedDrafts: Bool {
        guard case .review = phase else { return false }
        let selected = selectedDrafts
        guard !selected.isEmpty else { return false }
        return selected.allSatisfy { !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private var selectedDrafts: [AIScheduleDraft] {
        drafts.filter { selectedDraftIDs.contains($0.id) }
    }

    private var providerStatusText: String {
        String(
            format: localizedString("ai.capture.providers_format"),
            aiPreferences.selectedTranscriptionProvider.displayName,
            aiPreferences.selectedParserProvider.displayName
        )
    }

    private var privacyStatusText: String {
        let transcriptionProvider = aiPreferences.selectedTranscriptionProvider.displayName
        let parserProvider = aiPreferences.selectedParserProvider.displayName

        if aiPreferences.selectedTranscriptionProvider == .localWhisperKit {
            return String(
                format: localizedString("ai.capture.privacy_local_transcription_format"),
                parserProvider
            )
        }

        if transcriptionProvider == parserProvider {
            return String(
                format: localizedString("ai.capture.privacy_same_provider_format"),
                transcriptionProvider
            )
        }

        return String(
            format: localizedString("ai.capture.privacy_split_provider_format"),
            transcriptionProvider,
            parserProvider
        )
    }

    private func selectedBinding(for id: AIScheduleDraft.ID) -> Binding<Bool> {
        Binding(
            get: { selectedDraftIDs.contains(id) },
            set: { isSelected in
                if isSelected {
                    selectedDraftIDs.insert(id)
                } else {
                    selectedDraftIDs.remove(id)
                }
            }
        )
    }

    private func startRecording() {
        Task {
            do {
                try AIProviderFactory.validateCaptureReadiness(preferences: aiPreferences)
                try await captureService.startRecording()
                recordingStartedAt = .now
                elapsedSeconds = 0
                phase = .recording
            } catch {
                phase = .error(errorMessage(for: error))
            }
        }
    }

    private func stopRecordingAndProcess() {
        Task {
            do {
                let recording = try captureService.stopRecording()
                let result = try await assistantService.createDrafts(
                    from: recording,
                    existingScheduleItems: scheduleStore.items,
                    localeIdentifier: languageManager.locale.identifier,
                    appLanguage: languageManager.selectedLanguage,
                    progress: { progress in
                        switch progress {
                        case .transcribing:
                            phase = .transcribing
                        case .parsing:
                            phase = .parsing
                        }
                    }
                )

                transcriptText = result.transcriptText
                drafts = result.drafts
                selectedDraftIDs = Set(result.drafts.map(\.id))
                questions = result.questions
                warnings = result.warnings
                phase = .review
            } catch {
                phase = .error(errorMessage(for: error))
            }
        }
    }

    private func addSelectedDrafts() {
        for draft in selectedDrafts {
            scheduleStore.add(draft.scheduleItem())
        }
        dismiss()
    }

    private func reset() {
        captureService.cancelRecording()
        transcriptText = ""
        drafts = []
        selectedDraftIDs = []
        questions = []
        warnings = []
        elapsedSeconds = 0
        recordingStartedAt = nil
        phase = .ready
    }

    private func timeString(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }

    private func displayWarning(_ warning: String) -> String {
        switch warning {
        case ScheduleParseResult.pastDateWarning:
            localizedString("ai.warning.past_date")
        case ScheduleParseResult.notTodayWarning:
            localizedString("ai.warning.not_today")
        default:
            warning
        }
    }

    private func errorMessage(for error: Error) -> String {
        guard let assistantError = error as? AIScheduleAssistantError else {
            return error.localizedDescription
        }

        switch assistantError {
        case .disabled:
            return localizedString("ai.error.disabled")
        case .missingAPIKey(let provider):
            return String(format: localizedString("ai.error.missing_api_key_format"), provider)
        case .missingCredential(let provider, let field):
            return String(format: localizedString("ai.error.missing_credential_format"), provider, field)
        case .microphoneDenied:
            return localizedString("ai.error.microphone_denied")
        case .recordingFailed(let message):
            return String(format: localizedString("ai.error.recording_failed_format"), message)
        case .emptyTranscript:
            return localizedString("ai.error.empty_transcript")
        case .networkUnavailable:
            return localizedString("ai.error.network_unavailable")
        case .providerAuthenticationFailed(let provider):
            return String(format: localizedString("ai.error.provider_auth_failed_format"), provider)
        case .providerRequestFailed(let provider, let statusCode, let message):
            return String(
                format: localizedString("ai.error.provider_request_failed_format"),
                provider,
                statusCode,
                message
            )
        case .providerResponseInvalid(let provider, let message):
            return String(format: localizedString("ai.error.provider_invalid_response_format"), provider, message)
        case .invalidParserJSON(let provider, let message):
            return String(format: localizedString("ai.error.invalid_parser_json_format"), provider, message)
        case .localModelUnavailable(let model):
            return String(format: localizedString("ai.error.local_model_unavailable_format"), model)
        case .keychainFailed(let message):
            return String(format: localizedString("ai.error.keychain_failed_format"), message)
        }
    }

    private func localizedString(_ key: String) -> String {
        languageManager.localizedString(key)
    }
}

private enum Phase: Equatable {
    case ready
    case recording
    case transcribing
    case parsing
    case review
    case error(String)

    var statusKey: String {
        switch self {
        case .ready:
            "ai.capture.ready"
        case .recording:
            "ai.capture.recording"
        case .transcribing:
            "ai.capture.transcribing"
        case .parsing:
            "ai.capture.parsing"
        case .review:
            "ai.capture.review"
        case .error:
            "ai.capture.error"
        }
    }
}
