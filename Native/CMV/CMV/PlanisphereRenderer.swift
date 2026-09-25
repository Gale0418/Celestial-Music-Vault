import SwiftUI
import CMVThemes

/// Astronomically grounded sky for Taiwan (25° N), projected from the
/// foreground date while subtle brightness changes use a separate clock.
enum PlanisphereRenderer {
    private struct SkyPoint: Sendable {
        let rightAscension: Double
        let declination: Double
    }

    private struct ChartStar: Sendable {
        let name: String?
        let point: SkyPoint
        let magnitude: Double
        let phase: Double
    }

    private struct Vector3: Sendable {
        let x: Double
        let y: Double
        let z: Double

        static func - (lhs: Vector3, rhs: Vector3) -> Vector3 {
            Vector3(x: lhs.x - rhs.x, y: lhs.y - rhs.y, z: lhs.z - rhs.z)
        }
    }

    private struct OrbitalElements: Sendable {
        let name: String
        let base: [Double]
        let rate: [Double]
    }

    private static let observerLatitude = 25.033 * Double.pi / 180
    private static let observerLongitudeDegrees = 121.5654
    private static let degreesToRadians = Double.pi / 180
    private static let radiansToDegrees = 180 / Double.pi
    private static let obliquity = 23.43928 * degreesToRadians
    private static let unitDot = Path(ellipseIn: CGRect(x: -1, y: -1, width: 2, height: 2))

    private static let zodiacNames = [
        "牡羊", "金牛", "雙子", "巨蟹", "獅子", "處女",
        "天秤", "天蠍", "射手", "摩羯", "水瓶", "雙魚"
    ]

    /// Derives a deterministic phase from fixed J2000 coordinates, avoiding mutable
    /// per-star state or random allocation while the canvas is redrawn.
    private static func star(
        _ name: String?,
        ra: Double,
        dec: Double,
        magnitude: Double
    ) -> ChartStar {
        let point = SkyPoint(rightAscension: ra, declination: dec)
        let phase = normalizedDegrees(ra * 7.31 + dec * 13.17) * degreesToRadians
        return ChartStar(name: name, point: point, magnitude: magnitude, phase: phase)
    }

