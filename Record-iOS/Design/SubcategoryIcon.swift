import Foundation
#if canImport(UIKit)
import UIKit

enum SubcategoryIconCatalog {
    private static let subcategoryIcons: [String: String] = [
        "周边游": "travelling_icon",
        "旅游": "travelling_icon",
        "三餐": "food_icon",
        "早餐": "breakfast_icon",
        "中餐": "food_icon",
        "晚餐": "food_icon",
        "买菜": "vegatables_icon",
        "水果": "fruit_icon",
        "零食": "snacks_icon",
        "加餐": "food_icon",
        "下午茶": "afternoon_tea_icon",
        "烟酒饮品": "drink_icon",
        "粮油调料": "food_icon",
        "公交地铁": "subway_icon",
        "打车": "taxi_icon",
        "火车飞机": "plane_train_icon",
        "共享单车": "traffic_icon",
        "私家车": "traffic_icon",
        "日用品": "goods_icon",
        "衣帽鞋包": "clothes_icon",
        "护肤美妆": "shopping_icon",
        "饰品": "shopping_icon",
        "数码": "digital_icon",
        "电器": "electrical_icon",
        "家装": "shopping_icon",
        "话费": "phone_bill_icon",
        "房租": "home_bill_icon",
        "水费": "water_bill_icon",
        "电费": "electricity_bill_icon",
        "物业": "home_icon",
        "维修": "fix_icon",
        "管理费": "home_icon",
        "网费": "home_icon",
        "燃气费": "gas_icon",
        "送礼": "gift_icon",
        "请客": "treat_icon",
        "孝心": "relationship_icon",
        "亲密付": "relationship_icon",
        "发红包": "red_packet_icon",
        "借出": "relationship_icon",
        "还钱": "relationship_icon",
        "药品": "medical_icon",
        "保健": "medical_icon",
        "治疗": "medical_icon",
        "美容": "haircut_icon",
        "电子消费": "member_icon",
        "休闲": "leisure_icon",
        "约会": "dating_icon",
        "聚会": "party_icon",
        "游戏": "game_icon",
        "健身": "entertainment_icon",
        "电影": "movie_icon",
        "ChatGPT": "chatgpt_icon",
        "书籍": "study_icon",
        "培训": "study_icon",
        "网课": "study_icon",
        "房贷": "finance_icon",
        "车贷": "finance_icon",
        "分期": "finance_icon",
        "手续费": "finance_icon",
        "保险": "finance_icon",
        "养卡": "finance_icon",
        "快递到付": "express_icon",
        "邮寄快递": "express_icon",
        "装修": "other_icon",
        "办事": "other_icon",
    ]

    private static let categoryIcons: [String: String] = [
        "餐饮": "food_icon",
        "交通": "traffic_icon",
        "购物": "shopping_icon",
        "居家": "home_icon",
        "人情": "relationship_icon",
        "医疗": "medical_icon",
        "娱乐": "entertainment_icon",
        "学习": "study_icon",
        "金融": "finance_icon",
        "快递": "express_icon",
        "其他": "other_icon",
    ]

    private static let placeholderIcons: Set<String> = [
        "food_icon", "home_icon", "shopping_icon", "relationship_icon",
        "medical_icon", "study_icon", "finance_icon", "express_icon", "other_icon"
    ]

    private static let placeholderSymbols: [String: String] = [
        "food_icon": "fork.knife",
        "home_icon": "house",
        "shopping_icon": "bag",
        "relationship_icon": "heart",
        "medical_icon": "cross.case",
        "study_icon": "book",
        "finance_icon": "banknote",
        "express_icon": "shippingbox",
        "other_icon": "square.grid.2x2"
    ]

    private static var cache: [String: UIImage] = [:]

    static func image(for subcategory: String, category: String) -> UIImage? {
        guard let name = subcategoryIcons[subcategory] ?? categoryIcons[category],
              !placeholderIcons.contains(name) else { return nil }
        if let cached = cache[name] { return cached }
        let candidates = [
            Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "SubcategoryIcons"),
            Bundle.main.url(forResource: name, withExtension: "png")
        ]
        for url in candidates.compactMap({ $0 }) {
            if let image = UIImage(contentsOfFile: url.path) {
                cache[name] = image
                return image
            }
        }
        return nil
    }

    static func symbol(for subcategory: String, category: String) -> String? {
        let name = subcategoryIcons[subcategory] ?? categoryIcons[category]
        return name.flatMap { placeholderSymbols[$0] }
    }
}
#endif
