import SwiftUI

struct SuggestionsView: View {
    let suggestions: [Suggestion]
    let currentSuggestion: String
    let isGenerating: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // Streaming suggestion — parse bullets as they arrive
                if isGenerating || !currentSuggestion.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        if isGenerating {
                            HStack(spacing: 6) {
                                ProgressView()
                                    .controlSize(.mini)
                                Text("Thinking...")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if !currentSuggestion.isEmpty {
                            let bullets = parseBullets(currentSuggestion)
                            ForEach(bullets) { bullet in
                                BulletRow(bullet: bullet, isStreaming: true)
                            }
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.accentTeal.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                // Past suggestions
                ForEach(suggestions) { suggestion in
                    SuggestionCard(suggestion: suggestion)
                }

                if suggestions.isEmpty && currentSuggestion.isEmpty && !isGenerating {
                    VStack(spacing: 8) {
                        Text("No suggestions yet")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                        Text("Suggestions appear when the other person speaks about topics in your knowledge base.")
                            .font(.system(size: 12))
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
                }
            }
            .padding(16)
        }
    }
}

// MARK: - Bullet Parsing

/// A parsed bullet from LLM output: headline + optional detail.
struct ParsedBullet: Identifiable {
    let id = UUID()
    let headline: String
    let detail: String?
}

/// Parses LLM output in `• Headline\n> Detail` format into structured bullets.
private func parseBullets(_ text: String) -> [ParsedBullet] {
    let lines = text.components(separatedBy: "\n")
    var bullets: [ParsedBullet] = []
    var currentHeadline: String?
    var currentDetail: String?

    for line in lines {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        if trimmed.hasPrefix("•") || trimmed.hasPrefix("-") || trimmed.hasPrefix("*") {
            // Save previous bullet
            if let headline = currentHeadline {
                bullets.append(ParsedBullet(headline: headline, detail: currentDetail))
            }
            // Start new bullet — strip the bullet character
            let stripped = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
            currentHeadline = stripped.isEmpty ? nil : stripped
            currentDetail = nil
        } else if trimmed.hasPrefix(">") {
            // Detail line
            let detail = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
            if !detail.isEmpty {
                if currentDetail != nil {
                    currentDetail! += " " + detail
                } else {
                    currentDetail = detail
                }
            }
        } else if !trimmed.isEmpty && trimmed != "—" {
            // Continuation of current context — append to detail if we have a headline
            if currentHeadline != nil {
                if currentDetail != nil {
                    currentDetail! += " " + trimmed
                } else {
                    currentDetail = trimmed
                }
            }
        }
    }

    // Don't forget last bullet
    if let headline = currentHeadline {
        bullets.append(ParsedBullet(headline: headline, detail: currentDetail))
    }

    return bullets
}

// MARK: - Bullet Row

private struct BulletRow: View {
    let bullet: ParsedBullet
    var isStreaming: Bool = false
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Headline — always visible
            HStack(alignment: .top, spacing: 6) {
                if bullet.detail != nil && !isStreaming {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .frame(width: 10, height: 16)
                }

                Text(bullet.headline)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if bullet.detail != nil && !isStreaming {
                    withAnimation(.easeOut(duration: 0.15)) {
                        isExpanded.toggle()
                    }
                }
            }

            // Detail — shown when expanded or streaming
            if let detail = bullet.detail, (isExpanded || isStreaming) {
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .padding(.leading, bullet.detail != nil && !isStreaming ? 16 : 0)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Suggestion Card (past suggestions)

private struct SuggestionCard: View {
    let suggestion: Suggestion

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            let bullets = parseBullets(suggestion.text)

            if bullets.isEmpty {
                // Fallback: show raw text if parsing yields nothing
                Text(suggestion.text)
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
            } else {
                ForEach(bullets) { bullet in
                    BulletRow(bullet: bullet)
                }
            }

            if !suggestion.kbHits.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 9))
                    Text(suggestion.kbHits.map(\.sourceFile).joined(separator: ", "))
                        .font(.system(size: 10))
                }
                .foregroundStyle(.tertiary)
                .padding(.top, 2)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