    // Yale Bright Star Catalogue (5th Revised Edition) / starmap data, filtered to V <= 3.0.
    // Megrez (V 3.32) is retained as the Big Dipper bowl's connecting star.
    // The original anchors stay first because constellationEdges intentionally references them.
    private static let stars: [ChartStar] = [
        star("北極星", ra: 37.9500, dec: 89.2600, magnitude: 1.98),
        star("天狼星", ra: 101.2870, dec: -16.7160, magnitude: -1.46),
        star(nil, ra: 95.9870, dec: -52.6960, magnitude: -0.74),
        star("大角星", ra: 213.9150, dec: 19.1820, magnitude: -0.05),
        star("織女星", ra: 279.2350, dec: 38.7840, magnitude: 0.03),
        star(nil, ra: 79.1720, dec: 45.9980, magnitude: 0.08),
        star(nil, ra: 78.6340, dec: -8.2020, magnitude: 0.13),
        star(nil, ra: 114.8260, dec: 5.2250, magnitude: 0.34),
        star("參宿四", ra: 88.7930, dec: 7.4070, magnitude: 0.42),
        star("牛郎星", ra: 297.6960, dec: 8.8680, magnitude: 0.77),
        star(nil, ra: 68.9800, dec: 16.5090, magnitude: 0.85),
        star("角宿一", ra: 201.2980, dec: -11.1610, magnitude: 0.97),
        star("心宿二", ra: 247.3520, dec: -26.4320, magnitude: 1.06),
        star(nil, ra: 116.3290, dec: 28.0260, magnitude: 1.14),
        star(nil, ra: 344.4130, dec: -29.6220, magnitude: 1.16),
        star("天津四", ra: 310.3580, dec: 45.2800, magnitude: 1.25),
        star(nil, ra: 152.0930, dec: 11.9670, magnitude: 1.35),
        star(nil, ra: 81.2830, dec: 6.3500, magnitude: 1.64),
        star(nil, ra: 84.0530, dec: -1.2020, magnitude: 1.69),
        star(nil, ra: 83.0010, dec: -0.2990, magnitude: 1.74),
        star(nil, ra: 85.1900, dec: -1.9430, magnitude: 2.23),
        star(nil, ra: 165.9320, dec: 61.7510, magnitude: 1.79),
        star(nil, ra: 165.4600, dec: 56.3820, magnitude: 2.37),
        star(nil, ra: 178.4580, dec: 53.6950, magnitude: 2.44),
        star(nil, ra: 193.5070, dec: 55.9600, magnitude: 1.76),
        star(nil, ra: 200.9810, dec: 54.9250, magnitude: 2.23),
        star(nil, ra: 206.8850, dec: 49.3130, magnitude: 1.86),
        star("Megrez", ra: 183.8565, dec: 57.0326, magnitude: 3.32),
        star("Rigil Kentaurus", ra: 219.8996, dec: -60.8353, magnitude: -0.01),
        star("Achernar", ra: 24.4288, dec: -57.2367, magnitude: 0.46),
        star("Hadar", ra: 210.9558, dec: -60.3731, magnitude: 0.61),
        star("Mimosa", ra: 191.9300, dec: -59.6886, magnitude: 1.25),
        star("Acrux", ra: 186.6496, dec: -63.0992, magnitude: 1.33),
        star("Toliman", ra: 219.9004, dec: -60.8356, magnitude: 1.33),
        star("Adhara", ra: 104.6562, dec: -28.9722, magnitude: 1.50),
        star(nil, ra: 187.7913, dec: -57.1133, magnitude: 1.63),
        star(nil, ra: 263.4021, dec: -37.1039, magnitude: 1.63),
        star(nil, ra: 81.5729, dec: 28.6075, magnitude: 1.65),
        star(nil, ra: 138.3000, dec: -69.7172, magnitude: 1.68),
        star(nil, ra: 186.6521, dec: -63.0994, magnitude: 1.73),
        star(nil, ra: 332.0583, dec: -46.9611, magnitude: 1.74),
        star(nil, ra: 122.3833, dec: -47.3367, magnitude: 1.78),
        star(nil, ra: 51.0808, dec: 49.8611, magnitude: 1.79),
        star(nil, ra: 107.0979, dec: -26.3933, magnitude: 1.84),
        star(nil, ra: 276.0429, dec: -34.3847, magnitude: 1.85),
        star(nil, ra: 125.6283, dec: -59.5097, magnitude: 1.86),
        star(nil, ra: 264.3300, dec: -42.9978, magnitude: 1.87),
        star(nil, ra: 89.8821, dec: 44.9475, magnitude: 1.90),
        star(nil, ra: 252.1662, dec: -69.0278, magnitude: 1.92),
        star(nil, ra: 99.4279, dec: 16.3992, magnitude: 1.93),
        star(nil, ra: 306.4121, dec: -56.7350, magnitude: 1.94),
        star(nil, ra: 131.1758, dec: -54.7083, magnitude: 1.96),
        star(nil, ra: 95.6750, dec: -17.9558, magnitude: 1.98),
        star(nil, ra: 113.6500, dec: 31.8883, magnitude: 1.98),
        star(nil, ra: 141.8967, dec: -8.6586, magnitude: 1.98),
        star(nil, ra: 31.7933, dec: 23.4625, magnitude: 2.00),
        star(nil, ra: 239.8758, dec: 25.9203, magnitude: 2.00),
        star(nil, ra: 283.8163, dec: -26.2967, magnitude: 2.02),
        star(nil, ra: 10.8975, dec: -17.9867, magnitude: 2.04),
        star(nil, ra: 2.0971, dec: 29.0906, magnitude: 2.06),
        star(nil, ra: 17.4329, dec: 35.6206, magnitude: 2.06),
        star(nil, ra: 86.9392, dec: -9.6697, magnitude: 2.06),
        star(nil, ra: 211.6708, dec: -36.3700, magnitude: 2.06),
        star(nil, ra: 222.6763, dec: 74.1556, magnitude: 2.08),
        star(nil, ra: 263.7337, dec: 12.5600, magnitude: 2.08),
        star(nil, ra: 340.6671, dec: -46.8847, magnitude: 2.10),
        star(nil, ra: 47.0421, dec: 40.9556, magnitude: 2.12),
        star(nil, ra: 177.2650, dec: 14.5719, magnitude: 2.14),
        star(nil, ra: 190.3792, dec: -48.9597, magnitude: 2.17),
        star(nil, ra: 305.5571, dec: 40.2567, magnitude: 2.20),
        star(nil, ra: 136.9992, dec: -43.4325, magnitude: 2.21),
        star(nil, ra: 10.1271, dec: 56.5372, magnitude: 2.23),
        star(nil, ra: 233.6721, dec: 26.7147, magnitude: 2.23),
        star(nil, ra: 269.1517, dec: 51.4889, magnitude: 2.23),
        star(nil, ra: 120.8963, dec: -40.0033, magnitude: 2.25),
        star(nil, ra: 139.2725, dec: -59.2753, magnitude: 2.25),
        star(nil, ra: 30.9750, dec: 42.3297, magnitude: 2.26),
        star(nil, ra: 2.2946, dec: 59.1497, magnitude: 2.27),
        star(nil, ra: 252.5408, dec: -34.2933, magnitude: 2.29),
        star(nil, ra: 204.9717, dec: -53.4664, magnitude: 2.30),
        star(nil, ra: 220.4825, dec: -47.3883, magnitude: 2.30),
        star(nil, ra: 218.8767, dec: -42.1578, magnitude: 2.31),
        star(nil, ra: 240.0833, dec: -22.6217, magnitude: 2.32),
        star(nil, ra: 6.5708, dec: -42.3061, magnitude: 2.39),
        star(nil, ra: 326.0467, dec: 9.8750, magnitude: 2.39),
        star(nil, ra: 265.6221, dec: -39.0300, magnitude: 2.41),
        star(nil, ra: 345.9438, dec: 28.0828, magnitude: 2.42),
        star(nil, ra: 257.5946, dec: -15.7247, magnitude: 2.43),
        star(nil, ra: 319.6450, dec: 62.5856, magnitude: 2.44),
        star(nil, ra: 111.0238, dec: -29.3031, magnitude: 2.45),
        star(nil, ra: 311.5529, dec: 33.9703, magnitude: 2.46),
        star(nil, ra: 14.1771, dec: 60.7167, magnitude: 2.47),
        star(nil, ra: 346.1904, dec: 15.2053, magnitude: 2.49),
        star(nil, ra: 140.5283, dec: -55.0108, magnitude: 2.50),
        star(nil, ra: 45.5700, dec: 4.0897, magnitude: 2.53),
        star(nil, ra: 208.8850, dec: -47.2883, magnitude: 2.55),
        star(nil, ra: 168.5271, dec: 20.5236, magnitude: 2.56),
        star(nil, ra: 249.2896, dec: -10.5672, magnitude: 2.56),
        star(nil, ra: 83.1825, dec: -17.8222, magnitude: 2.58),
        star(nil, ra: 183.9517, dec: -17.5419, magnitude: 2.59),
        star(nil, ra: 182.0896, dec: -50.7225, magnitude: 2.60),
        star(nil, ra: 285.6529, dec: -29.8803, magnitude: 2.60),
        star(nil, ra: 154.9929, dec: 19.8417, magnitude: 2.61),
        star(nil, ra: 229.2517, dec: -9.3831, magnitude: 2.61),
        star(nil, ra: 89.9304, dec: 37.2125, magnitude: 2.62),
        star(nil, ra: 241.3592, dec: -19.8056, magnitude: 2.62),
        star(nil, ra: 28.6600, dec: 20.8081, magnitude: 2.64),
        star(nil, ra: 84.9121, dec: -34.0742, magnitude: 2.64),
        star(nil, ra: 188.5967, dec: -23.3967, magnitude: 2.65),
        star(nil, ra: 236.0671, dec: 6.4256, magnitude: 2.65),
        star(nil, ra: 21.4542, dec: 60.2353, magnitude: 2.68),
        star(nil, ra: 208.6713, dec: 18.3978, magnitude: 2.68),
        star(nil, ra: 224.6329, dec: -43.1339, magnitude: 2.68),
        star(nil, ra: 74.2483, dec: 33.1661, magnitude: 2.69),
        star(nil, ra: 161.6925, dec: -49.4200, magnitude: 2.69),
        star(nil, ra: 189.2958, dec: -69.1356, magnitude: 2.69),
        star(nil, ra: 262.6908, dec: -37.2958, magnitude: 2.69),
        star(nil, ra: 109.2858, dec: -37.0975, magnitude: 2.70),
        star(nil, ra: 221.2467, dec: 27.0742, magnitude: 2.70),
        star(nil, ra: 275.2487, dec: -29.8281, magnitude: 2.70),
        star(nil, ra: 296.5650, dec: 10.6133, magnitude: 2.72),
        star(nil, ra: 243.5863, dec: -3.6944, magnitude: 2.74),
        star(nil, ra: 245.9979, dec: 61.5142, magnitude: 2.74),
        star(nil, ra: 200.1492, dec: -36.7122, magnitude: 2.75),
        star(nil, ra: 222.7196, dec: -16.0417, magnitude: 2.75),
        star(nil, ra: 160.7392, dec: -64.3944, magnitude: 2.76),
        star(nil, ra: 83.8583, dec: -5.9100, magnitude: 2.77),
        star(nil, ra: 247.5550, dec: 21.4897, magnitude: 2.77),
        star(nil, ra: 265.8683, dec: 4.5672, magnitude: 2.77),
        star(nil, ra: 233.7854, dec: -41.1669, magnitude: 2.78),
        star(nil, ra: 76.9625, dec: -5.0864, magnitude: 2.79),
        star(nil, ra: 262.6083, dec: 52.3014, magnitude: 2.79),
        star(nil, ra: 6.4379, dec: -77.2542, magnitude: 2.80),
        star(nil, ra: 183.7862, dec: -58.7489, magnitude: 2.80),
        star(nil, ra: 121.8858, dec: -24.3042, magnitude: 2.81),
        star(nil, ra: 250.3217, dec: 31.6031, magnitude: 2.81),
        star(nil, ra: 276.9925, dec: -25.4217, magnitude: 2.81),
        star(nil, ra: 248.9708, dec: -28.2161, magnitude: 2.82),
        star(nil, ra: 3.3092, dec: 15.1836, magnitude: 2.83),
        star(nil, ra: 195.5442, dec: 10.9592, magnitude: 2.83),
        star(nil, ra: 82.0613, dec: -20.7594, magnitude: 2.84),
        star(nil, ra: 58.5329, dec: 31.8836, magnitude: 2.85),
        star(nil, ra: 238.7854, dec: -63.4306, magnitude: 2.85),
        star(nil, ra: 261.3250, dec: -55.5300, magnitude: 2.85),
        star(nil, ra: 29.6925, dec: -61.5697, magnitude: 2.86),
        star(nil, ra: 334.6254, dec: -60.2597, magnitude: 2.86),
        star(nil, ra: 56.8713, dec: 24.1050, magnitude: 2.87),
        star(nil, ra: 296.2437, dec: 45.1308, magnitude: 2.87),
        star(nil, ra: 326.7600, dec: -16.1272, magnitude: 2.87),
        star(nil, ra: 95.7400, dec: 22.5136, magnitude: 2.88),
        star(nil, ra: 113.6500, dec: 31.8886, magnitude: 2.88),
        star(nil, ra: 59.4633, dec: 40.0103, magnitude: 2.89),
        star(nil, ra: 229.7275, dec: -68.6794, magnitude: 2.89),
        star(nil, ra: 239.7129, dec: -26.1142, magnitude: 2.89),
        star(nil, ra: 245.2971, dec: -25.5928, magnitude: 2.89),
        star(nil, ra: 287.4408, dec: -21.0236, magnitude: 2.89),
        star(nil, ra: 111.7875, dec: 8.2894, magnitude: 2.90),
        star(nil, ra: 194.0071, dec: 38.3183, magnitude: 2.90),
        star(nil, ra: 322.8896, dec: -5.5711, magnitude: 2.91),
        star(nil, ra: 46.1992, dec: 53.5064, magnitude: 2.93),
        star(nil, ra: 102.4842, dec: -50.6147, magnitude: 2.93),
        star(nil, ra: 340.7504, dec: 30.2214, magnitude: 2.94),
        star(nil, ra: 59.5075, dec: -13.5086, magnitude: 2.95),
        star(nil, ra: 187.4663, dec: -16.5156, magnitude: 2.95),
        star(nil, ra: 262.9604, dec: -49.8761, magnitude: 2.95),
        star(nil, ra: 331.4458, dec: -0.3197, magnitude: 2.96),
        star(nil, ra: 100.9829, dec: 25.1311, magnitude: 2.98),
        star(nil, ra: 146.4629, dec: 23.7742, magnitude: 2.98),
        star(nil, ra: 75.4921, dec: 43.8233, magnitude: 2.99),
        star(nil, ra: 271.4521, dec: -30.4242, magnitude: 2.99),
        star(nil, ra: 286.3525, dec: 13.8633, magnitude: 2.99),
        star(nil, ra: 32.3858, dec: 34.9872, magnitude: 3.00),
        star(nil, ra: 84.4113, dec: 21.1425, magnitude: 3.00),
        star(nil, ra: 182.5312, dec: -22.6197, magnitude: 3.00),
        star(nil, ra: 199.7304, dec: -23.1717, magnitude: 3.00),
    ]

