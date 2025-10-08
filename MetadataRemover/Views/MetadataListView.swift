import SwiftUI

struct MetadataListView: View {
    let metadata: [MetadataEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(metadata) { entry in
                HStack(alignment: .top) {
                    Text(entry.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .frame(width: 120, alignment: .leading)
                    Text(entry.value)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                    Spacer()
                }
                Divider()
            }
        }
    }
}

#Preview {
    MetadataListView(metadata: MetadataEntry.previewData)
        .padding()
}
