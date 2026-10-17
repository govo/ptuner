import SwiftUI

/// 自定义调弦编辑页：名称、乐器类型、弦数与每根弦的音高/音分偏移。
struct CustomTuningEditorView: View {
    @EnvironmentObject private var library: InstrumentLibrary
    @Environment(\.dismiss) private var dismiss

    let isNew: Bool

    @State private var draft: TuningPreset
    @State private var errorMessage: String?
    @State private var savedMessage: String?

    init(preset: TuningPreset, isNew: Bool) {
        // 内置调弦永远不可被覆盖。即使调用方误把内置项传进来，
        // 这里也会先派生成一份全新的自定义副本，再进入编辑。
        let isBuiltIn = preset.isBuiltIn
        self.isNew = isNew || isBuiltIn
        _draft = State(initialValue: isBuiltIn ? preset.duplicated() : preset)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 14) {
                        basicSection
                        stringsSection
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 10)
                    .padding(.bottom, 30)
                    .frame(maxWidth: 620)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle(isNew ? "自定义调弦" : "编辑调弦")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                    .contentShape(Rectangle())
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        save()
                    }
                    .fontWeight(.semibold)
                    .contentShape(Rectangle())
                }
            }
            .alert(
                "提示",
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } }
                )
            ) {
                Button("好", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
            .alert(
                savedMessage ?? "已保存",
                isPresented: Binding(
                    get: { savedMessage != nil },
                    set: { if !$0 { savedMessage = nil } }
                )
            ) {
                Button("完成") {
                    dismiss()
                }
            } message: {
                Text("调弦「\(draft.name)」已经可用于调音。")
            }
        }
        .presentationDetents([.large])
    }

    // MARK: - 基本信息

    private var basicSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("基本信息")

            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 12) {
                        Text("名称")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(AppTheme.primaryText)
                            .frame(width: 64, alignment: .leading)

                        TextField("调弦名称", text: $draft.name)
                            .textFieldStyle(.plain)
                            .font(.system(size: 14))
                            .foregroundStyle(AppTheme.primaryText)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(AppTheme.controlBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                    }

                    fieldDescription("用于在乐器列表和调音页显示。")
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)

                Divider().overlay(AppTheme.divider).padding(.leading, 14)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 12) {
                        Text("乐器类型")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(AppTheme.primaryText)
                            .frame(width: 64, alignment: .leading)

                        Spacer()

                        Menu {
                            ForEach(InstrumentKind.allCases) { kind in
                                Button(kind.displayName) {
                                    draft.kind = kind
                                }
                            }
                        } label: {
                            menuLabel(draft.kind.displayName)
                        }
                    }

                    fieldDescription("决定在乐器列表中的分类和图标。")
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)

                Divider().overlay(AppTheme.divider).padding(.leading, 14)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 12) {
                        Text("弦数")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(AppTheme.primaryText)
                            .frame(width: 64, alignment: .leading)

                        Spacer()

                        StepperValue(value: draft.strings.count, range: 1...12) { value in
                            changeStringCount(to: value)
                        }
                    }

                    fieldDescription("这个调弦包含的弦数，最多 12 根。")
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(AppTheme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(AppTheme.cardBorder, lineWidth: 1)
            )
        }
    }

    // MARK: - 弦

    private var stringsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("弦的音高设置")

            VStack(alignment: .leading, spacing: 2) {
                fieldDescription("每行依次为音名、八度、音分偏移。")
                fieldDescription("音名与八度决定目标音高；音分偏移用于微调，正数偏高、负数偏低。")
                fieldDescription("右侧菜单可以上移、下移或删除这根弦。")
            }
            .padding(.horizontal, 4)

            VStack(spacing: 0) {
                ForEach(Array(draft.strings.enumerated()), id: \.element.id) { index, string in
                    stringRow(index: index, string: string)

                    if index < draft.strings.count - 1 {
                        Divider().overlay(AppTheme.divider).padding(.leading, 44)
                    }
                }

                Divider().overlay(AppTheme.divider)

                Button {
                    addString()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .bold))
                        Text("添加弦")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(draft.strings.count >= 12 ? AppTheme.tertiaryText : AppTheme.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(draft.strings.count >= 12)
            }
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(AppTheme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(AppTheme.cardBorder, lineWidth: 1)
            )
        }
    }

    private func stringRow(index: Int, string: TuningString) -> some View {
        HStack(spacing: 8) {
            Text("\(index + 1)")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.secondaryText)
                .frame(width: 22, height: 22)
                .background(AppTheme.controlBackground)
                .clipShape(Circle())

            Menu {
                ForEach(NoteSpelling.all) { spelling in
                    Button(spelling.name) {
                        updateString(at: index) { value in
                            value.pitchClass = spelling.pitchClass
                            value.accidental = spelling.accidental
                        }
                    }
                }
            } label: {
                menuLabel(string.noteName, minWidth: 34)
            }

            Menu {
                ForEach(Array(0...8), id: \.self) { octave in
                    Button("\(octave)") {
                        updateString(at: index) {
                            $0.octave = octave
                        }
                    }
                }
            } label: {
                menuLabel("\(string.octave)", minWidth: 22)
            }

            Spacer(minLength: 4)

            centsControl(index: index, string: string)

            Menu {
                Button {
                    moveString(from: index, to: index - 1)
                } label: {
                    Label("上移", systemImage: "arrow.up")
                }
                .disabled(index == 0)

                Button {
                    moveString(from: index, to: index + 1)
                } label: {
                    Label("下移", systemImage: "arrow.down")
                }
                .disabled(index >= draft.strings.count - 1)

                Divider()

                Button(role: .destructive) {
                    removeString(at: index)
                } label: {
                    Label("删除这根弦", systemImage: "trash")
                }
                .disabled(draft.strings.count <= 1)
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.secondaryText)
                    .frame(width: 24, height: 30)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .frame(width: 24)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private func centsControl(index: Int, string: TuningString) -> some View {
        HStack(spacing: 0) {
            Button {
                updateString(at: index) { $0.centsOffset = max(-100, $0.centsOffset - 1) }
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(AppTheme.secondaryText)
                    .frame(width: 24, height: 26)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Text(centsLabel(string.centsOffset))
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(abs(string.centsOffset) < 0.5 ? AppTheme.secondaryText : AppTheme.accent)
                .frame(width: 56)

            Button {
                updateString(at: index) { $0.centsOffset = min(100, $0.centsOffset + 1) }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(AppTheme.secondaryText)
                    .frame(width: 24, height: 26)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .background(AppTheme.controlBackground)
        .clipShape(Capsule())
    }

    private func fieldDescription(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11))
            .foregroundStyle(AppTheme.tertiaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(AppTheme.secondaryText)
            .padding(.leading, 4)
    }

    private func menuLabel(_ text: String, minWidth: CGFloat = 44) -> some View {
        HStack(spacing: 3) {
            Text(text)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppTheme.primaryText)
            Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(AppTheme.tertiaryText)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(minWidth: minWidth)
        .background(AppTheme.controlBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .contentShape(Rectangle())
    }

    private func centsLabel(_ value: Double) -> String {
        String(format: "%+.0f cents", value)
    }

    // MARK: - 编辑操作

    private func updateString(at index: Int, _ update: (inout TuningString) -> Void) {
        guard draft.strings.indices.contains(index) else { return }
        var string = draft.strings[index]
        update(&string)
        draft.strings[index] = string
    }

    private func changeStringCount(to count: Int) {
        let target = max(1, min(12, count))
        if target > draft.strings.count {
            while draft.strings.count < target {
                draft.strings.append(makeNextString())
            }
        } else if target < draft.strings.count {
            draft.strings.removeLast(draft.strings.count - target)
        }
    }

    private func addString() {
        guard draft.strings.count < 12 else { return }
        draft.strings.append(makeNextString())
    }

    private func removeString(at index: Int) {
        guard draft.strings.count > 1, draft.strings.indices.contains(index) else { return }
        draft.strings.remove(at: index)
    }

    private func moveString(from index: Int, to newIndex: Int) {
        guard draft.strings.indices.contains(index),
              draft.strings.indices.contains(newIndex),
              index != newIndex else { return }
        let item = draft.strings.remove(at: index)
        draft.strings.insert(item, at: newIndex)
    }

    private func makeNextString() -> TuningString {
        if let last = draft.strings.last {
            let midi = min(108, max(12, last.midiNote + 5))
            return TuningString(midiNote: midi,
                                accidental: last.accidental,
                                centsOffset: last.centsOffset)
        }
        return TuningString(parsing: "E2") ?? TuningString(midiNote: 40)
    }

    // MARK: - 保存

    private func save() {
        let trimmed = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "请输入调弦名称。"
            return
        }
        guard !draft.strings.isEmpty else {
            errorMessage = "请至少保留一根弦。"
            return
        }

        draft.name = trimmed
        library.saveCustom(draft)
        AppDiagnostics.breadcrumb(.tuner, "custom_tuning_saved")
        savedMessage = "已保存"
    }
}