    private static let constellationEdges: [(Int, Int)] = [
        // Orion: Betelgeuse, Bellatrix, belt, Saiph, Rigel.
        (8, 17), (8, 19), (17, 19), (19, 18), (18, 20), (20, 6), (6, 17),
        // Big Dipper.
        (21, 22), (22, 23), (23, 27), (27, 21), (27, 24), (24, 25), (25, 26),
        // Summer Triangle.
        (4, 15), (15, 9), (9, 4)
    ]

    // JPL Table 1 values: [a, e, I, L, longitude of perihelion, node].
    private static let earth = OrbitalElements(
        name: "地球",
        base: [1.00000261, 0.01671123, -0.00001531, 100.46457166, 102.93768193, 0],
        rate: [0.00000562, -0.00004392, -0.01294668, 35999.37244981, 0.32327364, 0]
    )

    private static let planets = [
        OrbitalElements(name: "水星", base: [0.38709927, 0.20563593, 7.00497902, 252.25032350, 77.45779628, 48.33076593], rate: [0.00000037, 0.00001906, -0.00594749, 149472.67411175, 0.16047689, -0.12534081]),
        OrbitalElements(name: "金星", base: [0.72333566, 0.00677672, 3.39467605, 181.97909950, 131.60246718, 76.67984255], rate: [0.00000390, -0.00004107, -0.00078890, 58517.81538729, 0.00268329, -0.27769418]),
        OrbitalElements(name: "火星", base: [1.52371034, 0.09339410, 1.84969142, -4.55343205, -23.94362959, 49.55953891], rate: [0.00001847, 0.00007882, -0.00813131, 19140.30268499, 0.44441088, -0.29257343]),
        OrbitalElements(name: "木星", base: [5.20288700, 0.04838624, 1.30439695, 34.39644051, 14.72847983, 100.47390909], rate: [-0.00011607, -0.00013253, -0.00183714, 3034.74612775, 0.21252668, 0.20469106]),
        OrbitalElements(name: "土星", base: [9.53667594, 0.05386179, 2.48599187, 49.95424423, 92.59887831, 113.66242448], rate: [-0.00125060, -0.00050991, 0.00193609, 1222.49362201, -0.41897216, -0.28867794]),
        OrbitalElements(name: "天王星", base: [19.18916464, 0.04725744, 0.77263783, 313.23810451, 170.95427630, 74.01692503], rate: [-0.00196176, -0.00004397, -0.00242939, 428.48202785, 0.40805281, 0.04240589]),
        OrbitalElements(name: "海王星", base: [30.06992276, 0.00859048, 1.77004347, -55.12002969, 44.96476227, 131.78422574], rate: [0.00026291, 0.00005105, 0.00035372, 218.45945325, -0.32241464, -0.00508664])
    ]

