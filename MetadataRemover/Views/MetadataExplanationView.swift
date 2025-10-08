import SwiftUI

struct MetadataExplanationView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Почему важно удалять метаданные")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Метаданные — это скрытая информация, которая сохраняется вместе с фотографией: координаты GPS, дата и время съёмки, модель устройства и даже параметры камеры. Делитесь только тем, что хотите показать")

                VStack(alignment: .leading, spacing: 8) {
                    Label("GPS-координаты", systemImage: "location")
                    Label("Дата и время съёмки", systemImage: "calendar")
                    Label("Модель устройства", systemImage: "iphone")
                    Label("Параметры экспозиции", systemImage: "camera")
                }
                .font(.subheadline)

                Text("Приложение использует безопасное рендеринг-движок, чтобы пересохранить изображение без лишних полей. Мы ничего не отправляем на сервер — все операции выполняются на вашем устройстве.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Text("Совет: храните исходные фото с метаданными только у себя, а очищенные версии — для публикаций и пересылки. Так вы защитите своё местоположение и личную информацию.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
        .navigationTitle("О метаданных")
    }
}

#Preview {
    NavigationStack { MetadataExplanationView() }
}