    static func draw(
        in context: inout GraphicsContext,
        size: CGSize,
        date: Date,
        twinkleTime: TimeInterval,
        showsLabels: Bool,
        theme: CMVTheme
    ) {
        guard size.width > 0, size.height > 0 else { return }
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let radius = min(size.width, size.height) * 0.49
        guard radius > 40 else { return }

        let julianDate = date.timeIntervalSince1970 / 86_400 + 2_440_587.5
        let siderealDegrees = normalizedDegrees(
            greenwichSiderealDegrees(julianDate: julianDate) + observerLongitudeDegrees
        )

        drawZodiac(in: &context, center: center, radius: radius,
                   siderealDegrees: siderealDegrees, showsLabels: showsLabels, theme: theme)
        drawConstellations(in: &context, center: center, radius: radius,
                           siderealDegrees: siderealDegrees,
                           time: twinkleTime, showsLabels: showsLabels, theme: theme)
        drawPlanets(in: &context, center: center, radius: radius,
                    siderealDegrees: siderealDegrees, julianDate: julianDate,
                    showsLabels: showsLabels, theme: theme)
    }

    private static func drawZodiac(
        in context: inout GraphicsContext,
        center: CGPoint,
        radius: CGFloat,
        siderealDegrees: Double,
        showsLabels: Bool,
        theme: CMVTheme
    ) {
        var ecliptic = Path()
        var isDrawingSegment = false
        for step in 0...72 {
            let longitude = Double(step) / 72 * Double.pi * 2
            let point = eclipticToEquatorial(Vector3(x: cos(longitude), y: sin(longitude), z: 0))
            guard let chartPoint = projectVisible(
                point, center: center, radius: radius, siderealDegrees: siderealDegrees
            ) else {
                isDrawingSegment = false
                continue
            }
            if isDrawingSegment { ecliptic.addLine(to: chartPoint) }
            else { ecliptic.move(to: chartPoint); isDrawingSegment = true }
        }
        context.stroke(ecliptic, with: .color(theme.starSecondary.opacity(0.16)),
                       style: StrokeStyle(lineWidth: 0.7, lineCap: .round, dash: [2, 5]))

        for (index, name) in zodiacNames.enumerated() {
            let longitude = (Double(index) * 30 + 15) * degreesToRadians
            let skyPoint = eclipticToEquatorial(Vector3(x: cos(longitude), y: sin(longitude), z: 0))
            guard let point = projectVisible(
                skyPoint, center: center, radius: radius, siderealDegrees: siderealDegrees
            ) else { continue }
            drawDot(in: &context, point: point, radius: 1.1,
                    color: theme.starSecondary.opacity(0.42))
            if showsLabels {
                drawLabel(name, in: &context, at: CGPoint(x: point.x, y: point.y + 6),
                          color: theme.starSecondary.opacity(0.38), anchor: .top)
            }
        }
    }

    private static func drawConstellations(
        in context: inout GraphicsContext,
        center: CGPoint,
        radius: CGFloat,
        siderealDegrees: Double,
        time: TimeInterval,
        showsLabels: Bool,
        theme: CMVTheme
    ) {
        let points: [CGPoint?] = stars.map {
            projectVisible($0.point, center: center, radius: radius,
                           siderealDegrees: siderealDegrees)
        }
        var linePath = Path()
        for (start, end) in constellationEdges {
            guard let startPoint = points[start], let endPoint = points[end] else { continue }
            linePath.move(to: startPoint)
            linePath.addLine(to: endPoint)
        }
        context.stroke(linePath, with: .color(theme.starSecondary.opacity(0.20)),
                       style: StrokeStyle(lineWidth: 0.75, lineCap: .round, lineJoin: .round))

        for (index, star) in stars.enumerated() {
            guard let point = points[index] else { continue }
            let radius = CGFloat(max(0.75, min(2.2, 1.9 - star.magnitude * 0.28)))
            // A low-amplitude, per-star phase-shifted pulse keeps the shimmer subtle.
            let pulse = 1.0 + 0.045 * sin(time * 0.42 + star.phase)
            let opacity = min(0.86, max(0.62, 0.78 * pulse))
            drawDot(in: &context, point: point, radius: radius,
                    color: theme.starPrimary.opacity(opacity))
            if showsLabels, let name = star.name {
                drawLabel(name, in: &context, at: CGPoint(x: point.x + 5, y: point.y),
                          color: theme.starPrimary.opacity(0.32), anchor: .leading)
            }
        }
    }

    private static func drawPlanets(
        in context: inout GraphicsContext,
        center: CGPoint,
        radius: CGFloat,
        siderealDegrees: Double,
        julianDate: Double,
        showsLabels: Bool,
        theme: CMVTheme
    ) {
        let centuries = (julianDate - 2_451_545.0) / 36_525
        let earthPosition = heliocentricVector(earth, centuries: centuries)
        for (index, planet) in planets.enumerated() {
            let geocentric = heliocentricVector(planet, centuries: centuries) - earthPosition
            let skyPoint = eclipticToEquatorial(geocentric)
            guard let point = projectVisible(
                skyPoint, center: center, radius: radius, siderealDegrees: siderealDegrees
            ) else { continue }
            drawPlanetIcon(in: &context, at: point, index: index)
            if showsLabels {
                drawLabel(planet.name, in: &context, at: CGPoint(x: point.x + 10, y: point.y),
                          color: theme.metal.opacity(0.70), anchor: .leading)
            }
        }
    }

    /// Tiny, scale-independent planet portraits. The order matches `planets` above.
    private static func drawPlanetIcon(
        in context: inout GraphicsContext,
        at point: CGPoint,
        index: Int
    ) {
        let radius: CGFloat = index == 3 || index == 4 ? 5.2 : 4.4
        let disk = Path(ellipseIn: CGRect(
            x: point.x - radius, y: point.y - radius,
            width: radius * 2, height: radius * 2
        ))

        if index == 4 { // Saturn's ring sits behind its disk.
            var ringContext = context
            ringContext.translateBy(x: point.x, y: point.y)
            ringContext.rotate(by: .degrees(-25))
            ringContext.stroke(
                Path(ellipseIn: CGRect(x: -8.3, y: -3.1, width: 16.6, height: 6.2)),
                with: .color(Color(red: 0.94, green: 0.81, blue: 0.59).opacity(0.85)),
                lineWidth: 1.3
            )
        }

        let colors: [Color]
        switch index {
        case 0: colors = [Color(red: 0.87, green: 0.84, blue: 0.78), Color(red: 0.42, green: 0.44, blue: 0.47)]
        case 1: colors = [Color(red: 1.00, green: 0.91, blue: 0.69), Color(red: 0.74, green: 0.57, blue: 0.35)]
        case 2: colors = [Color(red: 1.00, green: 0.64, blue: 0.42), Color(red: 0.59, green: 0.25, blue: 0.20)]
        case 3: colors = [Color(red: 0.98, green: 0.87, blue: 0.68), Color(red: 0.64, green: 0.41, blue: 0.34)]
        case 4: colors = [Color(red: 0.98, green: 0.89, blue: 0.65), Color(red: 0.67, green: 0.53, blue: 0.37)]
        case 5: colors = [Color(red: 0.80, green: 0.97, blue: 0.97), Color(red: 0.35, green: 0.69, blue: 0.76)]
        default: colors = [Color(red: 0.54, green: 0.76, blue: 1.00), Color(red: 0.17, green: 0.31, blue: 0.76)]
        }
        context.fill(
            disk,
            with: .linearGradient(
                Gradient(colors: colors),
                startPoint: CGPoint(x: point.x - radius, y: point.y - radius),
                endPoint: CGPoint(x: point.x + radius, y: point.y + radius)
            )
        )

        var detailContext = context
        detailContext.clip(to: disk)
        switch index {
        case 0: // Mercury: one crater is enough at this size.
            detailContext.fill(
                Path(ellipseIn: CGRect(x: point.x + 0.6, y: point.y - 1.4, width: 1.8, height: 1.8)),
                with: .color(.black.opacity(0.23))
            )
        case 1, 3, 4, 5: // Cloud, gas, and ice bands.
            let bandColor = index == 5 ? Color.white.opacity(0.29)
                : Color(red: 0.56, green: 0.35, blue: 0.27).opacity(index == 1 ? 0.19 : 0.42)
            let bandHeight: CGFloat = index == 3 ? 1.4 : 1.1
            for offset in [-2.0, 1.5] as [CGFloat] {
                detailContext.fill(
                    Path(CGRect(x: point.x - radius, y: point.y + offset,
                                width: radius * 2, height: bandHeight)),
                    with: .color(bandColor)
                )
            }
        case 2: // Mars: a dark surface patch.
            detailContext.fill(
                Path(ellipseIn: CGRect(x: point.x - 1.5, y: point.y + 0.2, width: 2.9, height: 1.5)),
                with: .color(Color(red: 0.41, green: 0.18, blue: 0.16).opacity(0.48))
            )
        default: break
        }
    }

    private static func projectVisible(
        _ point: SkyPoint,
        center: CGPoint,
        radius: CGFloat,
        siderealDegrees: Double
    ) -> CGPoint? {
        let hourAngle = normalizedSignedDegrees(siderealDegrees - point.rightAscension)
            * degreesToRadians
        let declination = point.declination * degreesToRadians
        let east = -cos(declination) * sin(hourAngle)
        let north = sin(declination) * cos(observerLatitude)
            - cos(declination) * cos(hourAngle) * sin(observerLatitude)
        let up = sin(declination) * sin(observerLatitude)
            + cos(declination) * cos(hourAngle) * cos(observerLatitude)
        guard up > 0 else { return nil }
        let altitude = asin(min(1, max(-1, up)))
        let azimuth = atan2(east, north)
        let radialDistance = radius * CGFloat((Double.pi / 2 - altitude) / (Double.pi / 2))
        return CGPoint(
            x: center.x + sin(azimuth) * radialDistance,
            y: center.y - cos(azimuth) * radialDistance
        )
    }

    private static func heliocentricVector(
        _ elements: OrbitalElements,
        centuries: Double
    ) -> Vector3 {
        let values = zip(elements.base, elements.rate).map { $0 + $1 * centuries }
        let a = values[0], e = values[1]
        let inclination = values[2] * degreesToRadians
        let node = values[5] * degreesToRadians
        let argument = (values[4] - values[5]) * degreesToRadians
        let meanAnomaly = normalizedSignedDegrees(values[3] - values[4]) * degreesToRadians
        var eccentricAnomaly = meanAnomaly
        for _ in 0..<10 {
            let delta = (eccentricAnomaly - e * sin(eccentricAnomaly) - meanAnomaly)
                / (1 - e * cos(eccentricAnomaly))
            eccentricAnomaly -= delta
            if abs(delta) < 1e-12 { break }
        }
        let xPrime = a * (cos(eccentricAnomaly) - e)
        let yPrime = a * sqrt(max(0, 1 - e * e)) * sin(eccentricAnomaly)
        let cosArgument = cos(argument), sinArgument = sin(argument)
        let cosNode = cos(node), sinNode = sin(node)
        let cosInclination = cos(inclination), sinInclination = sin(inclination)
        return Vector3(
            x: (cosArgument * cosNode - sinArgument * sinNode * cosInclination) * xPrime
                + (-sinArgument * cosNode - cosArgument * sinNode * cosInclination) * yPrime,
            y: (cosArgument * sinNode + sinArgument * cosNode * cosInclination) * xPrime
                + (-sinArgument * sinNode + cosArgument * cosNode * cosInclination) * yPrime,
            z: sinArgument * sinInclination * xPrime + cosArgument * sinInclination * yPrime
        )
    }

    private static func eclipticToEquatorial(_ vector: Vector3) -> SkyPoint {
        let y = cos(obliquity) * vector.y - sin(obliquity) * vector.z
        let z = sin(obliquity) * vector.y + cos(obliquity) * vector.z
        return SkyPoint(
            rightAscension: normalizedDegrees(atan2(y, vector.x) * radiansToDegrees),
            declination: atan2(z, hypot(vector.x, y)) * radiansToDegrees
        )
    }

    private static func greenwichSiderealDegrees(julianDate: Double) -> Double {
        let days = julianDate - 2_451_545.0
        let centuries = days / 36_525
        return 280.46061837 + 360.98564736629 * days
            + 0.000387933 * centuries * centuries
            - centuries * centuries * centuries / 38_710_000
    }

    private static func normalizedDegrees(_ value: Double) -> Double {
        let result = value.truncatingRemainder(dividingBy: 360)
        return result < 0 ? result + 360 : result
    }

    private static func normalizedSignedDegrees(_ value: Double) -> Double {
        let normalized = normalizedDegrees(value)
        return normalized > 180 ? normalized - 360 : normalized
    }

    private static func drawDot(
        in context: inout GraphicsContext,
        point: CGPoint,
        radius: CGFloat,
        color: Color
    ) {
        var dotContext = context
        dotContext.translateBy(x: point.x, y: point.y)
        dotContext.scaleBy(x: radius, y: radius)
        dotContext.fill(unitDot, with: .color(color))
    }

    private static func drawLabel(
        _ label: String,
        in context: inout GraphicsContext,
        at point: CGPoint,
        color: Color,
        anchor: UnitPoint
    ) {
        context.draw(
            Text(label).font(.caption2.weight(.medium)).foregroundStyle(color),
            at: point,
            anchor: anchor
        )
    }

}

// Planet positions use NASA/JPL's offline 1800–2050 approximation:
// https://ssd.jpl.nasa.gov/planets/approx_pos.html
